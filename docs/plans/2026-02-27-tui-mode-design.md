# TUI Mode Design

## Summary

Add a terminal UI mode to TodoAgent as a Go program using Bubble Tea, living in `tui/` subdirectory. Read-only dashboard that watches a single markdown file and renders todo items grouped by heading sections. Designed to run in a cmux pane alongside coding sessions.

## Decisions

- **Separate Go module** in `tui/` — no coupling to the Swift menu bar app
- **Go + Bubble Tea** — best-in-class TUI ecosystem, single static binary
- **Single-file watcher** — `todoagent-tui <file.md>`, live-updates via fsnotify
- **Read-only** — matches existing app philosophy, no editing in the TUI
- **Port the parser** — faithful reimplementation of Swift MarkdownParser logic

## Project Structure

```
tui/
├── go.mod
├── go.sum
├── main.go              # Entry point, arg parsing, file validation
├── parser.go            # Markdown parser (port of Swift MarkdownParser)
├── parser_test.go       # Parser tests (port of Swift tests)
├── model.go             # Bubble Tea model (state, update, view)
└── watcher.go           # fsnotify file watcher -> Bubble Tea message
```

## Dependencies

- `github.com/charmbracelet/bubbletea` — TUI framework
- `github.com/charmbracelet/lipgloss` — Styling (colors, borders, padding)
- `github.com/fsnotify/fsnotify` — File system notifications

## Data Types

Port from Swift Models.swift:

- `TodoItem` — title, completed, line, tags, details
- `TodoSection` — heading, level, items, subsections, allCompleted
- `TodoFile` — name, path, sections

## Parser

Faithful port of Swift MarkdownParser:

- Heading levels ##-#### (# ignored as document title)
- Checkbox patterns `- [ ]` and `- [x]`/`- [X]`
- Bold title extraction `**title**`, fallback to text before tags
- Tag extraction regex `\[([a-zA-Z][a-zA-Z0-9/]*)\]`
- Detail lines collected after checkboxes
- Stack-based nesting algorithm
- `allCompleted` computed recursively

## TUI Layout

```
┌─ todos.md ──────────────────────────────────┐
│ ## SSMD                              [3/5]   │
│   ### Active                         [2/3]   │
│     ☐ Fix connector timeout [ssmd]           │
│     ☑ Add retry logic [ssmd]                 │
│     ☐ Update docs                            │
│   ### Backlog                        [1/2]   │
│     ☑ Research caching                       │
│     ☐ Profile memory usage                   │
│ ## Personal                          [0/2]   │
│   ☐ Grocery list                             │
│   ☐ Call dentist                             │
│                                              │
├──────────────────────────────────────────────┤
│ 4/12 done  ↑↓ navigate  ←→ collapse  q quit │
└──────────────────────────────────────────────┘
```

## Colors

Port the 8-color pastel palette from PastelTheme.swift:
- blue, green, peach, lavender, mint, rose, yellow, orchid
- Each top-level section gets a distinct color
- Completed items dimmed/strikethrough

## Keybindings

- `↑`/`↓` or `j`/`k` — move cursor between sections and items
- `←`/`→` or `h`/`l` — collapse/expand sections
- `q` or `Ctrl+C` — quit
- `r` — manual refresh

## File Watching

- fsnotify watches the target file
- Write and Create events trigger re-parse (handles atomic-write editors)
- 100ms debounce for rapid events
- Watcher goroutine sends parsed results to Bubble Tea via tea.Cmd
- Cursor position preserved across updates

## Error Handling

- File not found at startup: print error, exit
- File deleted while watching: show "File removed, waiting..." message, keep watching
- Permission errors: display in status bar

## Usage

```
todoagent-tui <file.md>
```
