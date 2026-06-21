import Foundation
import os.lock

/// Checks for new releases by reading a static version.json file (no rate limit),
/// with GitHub API as fallback.
final class UpdateService: @unchecked Sendable {
    static let shared = UpdateService()

    private let repoOwner = "RRRadiant"
    private let repoName = "ClaudeCodePanel"

    /// Static version file — served by GitHub's CDN, never rate-limited.
    private var versionJSONURL: URL {
        URL(string: "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/main/version.json")!
    }

    /// GitHub API fallback (uses token if available).
    private var apiURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()

    // MARK: - Cache (synchronized)

    private let cacheLock = OSAllocatedUnfairLock()
    private var _lastCheckResult: ReleaseInfo?
    private var _lastCheckTime: Date = .distantPast
    private let cacheDuration: TimeInterval = 3600

    private var cachedResult: (time: Date, result: ReleaseInfo?)? {
        get { cacheLock.withLock { _lastCheckTime == .distantPast ? nil : (_lastCheckTime, _lastCheckResult) } }
        set {
            cacheLock.withLock {
                if let v = newValue {
                    _lastCheckTime = v.time
                    _lastCheckResult = v.result
                } else {
                    _lastCheckTime = .distantPast
                    _lastCheckResult = nil
                }
            }
        }
    }

    private var _ghTokenLoaded = false
    private var _ghToken: String?
    private var ghToken: String? {
        if !_ghTokenLoaded { _ghToken = readGHToken(); _ghTokenLoaded = true }
        return _ghToken
    }

    // MARK: - Public

    func checkForUpdate() async throws -> ReleaseInfo? {
        if let cached = cachedResult, Date().timeIntervalSince(cached.time) < cacheDuration {
            return cached.result
        }

        let result = try await fetchAndCompare()
        cachedResult = (Date(), result)
        return result
    }

    private func fetchAndCompare() async throws -> ReleaseInfo? {
        // 1. Try static version.json first — no rate limit, always works
        if let release = try? await fetchFromVersionJSON(),
           let current = currentAppVersion(),
           compareVersions(release.version, isGreaterThan: current) {
            return release
        }

        // 2. Fallback to GitHub API (uses gh token if available)
        if let release = try? await fetchFromAPI() {
            return release
        }

        return nil
    }

    // MARK: - Static version.json (primary, no rate limit)

    private struct StaticVersion: Decodable {
        let version: String
        let name: String?
        let notes: String?
        let dmg_url: String?
        let published_at: String?
    }

    private func fetchFromVersionJSON() async throws -> ReleaseInfo? {
        var request = URLRequest(url: versionJSONURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let info = try JSONDecoder().decode(StaticVersion.self, from: data)

        return ReleaseInfo(
            id: 0,
            version: info.version,
            name: info.name ?? "v\(info.version)",
            body: info.notes ?? "",
            htmlURL: URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/tag/v\(info.version)")!,
            downloadURL: info.dmg_url.flatMap(URL.init),
            publishedAt: info.published_at.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .now,
            isNewer: true
        )
    }

    // MARK: - GitHub API (fallback)

    private struct GHRelease: Decodable {
        let id: Int; let tag_name: String; let name: String; let body: String
        let html_url: URL; let assets: [GHAsset]; let published_at: String
        var tag: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
        var htmlURL: URL { html_url }
        var publishedAt: Date { ISO8601DateFormatter().date(from: published_at) ?? .distantPast }
        var assetURL: URL? { assets.first(where: { $0.name.hasSuffix(".dmg") })?.browser_download_url }
    }
    private struct GHAsset: Decodable { let name: String; let browser_download_url: URL }

    private func fetchFromAPI() async throws -> ReleaseInfo? {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        if let token = ghToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.networkError("Invalid response")
        }

        guard http.statusCode == 200 else {
            if http.statusCode == 404 { throw UpdateError.noReleases }
            throw UpdateError.networkError("HTTP \(http.statusCode)")
        }

        let latest = try JSONDecoder().decode(GHRelease.self, from: data)
        guard let current = currentAppVersion(),
              compareVersions(latest.tag, isGreaterThan: current) else { return nil }

        return ReleaseInfo(
            id: latest.id, version: latest.tag, name: latest.name, body: latest.body,
            htmlURL: latest.htmlURL, downloadURL: latest.assetURL,
            publishedAt: latest.publishedAt, isNewer: true
        )
    }

    // MARK: - gh CLI token

    private func readGHToken() -> String? {
        let path = NSHomeDirectory() + "/.config/gh/hosts.yml"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }

        // Match YAML key: "oauth_token: VALUE" (handles quotes, leading whitespace)
        let pattern = try? NSRegularExpression(
            pattern: #"^\s*oauth_token:\s*"?([^"\n]+)"?\s*$"#,
            options: [.anchorsMatchLines]
        )
        guard let pattern else { return nil }

        let nsContent = content as NSString
        guard let match = pattern.firstMatch(in: content, options: [], range: NSRange(location: 0, length: nsContent.length)),
              match.numberOfRanges > 1 else { return nil }

        let tokenRange = match.range(at: 1)
        return nsContent.substring(with: tokenRange).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Version helpers

    private func currentAppVersion() -> String? {
        Bundle.appVersionOrNil
    }

    /// Compare two semantic version strings (e.g. "1.8" vs "1.9").
    /// Returns true if `versionA` is strictly greater than `versionB`.
    /// Non-numeric segments (e.g. "beta") are compared lexicographically as tie-breakers.
    private func compareVersions(_ a: String, isGreaterThan b: String) -> Bool {
        let aParts = a.split(separator: ".")
        let bParts = b.split(separator: ".")
        let maxLen = max(aParts.count, bParts.count)
        for i in 0..<maxLen {
            let asub = i < aParts.count ? aParts[i] : ""
            let bsub = i < bParts.count ? bParts[i] : ""
            if let an = Int(asub), let bn = Int(bsub) {
                if an > bn { return true }
                if an < bn { return false }
            } else if let an = Int(asub) {
                return true  // numeric > non-numeric
            } else if let bn = Int(bsub) {
                return false // non-numeric < numeric
            } else {
                if asub > bsub { return true }
                if asub < bsub { return false }
            }
        }
        return false // equal
    }
}

enum UpdateError: LocalizedError {
    case notModified, noReleases
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notModified: nil
        case .noReleases: "暂无发布版本"
        case .networkError(let msg): "\(msg)"
        }
    }
}
