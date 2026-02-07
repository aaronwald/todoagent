# Todo Menu Bar App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu bar app that monitors a directory of markdown files and displays todo items grouped by heading sections with pastel colors, collapse/expand, and flash-on-change animations.

**Architecture:** SwiftUI menu bar app using `MenuBarExtra` (macOS 13+). `FSEvents` via `DispatchSource` monitors the chosen directory for `.md` file changes. A parser converts markdown headings + checkboxes into a section tree model. The view diffs against the previous state to trigger flash animations on changed items.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (for `NSStatusItem` fallback if needed), Swift Package Manager, Swift Testing framework

---

### Task 1: Project Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/TodoAgent/TodoAgentApp.swift`
- Create: `Sources/TodoAgent/MenuBarView.swift`
- Create: `Tests/TodoAgentTests/PlaceholderTests.swift`

**Step 1: Initialize Swift package**

Run:
```bash
cd /Users/aaronwald/repos/todoagent
swift package init --type executable --enable-swift-testing --name TodoAgent
```

**Step 2: Replace Package.swift with macOS app configuration**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TodoAgent",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TodoAgent",
            path: "Sources/TodoAgent"
        ),
        .testTarget(
            name: "TodoAgentTests",
            dependencies: ["TodoAgent"],
            path: "Tests/TodoAgentTests"
        ),
    ]
)
```

**Step 3: Create minimal menu bar app entry point**

`Sources/TodoAgent/TodoAgentApp.swift`:
```swift
import SwiftUI

@main
struct TodoAgentApp: App {
    var body: some Scene {
        MenuBarExtra("TodoAgent", systemImage: "checklist") {
            Text("TodoAgent")
                .padding()
        }
    }
}
```

Remove auto-generated `main.swift` if it exists (conflicts with `@main`).

**Step 4: Build and verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 5: Commit**

```bash
git init
git add Package.swift Sources/ Tests/ CLAUDE.md docs/
git commit -m "feat: scaffold macOS menu bar app with SwiftUI MenuBarExtra"
```

---

### Task 2: Markdown Parser — Data Model

**Files:**
- Create: `Sources/TodoAgent/Models.swift`
- Create: `Tests/TodoAgentTests/ModelsTests.swift`

**Step 1: Write the failing test**

`Tests/TodoAgentTests/ModelsTests.swift`:
```swift
import Testing
@testable import TodoAgent

@Test func todoItemCreation() {
    let item = TodoItem(title: "Fix bug", isCompleted: false, line: 5, tags: ["ssmd"])
    #expect(item.title == "Fix bug")
    #expect(item.isCompleted == false)
    #expect(item.line == 5)
    #expect(item.tags == ["ssmd"])
}

@Test func todoSectionCreation() {
    let item = TodoItem(title: "Task 1", isCompleted: false, line: 3, tags: [])
    let section = TodoSection(
        heading: "Active",
        level: 3,
        items: [item],
        subsections: [],
        allCompleted: false
    )
    #expect(section.heading == "Active")
    #expect(section.level == 3)
    #expect(section.items.count == 1)
}

@Test func todoFileCreation() {
    let file = TodoFile(
        name: "TODO.md",
        path: "/tmp/TODO.md",
        sections: []
    )
    #expect(file.name == "TODO.md")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — types not defined

**Step 3: Write the model types**

`Sources/TodoAgent/Models.swift`:
```swift
import Foundation

struct TodoItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let isCompleted: Bool
    let line: Int
    let tags: [String]

    static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        lhs.title == rhs.title && lhs.isCompleted == rhs.isCompleted && lhs.line == rhs.line
    }
}

struct TodoSection: Identifiable, Sendable {
    let id = UUID()
    let heading: String
    let level: Int
    let items: [TodoItem]
    let subsections: [TodoSection]
    let allCompleted: Bool
}

struct TodoFile: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let sections: [TodoSection]
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -20`
Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add Sources/TodoAgent/Models.swift Tests/TodoAgentTests/ModelsTests.swift
git commit -m "feat: add TodoItem, TodoSection, TodoFile data models"
```

---

### Task 3: Markdown Parser — Parsing Logic

**Files:**
- Create: `Sources/TodoAgent/MarkdownParser.swift`
- Create: `Tests/TodoAgentTests/MarkdownParserTests.swift`

**Step 1: Write the failing tests**

`Tests/TodoAgentTests/MarkdownParserTests.swift`:
```swift
import Testing
@testable import TodoAgent

@Test func parseSimpleCheckboxes() {
    let markdown = """
    ## Tasks
    - [ ] Uncompleted task
    - [x] Completed task
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections.count == 1)
    #expect(sections[0].heading == "Tasks")
    #expect(sections[0].level == 2)
    #expect(sections[0].items.count == 2)
    #expect(sections[0].items[0].isCompleted == false)
    #expect(sections[0].items[0].title == "Uncompleted task")
    #expect(sections[0].items[1].isCompleted == true)
}

@Test func parseNestedHeadings() {
    let markdown = """
    ## SSMD
    ### Active
    - [ ] Task A
    ### Pending
    - [ ] Task B
    - [ ] Task C
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections.count == 1)
    #expect(sections[0].heading == "SSMD")
    #expect(sections[0].subsections.count == 2)
    #expect(sections[0].subsections[0].heading == "Active")
    #expect(sections[0].subsections[0].items.count == 1)
    #expect(sections[0].subsections[1].heading == "Pending")
    #expect(sections[0].subsections[1].items.count == 2)
}

