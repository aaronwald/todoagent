import SwiftUI

@main
struct TodoAgentApp: App {
    @StateObject private var watcher = DirectoryWatcher()
    @StateObject private var usage = ClaudeUsageWatcher()
    @State private var appState = AppState()
    @State private var hasLaunched = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            Button("Show Window") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("t")

            Button("Choose File...") {
                appState.performChooseFile(watcher: watcher)
                // Ensure window is visible after picking a file
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Collapse All") {
                appState.collapseAllToggle.toggle()
            }

            Button("Refresh") {
                watcher.scanFile()
            }

            Divider()

            Button("About TodoAgent") {
                openWindow(id: "about")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
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
            .onAppear {
                guard !hasLaunched else { return }
                hasLaunched = true
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        Window("TodoAgent", id: "main") {
            MenuBarView(watcher: watcher, usage: usage)
                .environment(appState)
                .onAppear {
                    watcher.restoreLastFile()
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultPosition(.topTrailing)

        Window("About TodoAgent", id: "about") {
            AboutView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 200)
    }

    private func allItems(in section: TodoSection) -> [TodoItem] {
        section.items + section.subsections.flatMap { allItems(in: $0) }
    }
}
