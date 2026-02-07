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