@Test func parseBoldTitleAndTags() {
    let markdown = """
    ## Work
    - [ ] **Multi-exchange secmaster** [ssmd] - Feb 7
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].items[0].title == "Multi-exchange secmaster")
    #expect(sections[0].items[0].tags == ["ssmd"])
}

@Test func parseAllCompletedSection() {
    let markdown = """
    ## Done
    - [x] Task A
    - [x] Task B
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].allCompleted == true)
}

@Test func parseLineNumbers() {
    let markdown = """
    ## Section
    - [ ] First
    - [ ] Second
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].items[0].line == 2)
    #expect(sections[0].items[1].line == 3)
}

@Test func ignoreNonCheckboxContent() {
    let markdown = """
    ## Summary
    | Col1 | Col2 |
    |------|------|
    | a    | b    |

    Some paragraph text.

    - [ ] Real task
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].items.count == 1)
    #expect(sections[0].items[0].title == "Real task")
}

@Test func parseDeeplyNested() {
    let markdown = """
    ## Domain
    ### Category
    #### Subcategory
    - [ ] Deep task
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].heading == "Domain")
    #expect(sections[0].subsections[0].heading == "Category")
    #expect(sections[0].subsections[0].subsections[0].heading == "Subcategory")
    #expect(sections[0].subsections[0].subsections[0].items[0].title == "Deep task")
}

@Test func parseEmptyContent() {
    let sections = MarkdownParser.parse(content: "")
    #expect(sections.isEmpty)
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — MarkdownParser not defined

**Step 3: Implement MarkdownParser**

`Sources/TodoAgent/MarkdownParser.swift`:
```swift
import Foundation

enum MarkdownParser {
    static func parse(content: String) -> [TodoSection] {
        let lines = content.components(separatedBy: "\n")
        var rootSections: [TodoSection] = []
        var stack: [(level: Int, heading: String, items: [TodoItem], subsections: [TodoSection])] = []

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if let headingMatch = parseHeading(line) {
                let (level, heading) = headingMatch
                // Pop stack back to parent level
                while let last = stack.last, last.level >= level {
                    let popped = stack.removeLast()
                    let section = buildSection(from: popped)
                    if var parent = stack.last {
                        stack[stack.count - 1].subsections.append(section)
                    } else {
                        rootSections.append(section)
                    }
                }
                stack.append((level: level, heading: heading, items: [], subsections: []))
            } else if let item = parseCheckbox(line, lineNumber: lineNumber) {
                if stack.isEmpty {
                    continue // checkbox outside any heading — skip
                }
                stack[stack.count - 1].items.append(item)
            }
        }

        // Flush remaining stack
        while let popped = stack.popLast() {
            let section = buildSection(from: popped)
            if stack.isEmpty {
                rootSections.append(section)
            } else {
                stack[stack.count - 1].subsections.append(section)
            }
        }

        return rootSections
    }

    private static func parseHeading(_ line: String) -> (Int, String)? {
        var level = 0
        for char in line {
            if char == "#" { level += 1 }
            else { break }
        }
        guard level >= 2 else { return nil }
        let heading = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        guard !heading.isEmpty else { return nil }
        return (level, heading)
    }

    private static func parseCheckbox(_ line: String, lineNumber: Int) -> TodoItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let isCompleted: Bool
        let rest: String

        if trimmed.hasPrefix("- [ ] ") {
            isCompleted = false
            rest = String(trimmed.dropFirst(6))
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            isCompleted = true
            rest = String(trimmed.dropFirst(6))
        } else {
            return nil
        }

        let title = extractTitle(from: rest)
        let tags = extractTags(from: rest)

        return TodoItem(title: title, isCompleted: isCompleted, line: lineNumber, tags: tags)
    }

    private static func extractTitle(from text: String) -> String {
        var title = text
        // Extract bold title if present: **Title**
        if let boldStart = title.range(of: "**"),
           let boldEnd = title[boldStart.upperBound...].range(of: "**") {
            title = String(title[boldStart.upperBound..<boldEnd.lowerBound])
        } else {
            // Take text up to first tag or date marker
            if let bracketRange = title.range(of: " [") {
                title = String(title[..<bracketRange.lowerBound])
            }
            if let dashRange = title.range(of: " - ") {
                title = String(title[..<dashRange.lowerBound])
            }
        }
        return title.trimmingCharacters(in: .whitespaces)
    }

    private static func extractTags(from text: String) -> [String] {
        var tags: [String] = []
        let scanner = text as NSString
        var searchRange = NSRange(location: 0, length: scanner.length)
        // Match [tag] but not [ ] or [x]
        while let range = scanner.range(of: "\\[([a-zA-Z][a-zA-Z0-9/]*)\\]",
                                          options: .regularExpression,
                                          range: searchRange).toOptional() {
            let full = scanner.substring(with: range)
            let tag = String(full.dropFirst().dropLast())
            tags.append(tag)
            searchRange = NSRange(location: range.upperBound,
                                  length: scanner.length - range.upperBound)
        }
        return tags
    }

    private static func buildSection(
        from entry: (level: Int, heading: String, items: [TodoItem], subsections: [TodoSection])
    ) -> TodoSection {
        let allItems = entry.items + entry.subsections.flatMap { allItemsIn($0) }
        let allCompleted = !allItems.isEmpty && allItems.allSatisfy(\.isCompleted)
        return TodoSection(
            heading: entry.heading,
            level: entry.level,
            items: entry.items,
            subsections: entry.subsections,
            allCompleted: allCompleted
        )
    }

    private static func allItemsIn(_ section: TodoSection) -> [TodoItem] {
        section.items + section.subsections.flatMap { allItemsIn($0) }
    }
}

// Helper to make NSRange work with optionals
extension NSRange {
    func toOptional() -> NSRange? {
        location == NSNotFound ? nil : self
    }
}
```

**Step 4: Run tests**

Run: `swift test 2>&1 | tail -30`
Expected: All 8 parser tests PASS

**Step 5: Commit**

```bash
git add Sources/TodoAgent/MarkdownParser.swift Tests/TodoAgentTests/MarkdownParserTests.swift
git commit -m "feat: implement markdown parser for headings, checkboxes, tags"
```

---

### Task 4: Directory Watcher

**Files:**
- Create: `Sources/TodoAgent/DirectoryWatcher.swift`

**Step 1: Implement FSEvents-based directory watcher**

`Sources/TodoAgent/DirectoryWatcher.swift`:
```swift
import Foundation

@MainActor
final class DirectoryWatcher: ObservableObject {
    @Published var files: [TodoFile] = []
    @Published var changedItemKeys: Set<String> = []

    private var directoryURL: URL?
    private var previousItems: [String: Bool] = [:]  // "file:line:title" -> isCompleted
    private var eventStream: FSEventStreamRef?

    func watch(directory: URL) {
        stop()
        self.directoryURL = directory
        scanFiles()
        startFSEvents(for: directory)
    }

    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    func scanFiles() {
        guard let dir = directoryURL else { return }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }

        let mdFiles = contents.filter { $0.pathExtension == "md" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        var newFiles: [TodoFile] = []
        var newItems: [String: Bool] = [:]
        var changed: Set<String> = []

        for fileURL in mdFiles {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let sections = MarkdownParser.parse(content: content)
            let file = TodoFile(name: fileURL.lastPathComponent, path: fileURL.path, sections: sections)
            newFiles.append(file)

            // Track items for change detection
            for item in allItems(in: sections) {
                let key = "\(fileURL.lastPathComponent):\(item.title)"
                newItems[key] = item.isCompleted

                if let oldCompleted = previousItems[key] {
                    if oldCompleted != item.isCompleted {
                        changed.insert(key)
                    }
                } else if !previousItems.isEmpty {
                    // New item added after initial scan
                    changed.insert(key)
                }
            }
        }

        self.files = newFiles
        self.previousItems = newItems
        if !changed.isEmpty {
            self.changedItemKeys = changed
            // Clear flash after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                self.changedItemKeys = []
            }
        }
    }

    private func allItems(in sections: [TodoSection]) -> [TodoItem] {
        sections.flatMap { section in
            section.items + allItems(in: section.subsections)
        }
    }

    private func startFSEvents(for directory: URL) {
        let path = directory.path as CFString
        var context = FSEventStreamContext()

        // Store a reference to self via Unmanaged pointer
        let unmanagedSelf = Unmanaged.passRetained(self)
        context.info = unmanagedSelf.toOpaque()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in
                watcher.scanFiles()
            }
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // 500ms latency
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    deinit {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/TodoAgent/DirectoryWatcher.swift
git commit -m "feat: add FSEvents-based directory watcher with change detection"
```

---

### Task 5: Pastel Color Theme

**Files:**
- Create: `Sources/TodoAgent/PastelTheme.swift`

**Step 1: Create pastel color palette**

`Sources/TodoAgent/PastelTheme.swift`:
```swift
import SwiftUI

enum PastelTheme {
    static let colors: [Color] = [
        Color(red: 0.68, green: 0.85, blue: 0.95),  // soft blue
        Color(red: 0.70, green: 0.93, blue: 0.73),  // soft green
        Color(red: 1.00, green: 0.85, blue: 0.73),  // soft peach
        Color(red: 0.80, green: 0.73, blue: 0.95),  // soft lavender
        Color(red: 0.68, green: 0.95, blue: 0.88),  // soft mint
        Color(red: 0.98, green: 0.73, blue: 0.78),  // soft rose
        Color(red: 0.95, green: 0.93, blue: 0.68),  // soft yellow
        Color(red: 0.88, green: 0.78, blue: 0.95),  // soft orchid
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }

    static func lightened(_ color: Color, by amount: Double = 0.3) -> Color {
        color.opacity(1.0 - amount)
    }
}
```

**Step 2: Build**

Run: `swift build 2>&1 | tail -5`
Expected: PASS

**Step 3: Commit**

```bash
git add Sources/TodoAgent/PastelTheme.swift
git commit -m "feat: add pastel color theme palette"
```

---

### Task 6: Section View — Collapsible Sections with Items

**Files:**
- Create: `Sources/TodoAgent/SectionView.swift`
- Create: `Sources/TodoAgent/TodoItemView.swift`

**Step 1: Create TodoItemView**

`Sources/TodoAgent/TodoItemView.swift`:
```swift
import SwiftUI

struct TodoItemView: View {
    let item: TodoItem
    let fileName: String
    let isFlashing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundColor(item.isCompleted ? .secondary : .primary)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12))
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(3)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isFlashing ? Color.accentColor : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: isFlashing)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            openInEditor(file: fileName, line: item.line)
        }
    }

    private func openInEditor(file: String, line: Int) {
        NSWorkspace.shared.open(URL(fileURLWithPath: file))
    }
}
```

**Step 2: Create SectionView**

`Sources/TodoAgent/SectionView.swift`:
```swift
import SwiftUI

struct SectionView: View {
    let section: TodoSection
    let fileName: String
    let colorIndex: Int
    let depth: Int
    let changedItemKeys: Set<String>

    @State private var isExpanded: Bool

    init(section: TodoSection, fileName: String, colorIndex: Int, depth: Int, changedItemKeys: Set<String>) {
        self.section = section
        self.fileName = fileName
        self.colorIndex = colorIndex
        self.depth = depth
        self.changedItemKeys = changedItemKeys
        self._isExpanded = State(initialValue: !section.allCompleted)
    }

    private var hasChangedDescendant: Bool {
        let fileBase = URL(fileURLWithPath: fileName).lastPathComponent
        return allItems(in: section).contains { item in
            changedItemKeys.contains("\(fileBase):\(item.title)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Text(section.heading)
                        .font(.system(size: depth == 0 ? 13 : 12, weight: depth == 0 ? .semibold : .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    let stats = itemStats(section)
                    Text("\(stats.unchecked)/\(stats.total)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(hasChangedDescendant && !isExpanded ? Color.accentColor : Color.clear, lineWidth: 2)
                    .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: hasChangedDescendant)
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(section.items) { item in
                        let fileBase = URL(fileURLWithPath: fileName).lastPathComponent
                        let key = "\(fileBase):\(item.title)"
                        TodoItemView(
                            item: item,
                            fileName: fileName,
                            isFlashing: changedItemKeys.contains(key)
                        )
                        .padding(.leading, CGFloat(depth) * 8 + 16)
                    }

                    ForEach(Array(section.subsections.enumerated()), id: \.element.id) { idx, sub in
                        SectionView(
                            section: sub,
                            fileName: fileName,
                            colorIndex: colorIndex,
                            depth: depth + 1,
                            changedItemKeys: changedItemKeys
                        )
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .background(
            PastelTheme.color(for: colorIndex)
                .opacity(depth == 0 ? 0.15 : 0.08)
        )
        .cornerRadius(depth == 0 ? 6 : 4)
    }

    private func itemStats(_ section: TodoSection) -> (unchecked: Int, total: Int) {
        let items = allItems(in: section)
        let total = items.count
        let unchecked = items.filter { !$0.isCompleted }.count
        return (unchecked, total)
    }

    private func allItems(in section: TodoSection) -> [TodoItem] {
        section.items + section.subsections.flatMap { allItems(in: $0) }
    }
}
```

**Step 3: Build**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/TodoAgent/SectionView.swift Sources/TodoAgent/TodoItemView.swift
git commit -m "feat: add collapsible section and todo item views with flash animation"
```

---

### Task 7: Main Menu Bar View — Full Popover

**Files:**
- Modify: `Sources/TodoAgent/MenuBarView.swift`
- Modify: `Sources/TodoAgent/TodoAgentApp.swift`

**Step 1: Create the main popover content view**

`Sources/TodoAgent/MenuBarView.swift`:
```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var watcher: DirectoryWatcher

    var body: some View {
        VStack(spacing: 0) {
            if watcher.files.isEmpty {
                emptyState
            } else {
                fileList
            }

            Divider()
            bottomBar
        }
        .frame(width: 380)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No directory selected")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Button("Choose Folder...") {
                chooseDirectory()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding()
    }

    @ViewBuilder
    private var fileList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(watcher.files) { file in
                    if !file.sections.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            if watcher.files.count > 1 {
                                Text(file.name)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 4)
                            }

                            ForEach(Array(file.sections.enumerated()), id: \.element.id) { idx, section in
                                SectionView(
                                    section: section,
                                    fileName: file.path,
                                    colorIndex: idx,
                                    depth: 0,
                                    changedItemKeys: watcher.changedItemKeys
                                )
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 500)
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack {
            Button(action: chooseDirectory) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Choose folder...")

            if let dir = watcher.files.first.map({ URL(fileURLWithPath: $0.path).deletingLastPathComponent().lastPathComponent }) {
                Text(dir)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            let totalUnchecked = watcher.files.flatMap(\.sections).flatMap { allItems(in: $0) }.filter { !$0.isCompleted }.count
            Text("\(totalUnchecked) remaining")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Button(action: { watcher.scanFiles() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory containing markdown TODO files"

        if panel.runModal() == .OK, let url = panel.url {
            watcher.watch(directory: url)
        }
    }

    private func allItems(in section: TodoSection) -> [TodoItem] {
        section.items + section.subsections.flatMap { allItems(in: $0) }
    }
}
```

**Step 2: Update app entry point**

`Sources/TodoAgent/TodoAgentApp.swift`:
```swift
import SwiftUI

@main
struct TodoAgentApp: App {
    @StateObject private var watcher = DirectoryWatcher()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(watcher: watcher)
        } label: {
            let count = watcher.files
                .flatMap(\.sections)
                .flatMap { allItems(in: $0) }
                .filter { !$0.isCompleted }
                .count
            HStack(spacing: 2) {
                Image(systemName: "checklist")
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func allItems(in section: TodoSection) -> [TodoItem] {
        section.items + section.subsections.flatMap { allItems(in: $0) }
    }
}
```

**Step 3: Build**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/TodoAgent/MenuBarView.swift Sources/TodoAgent/TodoAgentApp.swift
git commit -m "feat: implement full menu bar popover with folder picker and item count badge"
```

---

### Task 8: Integration Test with Real TODO File

**Files:**
- Create: `Tests/TodoAgentTests/IntegrationTests.swift`

**Step 1: Write integration test that parses a real-world-style TODO**

`Tests/TodoAgentTests/IntegrationTests.swift`:
```swift
import Testing
@testable import TodoAgent

@Test func parseRealWorldTodo() {
    let markdown = """
    # Project Roadmap

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
    - [x] Sync Google Drive to Brooklyn NAS
    """

    let sections = MarkdownParser.parse(content: markdown)

    // Top-level sections
    #expect(sections.count == 2)
    #expect(sections[0].heading == "SSMD (Market Data)")
    #expect(sections[1].heading == "Platform Infrastructure")

    // SSMD subsections
    #expect(sections[0].subsections.count == 3)
    #expect(sections[0].subsections[0].heading == "Active")
    #expect(sections[0].subsections[0].items.count == 2)

    // Pending has sub-subsections
    let pending = sections[0].subsections[1]
    #expect(pending.heading == "Pending")
    #expect(pending.subsections.count == 2)
    #expect(pending.subsections[0].heading == "Data Pipeline")
    #expect(pending.subsections[0].items.count == 2)

    // Completed section should be allCompleted
    let completed = sections[0].subsections[2]
    #expect(completed.heading == "Completed (Recent)")
    #expect(completed.allCompleted == true)

    // Tags parsed correctly
    #expect(sections[0].subsections[0].items[0].tags == ["ssmd"])
    #expect(sections[0].subsections[0].items[0].title == "Multi-exchange secmaster")

    // Platform infra
    #expect(sections[1].subsections[0].heading == "Pending")
    #expect(sections[1].subsections[0].items.count == 2)
    #expect(sections[1].subsections[1].allCompleted == true)
}

@Test func itemCountAcrossNesting() {
    let markdown = """
    ## Root
    - [ ] A
    ### Sub1
    - [ ] B
    - [x] C
    #### Deep
    - [ ] D
    """
    let sections = MarkdownParser.parse(content: markdown)
    // Root should NOT be allCompleted (has unchecked descendants)
    #expect(sections[0].allCompleted == false)
    // Root direct items
    #expect(sections[0].items.count == 1)
    // Sub1 direct items
    #expect(sections[0].subsections[0].items.count == 2)
    // Deep items
    #expect(sections[0].subsections[0].subsections[0].items.count == 1)
}
```

**Step 2: Run all tests**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS (8 parser + 2 integration + 3 model = 13 total)

**Step 3: Commit**

```bash
git add Tests/TodoAgentTests/IntegrationTests.swift
git commit -m "test: add integration tests with real-world TODO format"
```

---

### Task 9: Polish & Run

**Step 1: Build and run the app**

Run:
```bash
swift build -c release 2>&1 | tail -5
```

**Step 2: Test launch**

Run:
```bash
.build/release/TodoAgent &
```
Expected: App appears in the menu bar with a checklist icon

**Step 3: Run all tests one final time**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS

**Step 4: Update CLAUDE.md with build commands**

Add build/test commands to `CLAUDE.md`.

**Step 5: Final commit**

```bash
git add -A
git commit -m "docs: update CLAUDE.md with build and test instructions"
```

---

## Summary

| Task | Description | Tests |
|------|-------------|-------|
| 1 | Project scaffold + minimal MenuBarExtra | build check |
| 2 | Data models (TodoItem, TodoSection, TodoFile) | 3 |
| 3 | Markdown parser (headings, checkboxes, tags, nesting) | 8 |
| 4 | FSEvents directory watcher + change detection | build check |
| 5 | Pastel color palette | build check |
| 6 | SectionView + TodoItemView (collapsible, flash) | build check |
| 7 | Full MenuBarView popover + app wiring | build check |
| 8 | Integration tests with real-world format | 2 |
| 9 | Release build, launch test, docs | — |
