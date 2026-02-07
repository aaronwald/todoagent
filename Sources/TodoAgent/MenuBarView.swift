import SwiftUI

struct MenuBarView: View {
    @ObservedObject var watcher: DirectoryWatcher
    @Environment(AppState.self) private var appState: AppState?

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
        .frame(minWidth: 420, maxWidth: .infinity)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.questionmark")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No file selected")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("Use the menu bar icon to choose a file")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.6))
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
                            ForEach(Array(file.sections.enumerated()), id: \.element.id) { idx, section in
                                SectionView(
                                    section: section,
                                    fileName: file.path,
                                    colorIndex: idx,
                                    depth: 0,
                                    changedItemKeys: watcher.changedItemKeys,
                                    onAcknowledge: { keys in
                                        watcher.acknowledgeChanges(for: keys)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
        .frame(minHeight: 200, maxHeight: .infinity)
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack {
            if let name = watcher.files.first?.name {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            let totalUnchecked = watcher.files.flatMap(\.sections).flatMap { allItems(in: $0) }.filter { !$0.isCompleted }.count
            Text("\(totalUnchecked) remaining")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func allItems(in section: TodoSection) -> [TodoItem] {
        section.items + section.subsections.flatMap { allItems(in: $0) }
    }
}
