import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        // Auto-check for updates on launch (silent, shows alert only if update found)
        Task { await performAutoUpdateCheck() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Auto-update check

    private func performAutoUpdateCheck() async {
        let release: ReleaseInfo?
        do {
            release = try await UpdateService.shared.checkForUpdate()
        } catch {
            return // Silent on network failure
        }

        guard let release else { return }

        let alert = NSAlert()
        alert.messageText = "发现新版本"
        alert.informativeText = "Claude Code Panel \(release.version) 已发布。当前版本: \(currentVersion)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载更新")
        alert.addButton(withTitle: "稍后提醒")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = release.downloadURL {
                NSWorkspace.shared.open(url)
            } else {
                NSWorkspace.shared.open(release.htmlURL)
            }
        }
    }

    private var currentVersion: String {
        Bundle.appVersion
    }
}
