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
