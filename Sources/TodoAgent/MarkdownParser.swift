import Foundation

enum MarkdownParser {
    static func parse(content: String) -> [TodoSection] {
        let lines = content.components(separatedBy: "\n")
        var rootSections: [TodoSection] = []
        var stack: [(level: Int, heading: String, items: [TodoItem], subsections: [TodoSection])] = []
        var pendingDetails: [String] = []

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if let headingMatch = parseHeading(line) {
                // Flush pending details to last item
                flushDetails(&pendingDetails, into: &stack)

                let (level, heading) = headingMatch
                while let last = stack.last, last.level >= level {
                    let popped = stack.removeLast()
                    let parentPath = stack.map(\.heading)
                    let section = buildSection(from: popped, parentPath: parentPath)
                    if stack.isEmpty {
                        rootSections.append(section)
                    } else {
                        stack[stack.count - 1].subsections.append(section)
                    }
                }
                stack.append((level: level, heading: heading, items: [], subsections: []))
            } else if let item = parseCheckbox(line, lineNumber: lineNumber) {
                // Flush pending details to previous item before starting a new one
                flushDetails(&pendingDetails, into: &stack)
                if !stack.isEmpty {
                    stack[stack.count - 1].items.append(item)
                }
            } else if !line.isEmpty, !stack.isEmpty, let last = stack.last, !last.items.isEmpty {
                // Non-empty line after a checkbox — collect as detail
                let detail = rawLine.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "^- ", with: "", options: .regularExpression)
                pendingDetails.append(detail)
            }
        }

        flushDetails(&pendingDetails, into: &stack)

        while let popped = stack.popLast() {
            let parentPath = stack.map(\.heading)
            let section = buildSection(from: popped, parentPath: parentPath)
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

        return TodoItem(id: title, title: title, isCompleted: isCompleted, line: lineNumber, tags: tags, details: [])
    }

    private static func extractTitle(from text: String) -> String {
        var title = text
        if let boldStart = title.range(of: "**"),
           let boldEnd = title[boldStart.upperBound...].range(of: "**") {
            title = String(title[boldStart.upperBound..<boldEnd.lowerBound])
        } else {
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
        let pattern = "\\[([a-zA-Z][a-zA-Z0-9/]*)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        for match in results {
            if match.numberOfRanges >= 2 {
                let tagRange = match.range(at: 1)
                tags.append(nsString.substring(with: tagRange))
            }
        }
        return tags
    }

    private static func buildSection(
        from entry: (level: Int, heading: String, items: [TodoItem], subsections: [TodoSection]),
        parentPath: [String]
    ) -> TodoSection {
        let allItems = entry.items + entry.subsections.flatMap { allItemsIn($0) }
        let allCompleted = allItems.isEmpty || allItems.allSatisfy(\.isCompleted)
        let idPath = (parentPath + [entry.heading]).joined(separator: "/")
        return TodoSection(
            id: idPath,
            heading: entry.heading,
            level: entry.level,
            items: entry.items,
            subsections: entry.subsections,
            allCompleted: allCompleted
        )
    }

    private static func flushDetails(
        _ details: inout [String],
        into stack: inout [(level: Int, heading: String, items: [TodoItem], subsections: [TodoSection])]
    ) {
        guard !details.isEmpty, !stack.isEmpty else {
            details.removeAll()
            return
        }
        let idx = stack.count - 1
        guard !stack[idx].items.isEmpty else {
            details.removeAll()
            return
        }
        let lastIdx = stack[idx].items.count - 1
        let old = stack[idx].items[lastIdx]
        stack[idx].items[lastIdx] = TodoItem(
            id: old.id, title: old.title, isCompleted: old.isCompleted,
            line: old.line, tags: old.tags, details: details
        )
        details.removeAll()
    }

    private static func allItemsIn(_ section: TodoSection) -> [TodoItem] {
        section.items + section.subsections.flatMap { allItemsIn($0) }
    }
}
