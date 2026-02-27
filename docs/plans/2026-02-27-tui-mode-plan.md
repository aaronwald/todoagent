# TUI Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Go TUI that watches a markdown file and renders todo items in a terminal, for use in cmux panes.

**Architecture:** Go module in `tui/` using Bubble Tea for rendering, fsnotify for file watching, and lipgloss for styling. Faithful port of the Swift parser. Single static binary.

**Tech Stack:** Go, Bubble Tea, lipgloss, fsnotify

---

### Task 1: Initialize Go module and dependencies

**Files:**
- Create: `tui/go.mod`

**Step 1: Create the Go module**

```bash
mkdir -p tui && cd tui && go mod init github.com/aaronwald/todoagent/tui
```

**Step 2: Add dependencies**

```bash
cd tui && go get github.com/charmbracelet/bubbletea@latest github.com/charmbracelet/lipgloss@latest github.com/fsnotify/fsnotify@latest
```

**Step 3: Verify module is valid**

```bash
cd tui && cat go.mod
```

Expected: module line + require block with bubbletea, lipgloss, fsnotify

**Step 4: Commit**

```bash
git add tui/go.mod tui/go.sum
git commit -m "feat(tui): initialize Go module with bubbletea, lipgloss, fsnotify"
```

---

### Task 2: Port data types and parser

**Files:**
- Create: `tui/parser.go`
- Create: `tui/parser_test.go`

**Step 1: Write the parser tests**

Port all tests from the Swift test suite. These must pass before we write any UI code.

```go
// tui/parser_test.go
package main

import (
	"testing"
)

func TestParseSimpleCheckboxes(t *testing.T) {
	md := "## Tasks\n- [ ] Uncompleted task\n- [x] Completed task"
	sections := Parse(md)
	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if sections[0].Heading != "Tasks" {
		t.Errorf("heading = %q, want %q", sections[0].Heading, "Tasks")
	}
	if sections[0].Level != 2 {
		t.Errorf("level = %d, want 2", sections[0].Level)
	}
	if len(sections[0].Items) != 2 {
		t.Fatalf("items = %d, want 2", len(sections[0].Items))
	}
	if sections[0].Items[0].Completed {
		t.Error("item 0 should not be completed")
	}
	if sections[0].Items[0].Title != "Uncompleted task" {
		t.Errorf("title = %q, want %q", sections[0].Items[0].Title, "Uncompleted task")
	}
	if !sections[0].Items[1].Completed {
		t.Error("item 1 should be completed")
	}
}

func TestParseNestedHeadings(t *testing.T) {
	md := "## SSMD\n### Active\n- [ ] Task A\n### Pending\n- [ ] Task B\n- [ ] Task C"
	sections := Parse(md)
	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if len(sections[0].Subsections) != 2 {
		t.Fatalf("subsections = %d, want 2", len(sections[0].Subsections))
	}
	if sections[0].Subsections[0].Heading != "Active" {
		t.Errorf("heading = %q, want Active", sections[0].Subsections[0].Heading)
	}
	if len(sections[0].Subsections[0].Items) != 1 {
		t.Errorf("items = %d, want 1", len(sections[0].Subsections[0].Items))
	}
	if sections[0].Subsections[1].Heading != "Pending" {
		t.Errorf("heading = %q, want Pending", sections[0].Subsections[1].Heading)
	}
	if len(sections[0].Subsections[1].Items) != 2 {
		t.Errorf("items = %d, want 2", len(sections[0].Subsections[1].Items))
	}
}

func TestParseBoldTitleAndTags(t *testing.T) {
	md := "## Work\n- [ ] **Multi-exchange secmaster** [ssmd] - Feb 7"
	sections := Parse(md)
	if sections[0].Items[0].Title != "Multi-exchange secmaster" {
		t.Errorf("title = %q, want %q", sections[0].Items[0].Title, "Multi-exchange secmaster")
	}
	if len(sections[0].Items[0].Tags) != 1 || sections[0].Items[0].Tags[0] != "ssmd" {
		t.Errorf("tags = %v, want [ssmd]", sections[0].Items[0].Tags)
	}
}

func TestParseAllCompletedSection(t *testing.T) {
	md := "## Done\n- [x] Task A\n- [x] Task B"
	sections := Parse(md)
	if !sections[0].AllCompleted {
		t.Error("section should be allCompleted")
	}
}

func TestParseLineNumbers(t *testing.T) {
	md := "## Section\n- [ ] First\n- [ ] Second"
	sections := Parse(md)
	if sections[0].Items[0].Line != 2 {
		t.Errorf("line = %d, want 2", sections[0].Items[0].Line)
	}
	if sections[0].Items[1].Line != 3 {
		t.Errorf("line = %d, want 3", sections[0].Items[1].Line)
	}
}

func TestIgnoreNonCheckboxContent(t *testing.T) {
	md := "## Summary\n| Col1 | Col2 |\n|------|------|\n| a    | b    |\n\nSome paragraph text.\n\n- [ ] Real task"
	sections := Parse(md)
	if len(sections[0].Items) != 1 {
		t.Fatalf("items = %d, want 1", len(sections[0].Items))
	}
	if sections[0].Items[0].Title != "Real task" {
		t.Errorf("title = %q, want %q", sections[0].Items[0].Title, "Real task")
	}
}

func TestParseDeeplyNested(t *testing.T) {
	md := "## Domain\n### Category\n#### Subcategory\n- [ ] Deep task"
	sections := Parse(md)
	if sections[0].Heading != "Domain" {
		t.Errorf("heading = %q", sections[0].Heading)
	}
	if sections[0].Subsections[0].Heading != "Category" {
		t.Errorf("heading = %q", sections[0].Subsections[0].Heading)
	}
	if sections[0].Subsections[0].Subsections[0].Heading != "Subcategory" {
		t.Errorf("heading = %q", sections[0].Subsections[0].Subsections[0].Heading)
	}
	if sections[0].Subsections[0].Subsections[0].Items[0].Title != "Deep task" {
		t.Errorf("title = %q", sections[0].Subsections[0].Subsections[0].Items[0].Title)
	}
}

func TestParseEmptyContent(t *testing.T) {
	sections := Parse("")
	if len(sections) != 0 {
		t.Errorf("expected 0 sections, got %d", len(sections))
	}
}

func TestParseRealWorldTodo(t *testing.T) {
	md := `# Project Roadmap

