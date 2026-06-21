import SwiftUI
import AppKit
@main
struct ClaudeCodePanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    init() { NSApplication.shared.setActivationPolicy(.regular) }
    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: 720, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 650)
        .windowResizability(.contentMinSize)
    }
}
