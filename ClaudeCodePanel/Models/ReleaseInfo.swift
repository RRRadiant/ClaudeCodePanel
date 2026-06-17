import Foundation

/// A GitHub Release as returned by the GitHub API.
struct ReleaseInfo: Identifiable, Sendable {
    let id: Int
    let version: String       // e.g. "1.9"
    let name: String          // e.g. "v1.9 — New Features"
    let body: String          // Release notes (markdown)
    let htmlURL: URL
    let downloadURL: URL?     // .dmg asset URL
    let publishedAt: Date
    let isNewer: Bool         // true if this release > current app version
}