## SSMD (Market Data)

### Active
- [ ] **Multi-exchange secmaster** [ssmd] - Feb 7
- [ ] **Spread capture research** [ssmd] - Feb 1

### Pending

#### Data Pipeline
- [ ] Kraken Futures WebSocket connector [ssmd]
- [x] Pair ID namespace prefix migration [ssmd] - Feb 7

#### Agent & Signals
- [ ] SQLite checkpointer

### Completed (Recent)
- [x] **Polymarket connector** [ssmd/varlab] - Feb 6
- [x] **Momentum signal research** [ssmd] - Feb 1

## Platform Infrastructure

### Pending
- [ ] Migrate Velero backups to Temporal
- [ ] Disaster Recovery validation

### Completed (Recent)
- [x] Sync Google Drive to Brooklyn NAS`

	sections := Parse(md)

	if len(sections) != 2 {
		t.Fatalf("sections = %d, want 2", len(sections))
	}
	if sections[0].Heading != "SSMD (Market Data)" {
		t.Errorf("heading = %q", sections[0].Heading)
	}
	if sections[1].Heading != "Platform Infrastructure" {
		t.Errorf("heading = %q", sections[1].Heading)
	}

	// SSMD subsections
	if len(sections[0].Subsections) != 3 {
		t.Fatalf("subsections = %d, want 3", len(sections[0].Subsections))
	}
	if sections[0].Subsections[0].Heading != "Active" {
		t.Errorf("heading = %q", sections[0].Subsections[0].Heading)
	}
	if len(sections[0].Subsections[0].Items) != 2 {
		t.Errorf("items = %d, want 2", len(sections[0].Subsections[0].Items))
	}

	// Pending has sub-subsections
	pending := sections[0].Subsections[1]
	if pending.Heading != "Pending" {
		t.Errorf("heading = %q", pending.Heading)
	}
	if len(pending.Subsections) != 2 {
		t.Fatalf("subsections = %d, want 2", len(pending.Subsections))
	}
	if pending.Subsections[0].Heading != "Data Pipeline" {
		t.Errorf("heading = %q", pending.Subsections[0].Heading)
	}
	if len(pending.Subsections[0].Items) != 2 {
		t.Errorf("items = %d, want 2", len(pending.Subsections[0].Items))
	}

	// Completed section
	completed := sections[0].Subsections[2]
	if !completed.AllCompleted {
		t.Error("completed section should be allCompleted")
	}

	// Tags
	if sections[0].Subsections[0].Items[0].Tags[0] != "ssmd" {
		t.Errorf("tag = %q", sections[0].Subsections[0].Items[0].Tags[0])
	}
	if sections[0].Subsections[0].Items[0].Title != "Multi-exchange secmaster" {
		t.Errorf("title = %q", sections[0].Subsections[0].Items[0].Title)
	}

	// Platform infra
	if sections[1].Subsections[0].Heading != "Pending" {
		t.Errorf("heading = %q", sections[1].Subsections[0].Heading)
	}
	if len(sections[1].Subsections[0].Items) != 2 {
		t.Errorf("items = %d", len(sections[1].Subsections[0].Items))
	}
	if !sections[1].Subsections[1].AllCompleted {
		t.Error("should be allCompleted")
	}
}

func TestItemCountAcrossNesting(t *testing.T) {
	md := "## Root\n- [ ] A\n### Sub1\n- [ ] B\n- [x] C\n#### Deep\n- [ ] D"
	sections := Parse(md)
	if sections[0].AllCompleted {
		t.Error("root should not be allCompleted")
	}
	if len(sections[0].Items) != 1 {
		t.Errorf("items = %d, want 1", len(sections[0].Items))
	}
	if len(sections[0].Subsections[0].Items) != 2 {
		t.Errorf("items = %d, want 2", len(sections[0].Subsections[0].Items))
	}
	if len(sections[0].Subsections[0].Subsections[0].Items) != 1 {
		t.Errorf("items = %d, want 1", len(sections[0].Subsections[0].Subsections[0].Items))
	}
}
```

