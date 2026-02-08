# TodoAgent

A native macOS menu bar app that monitors markdown files and displays todo items (`- [ ]` / `- [x]`) grouped by heading sections. Built with SwiftUI using `MenuBarExtra`.

## Features

- Watches a markdown file for changes via FSEvents and updates in real-time
- Parses `##`-`####` headings into collapsible nested sections with pastel colors
- Extracts checkboxes, bold titles, and `[tag]` annotations
- Flash-on-change highlights when items are added or toggled
- Claude Code usage quota bars (5-hour and 7-day utilization from Anthropic API)
- Read-only viewer -- click any item to open the file in your default editor

## Requirements

- macOS 14+ (Sonoma)
- Swift 6.0+
- Xcode or Swift toolchain

## Build

```bash
# Debug build
swift build

# Release build
swift build -c release

# Build .app bundle (no Dock icon, no terminal window)
./scripts/bundle.sh
```

## Run

```bash
# Run the .app bundle
open TodoAgent.app

# Or run the binary directly
.build/release/TodoAgent
```

## Install

```bash
./scripts/bundle.sh
cp -r TodoAgent.app /Applications/
```

## Test

```bash
swift test
```

Requires Xcode (not just Command Line Tools) for the Swift Testing framework.

## License

MIT -- see [LICENSE](LICENSE).
