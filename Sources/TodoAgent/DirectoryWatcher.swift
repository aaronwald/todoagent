import Foundation
import SwiftUI

@MainActor
final class DirectoryWatcher: ObservableObject {
    @Published var files: [TodoFile] = []
    @Published var changedItemKeys: Set<String> = []

    private var directoryURL: URL?
    private var previousItems: [String: Bool] = [:]
    private nonisolated(unsafe) var eventStream: FSEventStreamRef?

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

            for item in allItems(in: sections) {
                let key = "\(fileURL.lastPathComponent):\(item.title)"
                newItems[key] = item.isCompleted

                if let oldCompleted = previousItems[key] {
                    if oldCompleted != item.isCompleted {
                        changed.insert(key)
                    }
                } else if !previousItems.isEmpty {
                    changed.insert(key)
                }
            }
        }

        self.files = newFiles
        self.previousItems = newItems
        if !changed.isEmpty {
            self.changedItemKeys = changed
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