**Step 2: Run tests to verify they fail**

```bash
cd tui && go test -v ./...
```

Expected: compilation error (Parse not defined yet)

**Step 3: Write the parser implementation**

```go
// tui/parser.go
package main

import (
	"regexp"
	"strings"
)

// TodoItem represents a single checkbox item.
type TodoItem struct {
	Title     string
	Completed bool
	Line      int
	Tags      []string
	Details   []string
}

// TodoSection represents a heading with items and nested subsections.
type TodoSection struct {
	Heading      string
	Level        int
	Items        []TodoItem
	Subsections  []TodoSection
	AllCompleted bool
}

type stackEntry struct {
	level       int
	heading     string
	items       []TodoItem
	subsections []TodoSection
}

var tagRegex = regexp.MustCompile(`\[([a-zA-Z][a-zA-Z0-9/]*)\]`)

// Parse parses markdown content into a tree of TodoSections.
func Parse(content string) []TodoSection {
	lines := strings.Split(content, "\n")
	var root []TodoSection
	var stack []stackEntry
	var pendingDetails []string

	for i, rawLine := range lines {
		line := strings.TrimSpace(rawLine)
		lineNumber := i + 1

		if level, heading, ok := parseHeading(line); ok {
			flushDetails(&pendingDetails, &stack)

			for len(stack) > 0 && stack[len(stack)-1].level >= level {
				popped := stack[len(stack)-1]
				stack = stack[:len(stack)-1]
				section := buildSection(popped, stack)
				if len(stack) == 0 {
					root = append(root, section)
				} else {
					stack[len(stack)-1].subsections = append(stack[len(stack)-1].subsections, section)
				}
			}
			stack = append(stack, stackEntry{level: level, heading: heading})
		} else if item, ok := parseCheckbox(line, lineNumber); ok {
			flushDetails(&pendingDetails, &stack)
			if len(stack) > 0 {
				stack[len(stack)-1].items = append(stack[len(stack)-1].items, item)
			}
		} else if line != "" && len(stack) > 0 && len(stack[len(stack)-1].items) > 0 {
			detail := strings.TrimSpace(rawLine)
			if strings.HasPrefix(detail, "- ") {
				detail = detail[2:]
			}
			pendingDetails = append(pendingDetails, detail)
		}
	}

	flushDetails(&pendingDetails, &stack)

	for len(stack) > 0 {
		popped := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		section := buildSection(popped, stack)
		if len(stack) == 0 {
			root = append(root, section)
		} else {
			stack[len(stack)-1].subsections = append(stack[len(stack)-1].subsections, section)
		}
	}

	return root
}

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

func parseCheckbox(line string, lineNumber int) (TodoItem, bool) {
	trimmed := strings.TrimSpace(line)
	var completed bool
	var rest string

	switch {
	case strings.HasPrefix(trimmed, "- [ ] "):
		completed = false
		rest = trimmed[6:]
	case strings.HasPrefix(trimmed, "- [x] "), strings.HasPrefix(trimmed, "- [X] "):
		completed = true
		rest = trimmed[6:]
	default:
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

func extractTitle(text string) string {
	// Try bold first: **title**
	if start := strings.Index(text, "**"); start >= 0 {
		after := text[start+2:]
		if end := strings.Index(after, "**"); end >= 0 {
			return strings.TrimSpace(after[:end])
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

func extractTags(text string) []string {
	matches := tagRegex.FindAllStringSubmatch(text, -1)
	if len(matches) == 0 {
		return nil
	}
	tags := make([]string, len(matches))
	for i, m := range matches {
		tags[i] = m[1]
	}
	return tags
}

func buildSection(entry stackEntry, stack []stackEntry) TodoSection {
	allItems := collectAllItems(entry)
	allCompleted := len(allItems) == 0 || allDone(allItems)

	return TodoSection{
		Heading:      entry.heading,
		Level:        entry.level,
		Items:        entry.items,
		Subsections:  entry.subsections,
		AllCompleted: allCompleted,
	}
}

func collectAllItems(entry stackEntry) []TodoItem {
	items := make([]TodoItem, len(entry.items))
	copy(items, entry.items)
	for _, sub := range entry.subsections {
		items = append(items, collectAllItemsFromSection(sub)...)
	}
	return items
}

func collectAllItemsFromSection(s TodoSection) []TodoItem {
	items := make([]TodoItem, len(s.Items))
	copy(items, s.Items)
	for _, sub := range s.Subsections {
		items = append(items, collectAllItemsFromSection(sub)...)
	}
	return items
}

func allDone(items []TodoItem) bool {
	for _, item := range items {
		if !item.Completed {
			return false
		}
	}
	return true
}

func flushDetails(details *[]string, stack *[]stackEntry) {
	if len(*details) == 0 || len(*stack) == 0 {
		*details = nil
		return
	}
	idx := len(*stack) - 1
	items := (*stack)[idx].items
	if len(items) == 0 {
		*details = nil
		return
	}
	lastIdx := len(items) - 1
	items[lastIdx].Details = *details
	(*stack)[idx].items = items
	*details = nil
}
```

