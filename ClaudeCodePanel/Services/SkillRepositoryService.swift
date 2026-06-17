import Foundation

final class SkillRepositoryService: @unchecked Sendable {
    static let shared = SkillRepositoryService()
    private let fileManager = FileManager.default

    /// Scan ~/.claude/skills/ directory for locally installed skills
    func scanLocalSkills() -> [SkillItem] {
        let skillsDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills")

        guard fileManager.fileExists(atPath: skillsDir.path),
              let contents = try? fileManager.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        return contents.compactMap { url in
            guard url.hasDirectoryPath else { return nil }
            let name = url.lastPathComponent
            let files = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            let mdFiles = files.filter { $0.pathExtension == "md" }

            return SkillItem(
                name: name,
                displayName: name.replacingOccurrences(of: "-", with: " ").capitalized,
                description: "本地技能 · \(mdFiles.count) 个文件",
                source: "local",
                installed: true,
                enabled: true,
                isLocal: true,
                fileCount: mdFiles.count
            )
        }
    }

    /// Read settings.json enabledPlugins to get plugin-based skill names
    func enabledPluginSkillIds() -> [String] {
        let settingsURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        guard let data = try? Data(contentsOf: settingsURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = dict["enabledPlugins"] as? [String: Any] else {
            return []
        }

        return plugins.keys.map { key in
            if let atIndex = key.firstIndex(of: "@") {
                return String(key[..<atIndex])
            }
            return key
        }
    }
}
