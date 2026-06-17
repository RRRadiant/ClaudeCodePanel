import Foundation

/// Checks for new releases on GitHub and compares with the current app version.
final class UpdateService: @unchecked Sendable {
    static let shared = UpdateService()

    private let repoOwner = "RRRadiant"
    private let repoName = "ClaudeCodePanel"
    private let session = URLSession.shared

    // MARK: - Public API

    /// Returns the latest release from GitHub if it's newer than the current version.
    func checkForUpdate() async throws -> ReleaseInfo? {
        let latest = try await fetchLatestRelease()
        guard let currentVersion = currentAppVersion() else { return nil }
        let isNewer = compareVersions(latest.tag, isGreaterThan: currentVersion)
        guard isNewer else { return nil }

        return ReleaseInfo(
            id: latest.id,
            version: latest.tag,
            name: latest.name,
            body: latest.body,
            htmlURL: latest.htmlURL,
            downloadURL: latest.assetURL,
            publishedAt: latest.publishedAt,
            isNewer: true
        )
    }

    // MARK: - GitHub API

    private struct GHRelease: Decodable {
        let id: Int
        let tag_name: String
        let name: String
        let body: String
        let html_url: URL
        let assets: [GHAsset]
        let published_at: String

        var tag: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
        var htmlURL: URL { html_url }
        var publishedAt: Date {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: published_at) ?? .distantPast
        }
        var assetURL: URL? {
            assets.first(where: { $0.name.hasSuffix(".dmg") })?.browser_download_url
        }
    }

    private struct GHAsset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    private func fetchLatestRelease() async throws -> GHRelease {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw UpdateError.noReleases
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GHRelease.self, from: data)
    }

    // MARK: - Version helpers

    private func currentAppVersion() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// Compare two semantic version strings (e.g. "1.8" vs "1.9").
    /// Returns true if `versionA` is strictly greater than `versionB`.
    private func compareVersions(_ versionA: String, isGreaterThan versionB: String) -> Bool {
        let a = versionA.split(separator: ".").compactMap { Int($0) }
        let b = versionB.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(a.count, b.count)

        for i in 0..<maxLen {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false // equal
    }
}

enum UpdateError: LocalizedError {
    case noReleases
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noReleases: "暂无发布版本"
        case .networkError(let msg): "网络错误: \(msg)"
        }
    }
}