**Step 4: Run tests to verify they pass**

```bash
cd tui && go test -v ./...
```

Expected: all tests PASS

**Step 5: Commit**

```bash
git add tui/parser.go tui/parser_test.go
git commit -m "feat(tui): port markdown parser and tests from Swift"
```

---

### Task 3: Build the file watcher

**Files:**
- Create: `tui/watcher.go`

**Step 1: Write the file watcher**

```go
// tui/watcher.go
package main

import (
	"os"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/fsnotify/fsnotify"
)

// FileUpdatedMsg is sent when the watched file changes.
type FileUpdatedMsg struct {
	Sections []TodoSection
}

// FileErrorMsg is sent when there's an error reading the file.
type FileErrorMsg struct {
	Err error
}

// ReadAndParse reads a file and parses it into sections.
func ReadAndParse(path string) ([]TodoSection, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return Parse(string(data)), nil
}

// WatchFile returns a tea.Cmd that watches a file for changes and sends
// FileUpdatedMsg or FileErrorMsg when the file is modified.
func WatchFile(path string) tea.Cmd {
	return func() tea.Msg {
		watcher, err := fsnotify.NewWatcher()
		if err != nil {
			return FileErrorMsg{Err: err}
		}

		if err := watcher.Add(path); err != nil {
			watcher.Close()
			return FileErrorMsg{Err: err}
		}

		// Debounce: wait for events to settle
		var timer *time.Timer
		done := make(chan tea.Msg, 1)

		go func() {
			for {
				select {
				case event, ok := <-watcher.Events:
					if !ok {
						return
					}
					if event.Op&(fsnotify.Write|fsnotify.Create) != 0 {
						if timer != nil {
							timer.Stop()
						}
						timer = time.AfterFunc(100*time.Millisecond, func() {
							sections, err := ReadAndParse(path)
							if err != nil {
								done <- FileErrorMsg{Err: err}
							} else {
								done <- FileUpdatedMsg{Sections: sections}
							}
						})
					}
				case err, ok := <-watcher.Errors:
					if !ok {
						return
					}
					done <- FileErrorMsg{Err: err}
					return
				}
			}
		}()

		return <-done
	}
}
```

