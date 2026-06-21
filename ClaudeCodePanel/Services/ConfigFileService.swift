import Foundation

final class ConfigFileService: @unchecked Sendable {
    static let shared = ConfigFileService()
    private let fileManager = FileManager.default

    private var claudeDirectory: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    var settingsPath: URL {
        claudeDirectory.appendingPathComponent("settings.json")
    }

    var settingsLocalPath: URL {
        claudeDirectory.appendingPathComponent("settings.local.json")
    }

    /// ~/.claude.json — Claude Code global config (mcpServers, projects, stats)
    var claudeGlobalConfigPath: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    var skillsDirectory: URL {
        claudeDirectory.appendingPathComponent("skills")
    }

    var agentsDirectory: URL {
        claudeDirectory.appendingPathComponent("agents")
    }

    var commandsDirectory: URL {
        claudeDirectory.appendingPathComponent("commands")
    }

    // MARK: - File listing

    /// Claude Code's 3 core config files in priority order.
    private let coreFiles: [(name: String, desc: String, icon: String)] = [
        ("claude.json",       "主配置 — MCP 服务器、项目绑定、使用统计", "server.rack"),
        ("settings.json",     "全局设置 — 模型、环境变量、插件、主题", "gearshape"),
        ("settings.local.json", "本地设置 — 权限、项目级覆盖",        "lock.shield"),
    ]

    func listConfigFiles() -> [ConfigFileInfo] {
        var files: [ConfigFileInfo] = []

        // Core files first (always shown, with descriptions)
        for core in coreFiles {
            let url = core.name == "claude.json"
                ? claudeGlobalConfigPath
                : claudeDirectory.appendingPathComponent(core.name)
            if fileManager.fileExists(atPath: url.path) {
                files.append(fileInfo(for: url, type: .coreConfig(name: core.name, desc: core.desc, icon: core.icon)))
            }
        }

        // Any other JSON/TOML/YAML files in ~/.claude/
        let coreNames = Set(coreFiles.map(\.name))
        if let entries = try? fileManager.contentsOfDirectory(
            at: claudeDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in entries {
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                guard ext == "json" || ext == "toml" || ext == "yaml" || ext == "yml" else { continue }
                if name.hasPrefix(".") || coreNames.contains(name) { continue }
                files.append(fileInfo(for: url, type: .otherConfig(desc: "其他配置文件")))
            }
        }

        return files
    }

    private func fileInfo(for url: URL, type: ConfigFileInfo.FileType) -> ConfigFileInfo {
        let attrs = try? fileManager.attributesOfItem(atPath: url.path)
        let mtime = (attrs?[.modificationDate] as? Date) ?? .distantPast
        let size = (attrs?[.size] as? Int64) ?? 0
        return ConfigFileInfo(
            name: url.lastPathComponent,
            path: url.path,
            type: type,
            lastModified: mtime,
            sizeBytes: size
        )
    }

    // MARK: - I/O

    func readFile(at path: String) throws -> String {
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    func readJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw ConfigFileError.invalidJSON("Expected JSON object at \(url.path)")
        }
        return dict
    }

    func writeJSON(_ dict: [String: Any], to url: URL, expectedMtime: Date? = nil) throws {
        if let expected = expectedMtime, fileManager.fileExists(atPath: url.path) {
            let attrs = try fileManager.attributesOfItem(atPath: url.path)
            let currentMtime = (attrs[.modificationDate] as? Date) ?? .distantPast
            if abs(currentMtime.timeIntervalSince(expected)) > 0.1 {
                throw ConfigFileError.conflictDetected(path: url.path)
            }
        }

        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        let tempURL = url.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.moveItem(at: tempURL, to: url)
    }

    func ensureDirectoryExists(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Config File Info

struct ConfigFileInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let type: FileType
    let lastModified: Date
    let sizeBytes: Int64

    var description: String {
        switch type {
        case .coreConfig(_, let desc, _): return desc
        case .otherConfig(let desc): return desc
        }
    }

    var iconName: String {
        switch type {
        case .coreConfig(_, _, let icon): return icon
        case .otherConfig: return "doc.text"
        }
    }

    enum FileType: Equatable {
        case coreConfig(name: String, desc: String, icon: String)
        case otherConfig(desc: String)
    }
}

enum ConfigFileError: LocalizedError {
    case fileNotFound(path: String)
    case invalidJSON(String)
    case conflictDetected(path: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let p): "File not found: \(p)"
        case .invalidJSON(let m): "Invalid JSON: \(m)"
        case .conflictDetected(let p): "File was modified externally: \(p)"
        }
    }
}
