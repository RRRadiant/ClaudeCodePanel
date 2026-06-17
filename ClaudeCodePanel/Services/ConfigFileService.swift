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

    /// ~/.claude.json — Claude Code global config (contains mcpServers, projects, etc.)
    var claudeGlobalConfigPath: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    var mcpPath: URL {
        claudeDirectory.appendingPathComponent("mcp.json")
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

    func listConfigFiles() -> [ConfigFileInfo] {
        var files: [ConfigFileInfo] = []

        // Include ~/.claude.json (global Claude config with MCP servers)
        let claudeGlobalURL = claudeGlobalConfigPath
        if fileManager.fileExists(atPath: claudeGlobalURL.path) {
            files.append(fileInfo(for: claudeGlobalURL, type: .specificConfig("claude.json")))
        }

        // Scan for all JSON, TOML, YAML files directly in ~/.claude/
        let knownFileNames: Set<String> = ["settings.json", "settings.local.json", "mcp.json", "claude.json"]
        if let topLevelFiles = try? fileManager.contentsOfDirectory(
            at: claudeDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in topLevelFiles {
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                // Only include known config extensions
                guard ext == "json" || ext == "toml" || ext == "yaml" || ext == "yml" else { continue }
                // Exclude hidden files
                if name.hasPrefix(".") { continue }
                let type: ConfigFileInfo.FileType = knownFileNames.contains(name) ? .specificConfig(name) : .config
                files.append(fileInfo(for: url, type: type))
            }
        }

        return files.sorted { $0.name < $1.name }
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

struct ConfigFileInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let type: FileType
    let lastModified: Date
    let sizeBytes: Int64

    enum FileType: Equatable {
        case config
        case specificConfig(String)

        var iconName: String {
            switch self {
            case .config: return "doc.text"
            case .specificConfig(let name):
                switch name {
                case "settings.json", "settings.local.json": return "gearshape"
                case "mcp.json": return "server.rack"
                default: return "doc.text"
                }
            }
        }

        var displayName: String {
            switch self {
            case .config: return "Config"
            case .specificConfig(let name):
                switch name {
                case "claude.json": return "Claude Global"
                case "settings.json": return "Settings"
                case "settings.local.json": return "Local Settings"
                case "mcp.json": return "MCP Config"
                default: return name
                }
            }
        }

        var rawValue: String {
            switch self {
            case .config: return "config"
            case .specificConfig(let name): return name
            }
        }
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