**Step 2: Verify it compiles**

```bash
cd tui && go build ./...
```

Expected: no errors (needs a main.go stub — will be added in next task)

**Step 3: Commit**

```bash
git add tui/watcher.go
git commit -m "feat(tui): add file watcher with fsnotify debounce"
```

---

### Task 4: Build the Bubble Tea model and view

**Files:**
- Create: `tui/model.go`

**Step 1: Write the Bubble Tea model**

```go
// tui/model.go
package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Pastel colors ported from PastelTheme.swift
var pastelColors = []lipgloss.Color{
	lipgloss.Color("#66B3EB"), // blue
	lipgloss.Color("#59CC73"), // green
	lipgloss.Color("#F29959"), // peach
	lipgloss.Color("#9973E6"), // lavender
	lipgloss.Color("#4DD9B8"), // mint
	lipgloss.Color("#EB6680"), // rose
	lipgloss.Color("#E6D14D"), // yellow
	lipgloss.Color("#BF80E6"), // orchid
}

// node is a flattened representation of a section or item for cursor navigation.
type node struct {
	isSection bool
	depth     int
	section   *TodoSection // non-nil for section nodes
	item      *TodoItem    // non-nil for item nodes
	colorIdx  int          // top-level section color index
}

type model struct {
	filePath  string
	fileName  string
	sections  []TodoSection
	nodes     []node // flattened visible nodes
	cursor    int
	collapsed map[string]bool // section heading path -> collapsed
	width     int
	height    int
	err       error
}

func initialModel(filePath, fileName string, sections []TodoSection) model {
	m := model{
		filePath:  filePath,
		fileName:  fileName,
		sections:  sections,
		collapsed: make(map[string]bool),
	}
	// Collapse all-completed sections by default
	initCollapsed(sections, "", m.collapsed)
	m.nodes = m.flatten()
	return m
}

func initCollapsed(sections []TodoSection, prefix string, collapsed map[string]bool) {
	for _, s := range sections {
		key := prefix + s.Heading
		if s.AllCompleted {
			collapsed[key] = true
		}
		initCollapsed(s.Subsections, key+"/", collapsed)
	}
}

func (m model) Init() tea.Cmd {
	return WatchFile(m.filePath)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.nodes)-1 {
				m.cursor++
			}
		case "left", "h":
			if m.cursor < len(m.nodes) {
				n := m.nodes[m.cursor]
				if n.isSection {
					m.collapsed[sectionKey(n)] = true
					m.nodes = m.flatten()
				}
			}
		case "right", "l":
			if m.cursor < len(m.nodes) {
				n := m.nodes[m.cursor]
				if n.isSection {
					delete(m.collapsed, sectionKey(n))
					m.nodes = m.flatten()
				}
			}
		case "r":
			sections, err := ReadAndParse(m.filePath)
			if err != nil {
				m.err = err
			} else {
				m.sections = sections
				m.nodes = m.flatten()
				m.clampCursor()
			}
		}

	case FileUpdatedMsg:
		m.sections = msg.Sections
		m.err = nil
		m.nodes = m.flatten()
		m.clampCursor()
		return m, WatchFile(m.filePath)

	case FileErrorMsg:
		m.err = msg.Err
		return m, WatchFile(m.filePath)

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	}

	return m, nil
}

func (m *model) clampCursor() {
	if m.cursor >= len(m.nodes) {
		m.cursor = max(0, len(m.nodes)-1)
	}
}

func sectionKey(n node) string {
	if n.section == nil {
		return ""
	}
	// Build key from depth context — uses heading directly
	// This works because flatten tracks the prefix
	return n.section.Heading
}

func (m model) flatten() []node {
	var nodes []node
	for i := range m.sections {
		m.flattenSection(&nodes, &m.sections[i], 0, "", i)
	}
	return nodes
}

func (m model) flattenSection(nodes *[]node, s *TodoSection, depth int, prefix string, colorIdx int) {
	key := prefix + s.Heading
	*nodes = append(*nodes, node{
		isSection: true,
		depth:     depth,
		section:   s,
		colorIdx:  colorIdx,
	})

	if m.collapsed[key] {
		return
	}

	for i := range s.Items {
		*nodes = append(*nodes, node{
			isSection: false,
			depth:     depth + 1,
			item:      &s.Items[i],
			colorIdx:  colorIdx,
		})
	}

	for i := range s.Subsections {
		m.flattenSection(nodes, &s.Subsections[i], depth+1, key+"/", colorIdx)
	}
}

func (m model) View() string {
	if m.width == 0 {
		return "Loading..."
	}

	var b strings.Builder

	// Header
	headerStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("#FFFFFF")).
		Background(lipgloss.Color("#333333")).
		Width(m.width).
		Padding(0, 1)
	b.WriteString(headerStyle.Render(m.fileName))
	b.WriteString("\n")

	// Content area height = total - header(1) - footer(2)
	contentHeight := m.height - 3
	if contentHeight < 1 {
		contentHeight = 1
	}

	// Render visible nodes with scrolling
	lines := m.renderNodes()

	// Scroll to keep cursor visible
	start := 0
	if m.cursor >= contentHeight {
		start = m.cursor - contentHeight + 1
	}
	end := start + contentHeight
	if end > len(lines) {
		end = len(lines)
	}
	if start > 0 && end-start < contentHeight {
		start = max(0, end-contentHeight)
	}

	for i := start; i < end; i++ {
		b.WriteString(lines[i])
		b.WriteString("\n")
	}

	// Pad remaining lines
	for i := end - start; i < contentHeight; i++ {
		b.WriteString("\n")
	}

	// Footer
	total, done := m.countItems()
	footerStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#888888")).
		Width(m.width).
		Padding(0, 1)

	status := fmt.Sprintf("%d/%d done", done, total)
	if m.err != nil {
		status = fmt.Sprintf("Error: %v", m.err)
	}
	help := "↑↓ navigate  ←→ collapse  r refresh  q quit"
	padding := m.width - lipgloss.Width(status) - lipgloss.Width(help) - 4
	if padding < 1 {
		padding = 1
	}
	footer := status + strings.Repeat(" ", padding) + help
	b.WriteString(footerStyle.Render(footer))

	return b.String()
}

func (m model) renderNodes() []string {
	lines := make([]string, len(m.nodes))
	for i, n := range m.nodes {
		isCursor := i == m.cursor
		lines[i] = m.renderNode(n, isCursor)
	}
	return lines
}

func (m model) renderNode(n node, isCursor bool) string {
	indent := strings.Repeat("  ", n.depth)
	color := pastelColors[n.colorIdx%len(pastelColors)]

	if n.isSection {
		s := n.section
		chevron := "▸"
		key := n.section.Heading
		if !m.collapsed[key] {
			chevron = "▾"
		}

		total, done := countSectionItems(s)
		badge := fmt.Sprintf("[%d/%d]", done, total)

		text := fmt.Sprintf("%s%s %s %s", indent, chevron, s.Heading, badge)
		style := lipgloss.NewStyle().Foreground(color).Bold(true)
		if s.AllCompleted {
			style = style.Faint(true)
		}
		if isCursor {
			style = style.Reverse(true)
		}
		return style.Width(m.width).Render(text)
	}

	// Item node
	item := n.item
	check := "☐"
	if item.Completed {
		check = "☑"
	}

	title := item.Title
	var tagStr string
	if len(item.Tags) > 0 {
		tagStr = " [" + strings.Join(item.Tags, ", ") + "]"
	}

	text := fmt.Sprintf("%s  %s %s%s", indent, check, title, tagStr)
	style := lipgloss.NewStyle().Foreground(color)
	if item.Completed {
		style = style.Strikethrough(true).Faint(true)
	}
	if isCursor {
		style = style.Reverse(true)
	}
	return style.Width(m.width).Render(text)
}

func (m model) countItems() (total, done int) {
	for _, s := range m.sections {
		t, d := countSectionItems(&s)
		total += t
		done += d
	}
	return
}

func countSectionItems(s *TodoSection) (total, done int) {
	for _, item := range s.Items {
		total++
		if item.Completed {
			done++
		}
	}
	for _, sub := range s.Subsections {
		t, d := countSectionItems(&sub)
		total += t
		done += d
	}
	return
}
```

