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

// node represents a single navigable row in the TUI — either a section heading or a todo item.
type node struct {
	isSection bool
	depth     int
	section   *TodoSection
	item      *TodoItem
	colorIdx  int
	key       string // full path for collapse tracking, e.g. "SSMD/Active"
}

// model is the Bubble Tea model for the TodoAgent TUI.
type model struct {
	filePath  string
	fileName  string
	sections  []TodoSection
	nodes     []node
	cursor    int
	collapsed map[string]bool
	width     int
	height    int
	scroll    int
	err       error
}

// initialModel creates the initial model with parsed sections.
func initialModel(filePath, fileName string, sections []TodoSection) model {
	m := model{
		filePath:  filePath,
		fileName:  fileName,
		sections:  sections,
		collapsed: make(map[string]bool),
	}

	// Set default collapsed state: sections with AllCompleted are collapsed by default
	setDefaultCollapsed(sections, "", m.collapsed)

	m.nodes = flatten(sections, m.collapsed)
	return m
}

// setDefaultCollapsed recursively marks all-completed sections as collapsed.
func setDefaultCollapsed(sections []TodoSection, prefix string, collapsed map[string]bool) {
	for _, s := range sections {
		key := sectionKey(prefix, s.Heading)
		if s.AllCompleted {
			collapsed[key] = true
		}
		setDefaultCollapsed(s.Subsections, key, collapsed)
	}
}

// sectionKey builds a unique path key for collapse tracking.
func sectionKey(prefix, heading string) string {
	if prefix == "" {
		return heading
	}
	return prefix + "/" + heading
}

// flatten produces a flat list of nodes from the section tree, respecting collapsed state.
func flatten(sections []TodoSection, collapsed map[string]bool) []node {
	var nodes []node
	for i := range sections {
		flattenSection(&nodes, &sections[i], 0, "", i%len(pastelColors), collapsed)
	}
	return nodes
}

// flattenSection recursively adds nodes for a section and its children.
func flattenSection(nodes *[]node, s *TodoSection, depth int, prefix string, colorIdx int, collapsed map[string]bool) {
	key := sectionKey(prefix, s.Heading)
	*nodes = append(*nodes, node{
		isSection: true,
		depth:     depth,
		section:   s,
		colorIdx:  colorIdx,
		key:       key,
	})

	if collapsed[key] {
		return
	}

	for i := range s.Items {
		*nodes = append(*nodes, node{
			isSection: false,
			depth:     depth + 1,
			item:      &s.Items[i],
			colorIdx:  colorIdx,
			key:       key,
		})
	}

	for i := range s.Subsections {
		flattenSection(nodes, &s.Subsections[i], depth+1, key, colorIdx, collapsed)
	}
}

// Init starts file watching.
func (m model) Init() tea.Cmd {
	return WatchFile(m.filePath)
}

// Update handles messages.
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
			m.ensureVisible()

		case "down", "j":
			if m.cursor < len(m.nodes)-1 {
				m.cursor++
			}
			m.ensureVisible()

		case "left", "h":
			// Collapse: if on a section, collapse it; if on an item, collapse parent section
			key := m.currentSectionKey()
			if key != "" {
				m.collapsed[key] = true
				m.nodes = flatten(m.sections, m.collapsed)
				m.clampCursor()
				m.ensureVisible()
			}

		case "right", "l":
			// Expand: if on a section, expand it
			if m.cursor < len(m.nodes) && m.nodes[m.cursor].isSection {
				key := m.nodes[m.cursor].key
				delete(m.collapsed, key)
				m.nodes = flatten(m.sections, m.collapsed)
				m.ensureVisible()
			}

		case "r":
			sections, err := ReadAndParse(m.filePath)
			if err != nil {
				m.err = err
			} else {
				m.err = nil
				m.sections = sections
				m.nodes = flatten(m.sections, m.collapsed)
				m.clampCursor()
				m.ensureVisible()
			}
			return m, WatchFile(m.filePath)
		}

	case FileUpdatedMsg:
		m.err = nil
		m.sections = msg.Sections
		m.nodes = flatten(m.sections, m.collapsed)
		m.clampCursor()
		m.ensureVisible()
		return m, WatchFile(m.filePath)

	case FileErrorMsg:
		m.err = msg.Err
		return m, WatchFile(m.filePath)

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.ensureVisible()
	}

	return m, nil
}

// currentSectionKey returns the collapse key for the current cursor position.
// If the cursor is on a section, returns that section's key.
// If the cursor is on an item, returns the parent section's key.
func (m model) currentSectionKey() string {
	if m.cursor >= len(m.nodes) {
		return ""
	}
	n := m.nodes[m.cursor]
	if n.isSection {
		return n.key
	}
	// For items, the key field holds the parent section key
	return n.key
}

