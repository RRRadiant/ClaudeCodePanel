import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class UpdateViewModel {
    var updateStatus: UpdateStatus = .idle
    var latestRelease: ReleaseInfo?

    enum UpdateStatus: Equatable {
        case idle
        case checking
        case upToDate(currentVersion: String)
        case updateAvailable(version: String, notes: String)
        case error(String)
    }

    private let updateService = UpdateService.shared

    /// Current app version from bundle.
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    func checkForUpdates() async {
        updateStatus = .checking
        latestRelease = nil

        do {
            if let release = try await updateService.checkForUpdate() {
                latestRelease = release
                updateStatus = .updateAvailable(
                    version: release.version,
                    notes: release.body
                )
            } else {
                updateStatus = .upToDate(currentVersion: currentVersion)
            }
        } catch {
            updateStatus = .error(error.localizedDescription)
        }
    }

    /// Open the latest release page in the default browser.
    func openReleasePage() {
        guard let release = latestRelease else { return }
        NSWorkspace.shared.open(release.htmlURL)
    }

    /// Open the DMG download directly.
    func downloadUpdate() {
        guard let url = latestRelease?.downloadURL else {
            openReleasePage()
            return
        }
        NSWorkspace.shared.open(url)
    }
}