**Step 2: Verify it compiles**

```bash
cd tui && go build ./...
```

Expected: needs main.go (next task)

**Step 3: Commit**

```bash
git add tui/model.go
git commit -m "feat(tui): add Bubble Tea model with pastel theme and navigation"
```

---

### Task 5: Build the main entry point

**Files:**
- Create: `tui/main.go`

**Step 1: Write the main entry point**

```go
// tui/main.go
package main

import (
	"fmt"
	"os"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: todoagent-tui <file.md>\n")
		os.Exit(1)
	}

	filePath := os.Args[1]

	// Resolve to absolute path
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error resolving path: %v\n", err)
		os.Exit(1)
	}

	// Verify file exists
	if _, err := os.Stat(absPath); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Initial parse
	sections, err := ReadAndParse(absPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
		os.Exit(1)
	}

	fileName := filepath.Base(absPath)
	m := initialModel(absPath, fileName, sections)

	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
```

**Step 2: Build the binary**

```bash
cd tui && go build -o todoagent-tui .
```

Expected: binary `tui/todoagent-tui` is created

**Step 3: Manual smoke test**

Create a test file and run:

```bash
cat > /tmp/test-todos.md << 'EOF'
# My Project

## Active
- [ ] First task [work]
- [x] Second task [work]

### Sub-section
- [ ] Nested task

## Done
- [x] Finished item
EOF

cd tui && ./todoagent-tui /tmp/test-todos.md
```

