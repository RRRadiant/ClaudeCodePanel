import Foundation

final class SyncService: @unchecked Sendable {
    static let shared = SyncService()

    private let configService = ConfigFileService.shared

    struct SyncedConfig {
        var provider: APIProvider = .anthropic
        var apiKey: String = ""
        var baseURL: String = ""
        var selectedModel: String = ""
        var enabledModels: [String] = []
        var tierModels: [ModelTier: String] = [:]
        var mcpServers: [MCPServerConfig] = []
        var skillIds: [String] = []
        var didSync: Bool = false
    }

    func syncAll() -> SyncedConfig {
        var result = SyncedConfig()

        let settingsDict = (try? configService.readJSON(at: configService.settingsPath)) ?? [:]
        let localDict = (try? configService.readJSON(at: configService.settingsLocalPath)) ?? [:]

        if let env = settingsDict["env"] as? [String: String] {
            result = applyEnv(env, to: result)
        }
        if let localEnv = localDict["env"] as? [String: String] {
            result = applyEnv(localEnv, to: result)
        }

        var mergedForPlugins = settingsDict
        for (key, value) in localDict {
            mergedForPlugins[key] = value
        }
        if let enabledPlugins = mergedForPlugins["enabledPlugins"] as? [String: Any] {
            result.skillIds = enabledPlugins.keys.map { key in
                if let atIndex = key.firstIndex(of: "@") {
                    return String(key[..<atIndex])
                }
                return key
            }
        }

        // MCP servers from ~/.claude.json (the only MCP config Claude Code reads)
        result.mcpServers = extractMCPFromClaudeGlobalJSON()

        result.didSync = true
        return result
    }

    // MARK: - Helpers

    private func applyEnv(_ env: [String: String], to config: SyncedConfig) -> SyncedConfig {
        var c = config

        if let baseURL = env["ANTHROPIC_BASE_URL"], !baseURL.isEmpty {
            c.baseURL = baseURL
            let lowercased = baseURL.lowercased()
            if lowercased.contains("deepseek") { c.provider = .deepseek }
            else if lowercased.contains("openai") { c.provider = .openai }
            else { c.provider = .anthropic }
        }

        if let authToken = env["ANTHROPIC_AUTH_TOKEN"], !authToken.isEmpty { c.apiKey = authToken }
        if let model = env["ANTHROPIC_MODEL"], !model.isEmpty { c.selectedModel = model }

        let modelKeys = ["ANTHROPIC_DEFAULT_OPUS_MODEL", "ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL"]
        var models: [String] = []
        for key in modelKeys {
            if let model = env[key], !model.isEmpty {
                let cleaned = model.replacingOccurrences(of: "[1M]", with: "").replacingOccurrences(of: "[1m]", with: "").trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { models.append(cleaned) }
            }
        }
        if !models.isEmpty { c.enabledModels = models }

        for tier in ModelTier.allCases {
            if let model = env[tier.envKey], !model.isEmpty {
                let cleaned = model.replacingOccurrences(of: "[1M]", with: "").replacingOccurrences(of: "[1m]", with: "").trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { c.tierModels[tier] = cleaned }
            }
        }

        return c
    }

    /// Extract MCP servers from ~/.claude.json — the ONLY MCP config Claude Code reads.
    private func extractMCPFromClaudeGlobalJSON() -> [MCPServerConfig] {
        guard let globalDict = try? configService.readJSON(at: configService.claudeGlobalConfigPath) else {
            return []
        }

        var servers: [MCPServerConfig] = []

        func serverExists(name: String, source: String?) -> Bool {
            servers.contains { $0.name == name && $0.sourceProject == source }
        }

        // 1. Global mcpServers (top-level)
        if let globalServers = globalDict["mcpServers"] as? [String: [String: Any]] {
            for srv in parseMCPServerEntries(globalServers) {
                srv.sourceProject = nil
                servers.append(srv)
            }
        }

        // 2. Per-project entries
        if let projects = globalDict["projects"] as? [String: [String: Any]] {
            let homePath = NSHomeDirectory()

            if let homeData = projects[homePath] {
                applyProjectMCPServers(homeData, sourcePath: homePath, to: &servers)
            }

            for (projectPath, projectData) in projects {
                guard projectPath != homePath else { continue }

                if let projectServers = projectData["mcpServers"] as? [String: [String: Any]] {
                    let mcpList = parseMCPServerEntries(projectServers)
                    for mcp in mcpList {
                        mcp.sourceProject = projectPath
                        if !serverExists(name: mcp.name, source: projectPath) {
                            servers.append(mcp)
                        }
                    }
                }

                if let enabledList = projectData["enabledMcpjsonServers"] as? [String] {
                    for entry in enabledList {
                        if !serverExists(name: entry, source: projectPath) {
                            let srvType: MCPServerConfig.MCPServerType = entry.hasPrefix("plugin:") ? .plugin : .builtin
                            servers.append(MCPServerConfig(name: entry, serverType: srvType, command: "", args: [], env: [:], enabled: true, status: .running, sourceProject: projectPath))
                        }
                    }
                }
            }
        }

        return servers
    }

    private func applyProjectMCPServers(_ projectData: [String: Any], sourcePath: String, to servers: inout [MCPServerConfig]) {
        if let projectServers = projectData["mcpServers"] as? [String: [String: Any]] {
            for pmcp in parseMCPServerEntries(projectServers) {
                pmcp.sourceProject = sourcePath
                if let idx = servers.firstIndex(where: { $0.name == pmcp.name }) {
                    servers[idx] = pmcp
                } else {
                    servers.append(pmcp)
                }
            }
        }

        if let enabledList = projectData["enabledMcpjsonServers"] as? [String] {
            for entry in enabledList {
                if !servers.contains(where: { $0.name == entry }) {
                    let srvType: MCPServerConfig.MCPServerType = entry.hasPrefix("plugin:") ? .plugin : .builtin
                    servers.append(MCPServerConfig(name: entry, serverType: srvType, command: "", args: [], env: [:], enabled: true, status: .running, sourceProject: sourcePath))
                }
            }
        }

        let disabledJson = (projectData["disabledMcpjsonServers"] as? [String]) ?? []
        let disabled = (projectData["disabledMcpServers"] as? [String]) ?? []
        for name in Array(Set(disabledJson + disabled)) {
            if let idx = servers.firstIndex(where: { $0.name == name && $0.sourceProject == sourcePath }) {
                servers[idx].enabled = false
            } else {
                let srvType: MCPServerConfig.MCPServerType = name.hasPrefix("plugin:") ? .plugin : .builtin
                servers.append(MCPServerConfig(name: name, serverType: srvType, command: "", args: [], env: [:], enabled: false, status: .stopped, sourceProject: sourcePath))
            }
        }
    }

    private func parseMCPServerEntries(_ entries: [String: [String: Any]]) -> [MCPServerConfig] {
        return entries.compactMap { (name, config) in
            var mutableConfig = config
            mutableConfig["name"] = name
            return MCPServerConfig.fromJSON(mutableConfig)
        }
    }
}
