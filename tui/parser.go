package main

import (
	"regexp"
	"strings"
)

// TodoItem represents a single checkbox item in a markdown file.
type TodoItem struct {
	Title     string
	Completed bool
	Line      int
	Tags      []string
	Details   []string
}

// TodoSection represents a heading-delimited section containing items and subsections.
type TodoSection struct {
	Heading      string
	Level        int
	Items        []TodoItem
	Subsections  []TodoSection
	AllCompleted bool
}

// tagRegex matches tags like [ssmd] or [api/v2] in checkbox text.
var tagRegex = regexp.MustCompile(`\[([a-zA-Z][a-zA-Z0-9/]*)\]`)

// detailPrefixRegex strips a leading "- " from detail lines.
var detailPrefixRegex = regexp.MustCompile(`^- `)

// stackEntry is an intermediate representation used during parsing.
type stackEntry struct {
	level       int
	heading     string
	items       []TodoItem
	subsections []TodoSection
}

// Parse parses markdown content and returns a slice of top-level TodoSections.
// It recognizes headings at levels 2-4 (## through ####), ignoring h1 (#).
// Checkboxes are extracted from lines matching "- [ ]" or "- [x]"/"- [X]".
func Parse(content string) []TodoSection {
	lines := strings.Split(content, "\n")
	var rootSections []TodoSection
	var stack []stackEntry
	var pendingDetails []string

	for index, rawLine := range lines {
		line := strings.TrimSpace(rawLine)
		lineNumber := index + 1

		if level, heading, ok := parseHeading(line); ok {
			// Flush pending details to last item
			flushDetails(&pendingDetails, &stack)

			// Pop stack entries with level >= current heading level
			for len(stack) > 0 && stack[len(stack)-1].level >= level {
				popped := stack[len(stack)-1]
				stack = stack[:len(stack)-1]
				section := buildSection(popped)
				if len(stack) == 0 {
					rootSections = append(rootSections, section)
				} else {
					stack[len(stack)-1].subsections = append(stack[len(stack)-1].subsections, section)
				}
			}
			stack = append(stack, stackEntry{level: level, heading: heading})
		} else if item, ok := parseCheckbox(line, lineNumber); ok {
			// Flush pending details to previous item before starting a new one
			flushDetails(&pendingDetails, &stack)
			if len(stack) > 0 {
				stack[len(stack)-1].items = append(stack[len(stack)-1].items, item)
			}
		} else if line != "" && len(stack) > 0 && len(stack[len(stack)-1].items) > 0 {
			// Non-empty line after a checkbox — collect as detail
			detail := detailPrefixRegex.ReplaceAllString(strings.TrimSpace(rawLine), "")
			pendingDetails = append(pendingDetails, detail)
		}
	}

	// Flush any remaining pending details
	flushDetails(&pendingDetails, &stack)

	// Pop remaining stack entries
	for len(stack) > 0 {
		popped := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		section := buildSection(popped)
		if len(stack) == 0 {
			rootSections = append(rootSections, section)
		} else {
			stack[len(stack)-1].subsections = append(stack[len(stack)-1].subsections, section)
		}
	}

	return rootSections
}

// parseHeading checks if a line is a heading of level 2-4.
// Returns (level, heading text, true) or (0, "", false).
func parseHeading(line string) (int, string, bool) {
	level := 0
	for _, ch := range line {
		if ch == '#' {
			level++
		} else {
			break
		}
	}
	if level < 2 {
		return 0, "", false
	}
	heading := strings.TrimSpace(line[level:])
	if heading == "" {
		return 0, "", false
	}
	return level, heading, true
}

// parseCheckbox checks if a line is a checkbox item.
// Returns (TodoItem, true) if it matches, or (TodoItem{}, false) otherwise.
func parseCheckbox(line string, lineNumber int) (TodoItem, bool) {
	trimmed := strings.TrimSpace(line)
	var completed bool
	var rest string

	if strings.HasPrefix(trimmed, "- [ ] ") {
		completed = false
		rest = trimmed[6:]
	} else if strings.HasPrefix(trimmed, "- [x] ") || strings.HasPrefix(trimmed, "- [X] ") {
		completed = true
		rest = trimmed[6:]
	} else {
		return TodoItem{}, false
	}

	title := extractTitle(rest)
	tags := extractTags(rest)

	return TodoItem{
		Title:     title,
		Completed: completed,
		Line:      lineNumber,
		Tags:      tags,
	}, true
}

// extractTitle extracts the display title from checkbox text.
// If the text contains bold markers **title**, the bold content is used.
// Otherwise, text before " [" or " - " is used.
func extractTitle(text string) string {
	boldStart := strings.Index(text, "**")
	if boldStart >= 0 {
		afterStart := text[boldStart+2:]
		boldEnd := strings.Index(afterStart, "**")
		if boldEnd >= 0 {
			return strings.TrimSpace(afterStart[:boldEnd])
		}
	}

	title := text
	if idx := strings.Index(title, " ["); idx >= 0 {
		title = title[:idx]
	}
	if idx := strings.Index(title, " - "); idx >= 0 {
		title = title[:idx]
	}
	return strings.TrimSpace(title)
}

// extractTags finds all [tag] patterns in the text.
func extractTags(text string) []string {
	matches := tagRegex.FindAllStringSubmatch(text, -1)
	if len(matches) == 0 {
		return nil
	}
	tags := make([]string, 0, len(matches))
	for _, match := range matches {
		if len(match) >= 2 {
			tags = append(tags, match[1])
		}
	}
	return tags
}

// buildSection creates a TodoSection from a stack entry, computing AllCompleted.
func buildSection(entry stackEntry) TodoSection {
	allItems := collectAllItems(entry.items, entry.subsections)
	allCompleted := len(allItems) == 0 || allItemsCompleted(allItems)

	return TodoSection{
		Heading:      entry.heading,
		Level:        entry.level,
		Items:        entry.items,
		Subsections:  entry.subsections,
		AllCompleted: allCompleted,
	}
}

// collectAllItems gathers all items from direct items and all subsections recursively.
func collectAllItems(items []TodoItem, subsections []TodoSection) []TodoItem {
	all := make([]TodoItem, 0, len(items))
	all = append(all, items...)
	for _, sub := range subsections {
		all = append(all, collectAllItems(sub.Items, sub.Subsections)...)
	}
	return all
}

// allItemsCompleted returns true if every item in the slice is completed.
func allItemsCompleted(items []TodoItem) bool {
	for _, item := range items {
		if !item.Completed {
			return false
		}
	}
	return true
}

// flushDetails attaches accumulated detail lines to the last item on the stack.
func flushDetails(details *[]string, stack *[]stackEntry) {
	if len(*details) == 0 || len(*stack) == 0 {
		*details = nil
		return
	}
	idx := len(*stack) - 1
	if len((*stack)[idx].items) == 0 {
		*details = nil
		return
	}
	lastIdx := len((*stack)[idx].items) - 1
	(*stack)[idx].items[lastIdx].Details = *details
	*details = nil
}
