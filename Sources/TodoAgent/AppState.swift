import SwiftUI
import Observation

@Observable
@MainActor
final class AppState {
    var windowVisible = true
    var chooseFile = false
    var collapseAllToggle = false

    func performChooseFile(watcher: DirectoryWatcher) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.message = "Select a markdown TODO file"

        let response = panel.runModal()
        NSApp.setActivationPolicy(.accessory)

        if response == .OK, let url = panel.url {
            watcher.watch(file: url)
        }
    }
}
