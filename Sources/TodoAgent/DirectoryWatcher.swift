import Foundation
import SwiftUI

@MainActor
final class DirectoryWatcher: ObservableObject {
    @Published var files: [TodoFile] = []
    @Published var changedItemKeys: Set<String> = []
    @Published var itemChangeKeys: [String: String] = [:]  // item.id -> change tracking key

    private var fileURL: URL?
    private var previousItems: [String: Bool] = [:]
    private nonisolated(unsafe) var eventStream: FSEventStreamRef?

    private static let lastFileKey = "lastOpenedFile"

    func watch(file: URL) {
        stop()
        self.fileURL = file
        UserDefaults.standard.set(file.path, forKey: Self.lastFileKey)
        scanFile()
        startFSEvents(for: file.deletingLastPathComponent())
    }

    func restoreLastFile() {
        if let path = UserDefaults.standard.string(forKey: Self.lastFileKey) {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                watch(file: url)
            }
        }
    }

    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    func scanFile() {
        guard let fileURL = fileURL else { return }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }

        let sections = MarkdownParser.parse(content: content)
        let file = TodoFile(id: fileURL.path, name: fileURL.lastPathComponent, path: fileURL.path, sections: sections)

        var newItems: [String: Bool] = [:]
        var changed: Set<String> = []
        var titleCounts: [String: Int] = [:]
        var newItemChangeKeys: [String: String] = [:]

        for item in allItems(in: sections) {
            let base = "\(fileURL.lastPathComponent):\(item.title)"
            let occ = titleCounts[base, default: 0]
            titleCounts[base] = occ + 1
            let key = "\(base)#\(occ)"

            newItemChangeKeys[item.id] = key
            newItems[key] = item.isCompleted

            if let oldCompleted = previousItems[key] {
                if oldCompleted != item.isCompleted {
                    changed.insert(key)
                }
            } else if !previousItems.isEmpty {
                changed.insert(key)
            }
        }

        self.files = [file]
        self.previousItems = newItems
        self.itemChangeKeys = newItemChangeKeys
        if !changed.isEmpty {
            // Merge new changes with any unacknowledged ones
            self.changedItemKeys = self.changedItemKeys.union(changed)
            NSApp.requestUserAttention(.informationalRequest)
        }
    }

    func acknowledgeChanges(for keys: Set<String>) {
        changedItemKeys.subtract(keys)
    }

    private func allItems(in sections: [TodoSection]) -> [TodoItem] {
        sections.flatMap { section in
            section.items + allItems(in: section.subsections)
        }
    }

    private func startFSEvents(for directory: URL) {
        let path = directory.path as CFString
        var context = FSEventStreamContext()

        let unmanagedSelf = Unmanaged.passRetained(self)
        context.info = unmanagedSelf.toOpaque()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in
                watcher.scanFile()
            }
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
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
