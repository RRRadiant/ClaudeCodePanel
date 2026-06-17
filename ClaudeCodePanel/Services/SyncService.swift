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

        // Read settings.json (primary) and settings.local.json (overrides)
        let settingsDict = (try? configService.readJSON(at: configService.settingsPath)) ?? [:]
        let localDict = (try? configService.readJSON(at: configService.settingsLocalPath)) ?? [:]

        // --- Extract from settings.json env ---
        if let env = settingsDict["env"] as? [String: String] {
            result = applyEnv(env, to: result)
        }

        // --- Override with settings.local.json env if present ---
        if let localEnv = localDict["env"] as? [String: String] {
            result = applyEnv(localEnv, to: result)
        }

        // --- Extract enabledPlugins → skillIds (strip @source suffix) ---
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

        // --- Extract MCP servers from ~/.claude.json (primary source) ---
        result.mcpServers = extractMCPFromClaudeGlobalJSON()

        // Fallback: settings.json mcpServers key
        if result.mcpServers.isEmpty {
            result.mcpServers = extractMCPServers(from: settingsDict)
        }

        // Fallback: settings.local.json mcpServers key
        if result.mcpServers.isEmpty {
            let localMCPServers = extractMCPServers(from: localDict)
            if !localMCPServers.isEmpty {
                result.mcpServers = localMCPServers
            }
        }

        // Fallback: ~/.claude/.mcp.json file
        if result.mcpServers.isEmpty {
            let dotMcpPath = configService.settingsPath
                .deletingLastPathComponent()
                .appendingPathComponent(".mcp.json")
            if let dotMcpDict = try? configService.readJSON(at: dotMcpPath) {
                result.mcpServers = extractMCPServers(from: dotMcpDict)
            }
        }

        result.didSync = true
        return result
    }

    // MARK: - Helpers

    /// Apply env dictionary to a SyncedConfig, returning the updated config.
    private func applyEnv(_ env: [String: String], to config: SyncedConfig) -> SyncedConfig {
        var c = config

        // ANTHROPIC_BASE_URL → baseURL
        if let baseURL = env["ANTHROPIC_BASE_URL"], !baseURL.isEmpty {
            c.baseURL = baseURL

            // Detect provider from base URL
            let lowercased = baseURL.lowercased()
            if lowercased.contains("deepseek") {
                c.provider = .deepseek
            } else if lowercased.contains("openai") {
                c.provider = .openai
            } else {
                c.provider = .anthropic
            }
        }

        // ANTHROPIC_AUTH_TOKEN → apiKey
        if let authToken = env["ANTHROPIC_AUTH_TOKEN"], !authToken.isEmpty {
            c.apiKey = authToken
        }

        // ANTHROPIC_MODEL → selectedModel
        if let model = env["ANTHROPIC_MODEL"], !model.isEmpty {
            c.selectedModel = model
        }

        // ANTHROPIC_DEFAULT_OPUS_MODEL, _SONNET_MODEL, _HAIKU_MODEL → enabledModels
        let modelKeys = [
            "ANTHROPIC_DEFAULT_OPUS_MODEL",
            "ANTHROPIC_DEFAULT_SONNET_MODEL",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        ]
        var models: [String] = []
        for key in modelKeys {
            if let model = env[key], !model.isEmpty {
                let cleaned = model
                    .replacingOccurrences(of: "[1M]", with: "")
                    .replacingOccurrences(of: "[1m]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    models.append(cleaned)
                }
            }
        }
        if !models.isEmpty {
            c.enabledModels = models
        }

        // Fill tier models from env vars
        for tier in ModelTier.allCases {
            if let model = env[tier.envKey], !model.isEmpty {
                let cleaned = model
                    .replacingOccurrences(of: "[1M]", with: "")
                    .replacingOccurrences(of: "[1m]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    c.tierModels[tier] = cleaned
                }
            }
        }

        return c
    }

    /// Extract MCP servers from ~/.claude.json (Claude Code global config).
    /// Reads top-level mcpServers AND the current project's per-project mcpServers/enabledMcpjsonServers.
    private func extractMCPFromClaudeGlobalJSON() -> [MCPServerConfig] {
        guard let globalDict = try? configService.readJSON(at: configService.claudeGlobalConfigPath) else {
            return []
        }

        var servers: [MCPServerConfig] = []

        // Helper to check if a server is already present (matches by name AND source project)
        func serverExists(name: String, source: String?) -> Bool {
            servers.contains { $0.name == name && $0.sourceProject == source }
        }

        // 1. Global mcpServers (top-level) — source = nil (global)
        if let globalServers = globalDict["mcpServers"] as? [String: [String: Any]] {
            for srv in parseMCPServerEntries(globalServers) {
                srv.sourceProject = nil // global
                servers.append(srv)
            }
        }

        // 2. Collect from ALL project entries
        if let projects = globalDict["projects"] as? [String: [String: Any]] {
            let homePath = NSHomeDirectory()

            // Home project first — handles enabledMcpjsonServers, disabledMcpServers
            if let homeData = projects[homePath] {
                applyProjectMCPServers(homeData, sourcePath: homePath, to: &servers)
            }

            // Other projects — always include their MCP servers (even if name collides)
            for (projectPath, projectData) in projects {
                guard projectPath != homePath else { continue }

                // Per-project mcpServers
                if let projectServers = projectData["mcpServers"] as? [String: [String: Any]] {
                    let mcpList = parseMCPServerEntries(projectServers)
                    for mcp in mcpList {
                        mcp.sourceProject = projectPath
                        // Only skip if exact same (name + source) already exists
                        if !serverExists(name: mcp.name, source: projectPath) {
                            servers.append(mcp)
                        }
                    }
                }

                // Per-project enabledMcpjsonServers
                if let enabledList = projectData["enabledMcpjsonServers"] as? [String] {
                    for entry in enabledList {
                        if !serverExists(name: entry, source: projectPath) {
                            let srvType: MCPServerConfig.MCPServerType = entry.hasPrefix("plugin:") ? .plugin : .builtin
                            servers.append(MCPServerConfig(
                                name: entry,
                                serverType: srvType,
                                command: "",
                                args: [], env: [:],
                                enabled: true,
                                status: .running,
                                sourceProject: projectPath
                            ))
                        }
                    }
                }
            }
        }

        return servers
    }

    /// Apply per-project MCP server data to the servers array.
    private func applyProjectMCPServers(_ projectData: [String: Any], sourcePath: String, to servers: inout [MCPServerConfig]) {
        // Per-project mcpServers
        if let projectServers = projectData["mcpServers"] as? [String: [String: Any]] {
            let projectMCPs = parseMCPServerEntries(projectServers)
            for pmcp in projectMCPs {
                pmcp.sourceProject = sourcePath
                if let idx = servers.firstIndex(where: { $0.name == pmcp.name }) {
                    servers[idx] = pmcp
                } else {
                    servers.append(pmcp)
                }
            }
        }

        // enabledMcpjsonServers
        if let enabledList = projectData["enabledMcpjsonServers"] as? [String] {
            for entry in enabledList {
                if !servers.contains(where: { $0.name == entry }) {
                    let srvType: MCPServerConfig.MCPServerType = entry.hasPrefix("plugin:") ? .plugin : .builtin
                    let server = MCPServerConfig(
                        name: entry,
                        serverType: srvType,
                        command: "",
                        args: [],
                        env: [:],
                        enabled: true,
                        status: .running,
                        sourceProject: sourcePath
                    )
                    servers.append(server)
                }
            }
        }

        // disabledMcpjsonServers + disabledMcpServers (both variants exist)
        let disabledJsonServers = (projectData["disabledMcpjsonServers"] as? [String]) ?? []
        let disabledServers = (projectData["disabledMcpServers"] as? [String]) ?? []
        let allDisabled = Array(Set(disabledJsonServers + disabledServers))
        for name in allDisabled {
            if let idx = servers.firstIndex(where: { $0.name == name && $0.sourceProject == sourcePath }) {
                servers[idx].enabled = false
            } else {
                let srvType: MCPServerConfig.MCPServerType = name.hasPrefix("plugin:") ? .plugin : .builtin
                let server = MCPServerConfig(
                    name: name,
                    serverType: srvType,
                    command: "",
                    args: [],
                    env: [:],
                    enabled: false,
                    status: .stopped,
                    sourceProject: sourcePath
                )
                servers.append(server)
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

    /// Extract MCP server configs from a JSON dictionary.
    private func extractMCPServers(from dict: [String: Any]) -> [MCPServerConfig] {
        if let mcpServers = dict["mcpServers"] as? [String: [String: Any]] {
            return mcpServers.compactMap { (name, config) in
                var mutableConfig = config
                mutableConfig["name"] = name
                return MCPServerConfig.fromJSON(mutableConfig)
            }
        }

        let knownKeys: Set<String> = [
            "env", "model", "enabledPlugins", "hooks", "provider",
            "baseURL", "maxTokens", "timeout", "enabledModels",
        ]
        let possibleServers = dict.filter { !knownKeys.contains($0.key) }
        let configs = possibleServers.compactMap { (key, value) -> MCPServerConfig? in
            guard var serverDict = value as? [String: Any] else { return nil }
            serverDict["name"] = key
            return MCPServerConfig.fromJSON(serverDict)
        }
        if !configs.isEmpty {
            return configs
        }

        return []
    }
}