// clampCursor ensures cursor is within valid range.
func (m *model) clampCursor() {
	m.cursor = max(min(m.cursor, len(m.nodes)-1), 0)
}

// contentHeight returns the number of visible content lines (between header and footer).
func (m model) contentHeight() int {
	return max(m.height-2, 1) // header + footer
}

// ensureVisible adjusts scroll so the cursor is within the visible viewport.
func (m *model) ensureVisible() {
	ch := m.contentHeight()
	if m.cursor < m.scroll {
		m.scroll = m.cursor
	}
	if m.cursor >= m.scroll+ch {
		m.scroll = m.cursor - ch + 1
	}
	if m.scroll < 0 {
		m.scroll = 0
	}
}

// View renders the full TUI.
func (m model) View() string {
	if m.width == 0 || m.height == 0 {
		return ""
	}

	var b strings.Builder

	// Header
	headerStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("#FFFFFF")).
		Background(lipgloss.Color("#333333")).
		Width(m.width).
		Padding(0, 1)
	headerText := m.fileName
	if m.err != nil {
		headerText += "  [error: " + m.err.Error() + "]"
	}
	b.WriteString(headerStyle.Render(headerText))
	b.WriteString("\n")

	// Content area
	ch := m.contentHeight()
	endIdx := min(m.scroll+ch, len(m.nodes))

	linesRendered := 0
	for i := m.scroll; i < endIdx; i++ {
		selected := i == m.cursor
		b.WriteString(m.renderNode(m.nodes[i], selected))
		b.WriteString("\n")
		linesRendered++
	}

	// Fill remaining lines with empty space
	for linesRendered < ch {
		b.WriteString("\n")
		linesRendered++
	}

	// Footer
	done, total := m.countStats()
	footerLeft := fmt.Sprintf(" %d/%d done", done, total)
	footerRight := " q:quit  j/k:nav  h/l:fold  r:refresh "
	gap := max(m.width-lipgloss.Width(footerLeft)-lipgloss.Width(footerRight), 0)
	footerText := footerLeft + strings.Repeat(" ", gap) + footerRight

	footerStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#AAAAAA")).
		Background(lipgloss.Color("#222222")).
		Width(m.width)
	b.WriteString(footerStyle.Render(footerText))

	return b.String()
}

// renderNode renders a single node line.
func (m model) renderNode(n node, selected bool) string {
	w := max(m.width, 10)

	color := pastelColors[n.colorIdx%len(pastelColors)]
	indent := strings.Repeat("  ", n.depth)

	var line string
	if n.isSection {
		// Section heading with [done/total] badge
		done, total := sectionStats(n.section)
		isCollapsed := m.collapsed[n.key]

		arrow := "▼"
		if isCollapsed {
			arrow = "▶"
		}

		badge := fmt.Sprintf("[%d/%d]", done, total)

		headingStyle := lipgloss.NewStyle().
			Bold(true).
			Foreground(color)
		badgeStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("#888888"))

		line = indent + arrow + " " + headingStyle.Render(n.section.Heading) + " " + badgeStyle.Render(badge)
	} else {
		// Todo item
		checkbox := "[ ]"
		if n.item.Completed {
			checkbox = "[x]"
		}

		titleStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#DDDDDD"))
		if n.item.Completed {
			titleStyle = titleStyle.Strikethrough(true).Faint(true)
		}

		tagStr := ""
		if len(n.item.Tags) > 0 {
			tagStyle := lipgloss.NewStyle().Foreground(color).Faint(true)
			tagParts := make([]string, len(n.item.Tags))
			for i, tag := range n.item.Tags {
				tagParts[i] = "[" + tag + "]"
			}
			tagStr = " " + tagStyle.Render(strings.Join(tagParts, " "))
		}

		checkStyle := lipgloss.NewStyle().Foreground(color)
		line = indent + checkStyle.Render(checkbox) + " " + titleStyle.Render(n.item.Title) + tagStr
	}

	// Apply selection highlight
	if selected {
		cursorStyle := lipgloss.NewStyle().
			Background(lipgloss.Color("#3A3A3A")).
			Width(w)
		return cursorStyle.Render(">" + line)
	}

	// Pad to full width
	padStyle := lipgloss.NewStyle().Width(w)
	return padStyle.Render(" " + line)
}

// sectionStats returns (done, total) counts for a section and all its descendants.
func sectionStats(s *TodoSection) (int, int) {
	done := 0
	total := 0
	for _, item := range s.Items {
		total++
		if item.Completed {
			done++
		}
	}
	for i := range s.Subsections {
		d, t := sectionStats(&s.Subsections[i])
		done += d
		total += t
	}
	return done, total
}

// countStats returns (done, total) across all sections.
func (m model) countStats() (int, int) {
	done := 0
	total := 0
	for i := range m.sections {
		d, t := sectionStats(&m.sections[i])
		done += d
		total += t
	}
	return done, total
}
