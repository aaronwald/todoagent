# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

TodoAgent is a native macOS menu bar app that monitors a directory of markdown files and displays todo items (`- [ ]` / `- [x]`) grouped by heading sections. Built with SwiftUI using `MenuBarExtra`.

## Build & Test

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run all tests (requires Xcode, not just Command Line Tools)
```

Run the app: `.build/release/TodoAgent`

## Architecture

- **Models.swift** — `TodoItem`, `TodoSection`, `TodoFile` data types
- **MarkdownParser.swift** — Parses markdown headings (`##`-`####`) into nested sections, extracts `- [ ]`/`- [x]` checkboxes, bold titles, and `[tag]` annotations
- **DirectoryWatcher.swift** — `@MainActor ObservableObject` using FSEvents to watch a directory for `.md` file changes, re-parses on change, tracks diffs for flash animation
- **PastelTheme.swift** — 8-color pastel palette, each top-level section gets a distinct color
- **SectionView.swift** — Recursive collapsible section with pastel background, item count badge, flash-on-change when collapsed
- **TodoItemView.swift** — Single checkbox item row with tags, click opens file in default editor
- **MenuBarView.swift** — Main popover: folder picker, scrollable section list, bottom bar with stats
- **TodoAgentApp.swift** — `@main` entry point, `MenuBarExtra` with `.window` style, badge count in menu bar

## Key Design Decisions

- Read-only viewer — no editing in-app, watches for external file changes
- No persistence — directory choice resets on quit, change tracking resets on restart
- `#` (h1) headings are ignored (document title); sections start at `##`
- Sections with all items completed are collapsed by default
- Swift 6 strict concurrency: `DirectoryWatcher` is `@MainActor`, FSEvents callback dispatches back to main actor