Expected: TUI renders with sections, colors, navigation works. Press `q` to quit.

**Step 4: Commit**

```bash
git add tui/main.go
git commit -m "feat(tui): add main entry point with arg parsing and alt screen"
```

---

### Task 6: Fix collapsed section key tracking

The current `sectionKey` function uses just the heading name, which can collide for sections with the same name at different levels. Fix this to use the full path prefix, matching the flatten logic.

**Files:**
- Modify: `tui/model.go`

**Step 1: Refactor node to carry the full key**

Add a `key` field to the `node` struct. Set it during `flattenSection` using the `prefix + s.Heading` path. Update `sectionKey` to return `n.key`. Update collapse/expand in `Update` to use `n.key`.

In `node` struct, add:
```go
key string // full path key for collapse tracking (e.g., "SSMD/Active")
```

In `flattenSection`, set the key:
```go
*nodes = append(*nodes, node{
    isSection: true,
    depth:     depth,
    section:   s,
    colorIdx:  colorIdx,
    key:       key,
})
```

In `renderNode`, use `n.key` instead of `n.section.Heading` for collapse lookup.

In `Update`, use `m.nodes[m.cursor].key` for collapse/expand.

**Step 2: Run tests**

```bash
cd tui && go test -v ./...
```

Expected: all tests pass

**Step 3: Commit**

```bash
git add tui/model.go
git commit -m "fix(tui): use full path keys for section collapse tracking"
```

---

### Task 7: End-to-end test and cleanup

**Files:**
- Modify: `tui/go.mod` (tidy)

**Step 1: Tidy modules**

```bash
cd tui && go mod tidy
```

**Step 2: Run all tests**

```bash
cd tui && go test -v ./...
```

Expected: all pass

**Step 3: Build release binary**

```bash
cd tui && go build -o todoagent-tui .
```

Expected: clean build

**Step 4: Update CLAUDE.md with TUI instructions**

Add to the Build & Test section of the project CLAUDE.md:

```markdown
## TUI Mode

```bash
cd tui && go build -o todoagent-tui .    # Build TUI binary
cd tui && go test -v ./...                # Run TUI tests
./tui/todoagent-tui <file.md>            # Run TUI on a markdown file
```
```

**Step 5: Final commit**

```bash
git add -A tui/ CLAUDE.md
git commit -m "feat(tui): complete Go TUI mode for TodoAgent"
```
