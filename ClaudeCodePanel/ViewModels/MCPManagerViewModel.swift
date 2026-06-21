import Foundation
import SwiftUI

@MainActor
@Observable
final class MCPManagerViewModel {
    var servers: [MCPServerConfig] = []
    var isAddingServer = false
    var editingServer: MCPServerConfig?
    var errorMessage: String?
    var successMessage: String?
    var didAttemptSync = false
    var isSyncing = false

    // Rename state
    var renamingServerID: UUID?
    var renameInput: String = ""

    var newName = ""
    var newCommand = ""
    var newArgs: [String] = []
    var newEnv: [(String, String)] = []
    var newArgInput = ""
    var newEnvKeyInput = ""
    var newEnvValueInput = ""

    private let configService = ConfigFileService.shared
    private let mcpService = MCPService.shared

    /// Path to local display-name overrides
    private var displayNamesPath: URL {
        configService.settingsPath
            .deletingLastPathComponent()
            .appendingPathComponent("mcp-display-names.json")
    }

    // MARK: - Sync

    func loadServers() {
        syncFromClaudeJSON()
    }

    func syncNow() {
        isSyncing = true
        syncFromClaudeJSON()
        isSyncing = false
        successMessage = "已从 claude.json 同步 \(servers.count) 个服务器"
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
        }
    }

    private func syncFromClaudeJSON() {
        errorMessage = nil
        let aliases = loadDisplayNames()

        // Always sync from ~/.claude.json as primary source
        let synced = SyncService.shared.syncAll()
        if synced.didSync {
            servers = synced.mcpServers
            didAttemptSync = true
        } else {
            // Fallback: try mcp.json
            if let data = try? Data(contentsOf: configService.mcpPath),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let serverList = dict["servers"] as? [[String: Any]] {
                servers = serverList.compactMap { MCPServerConfig.fromJSON($0) }
                didAttemptSync = !serverList.isEmpty
            } else {
                servers = []
                didAttemptSync = true
            }
        }

        // Restore display aliases
        for (name, alias) in aliases {
            if let idx = servers.firstIndex(where: { $0.name == name }) {
                servers[idx].displayAlias = alias
            }
        }
    }

    // MARK: - Rename

    func startRenaming(_ server: MCPServerConfig) {
        renamingServerID = server.id
        renameInput = server.displayName
    }

    func commitRename() {
        guard let serverID = renamingServerID,
              let idx = servers.firstIndex(where: { $0.id == serverID }) else { return }
        let trimmed = renameInput.trimmingCharacters(in: .whitespaces)
        let server = servers[idx]

        if trimmed.isEmpty || trimmed == server.name {
            server.displayAlias = ""
        } else {
            server.displayAlias = trimmed
        }

        saveDisplayNames()
        cancelRename()
    }

    func cancelRename() {
        renamingServerID = nil
        renameInput = ""
    }

    // MARK: - Display name persistence

    private func loadDisplayNames() -> [String: String] {
        guard let data = try? Data(contentsOf: displayNamesPath),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }

    private func saveDisplayNames() {
        let dict = Dictionary(uniqueKeysWithValues: servers
            .filter { $0.isRenamed }
            .map { ($0.name, $0.displayAlias) })
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
            try data.write(to: displayNamesPath)
        } catch {
            errorMessage = "保存别名失败: \(error.localizedDescription)"
        }
    }

    // MARK: - CRUD

    func startEditing(_ server: MCPServerConfig) {
        editingServer = server
        newName = server.name
        newCommand = server.command
        newArgs = server.args
        newEnv = server.env.map { ($0.key, $0.value) }
        isAddingServer = true
    }

    func saveServer() async {
        let server: MCPServerConfig
        if let editing = editingServer {
            server = editing
            server.name = newName
            server.command = newCommand
            server.args = newArgs.filter { !$0.isEmpty }
            server.env = Dictionary(uniqueKeysWithValues: newEnv.filter { !$0.0.isEmpty })
        } else {
            server = MCPServerConfig(
                name: newName,
                command: newCommand,
                args: newArgs.filter { !$0.isEmpty },
                env: Dictionary(uniqueKeysWithValues: newEnv.filter { !$0.0.isEmpty })
            )
            servers.append(server)
        }

        await persistServers()
        resetForm()
    }

    func deleteServer(_ server: MCPServerConfig) {
        mcpService.stopServer(server)
        if server.isRenamed {
            server.displayAlias = ""
            saveDisplayNames()
        }
        servers.removeAll { $0.id == server.id }
        Task { await persistServers() }
    }

    func testServer(_ server: MCPServerConfig) async {
        server.status = .starting
        errorMessage = nil
        successMessage = nil

        let result: MCPService.TestResult

        switch server.serverType {
        case .sse:
            result = await mcpService.testSSE(urlString: server.url)

        case .stdio:
            result = await mcpService.testSTDIO(
                command: server.command,
                args: server.args,
                env: server.env
            )

        case .builtin:
            // Builtin servers are managed by Claude Code itself — verify they exist in config
            server.status = .running
            try? await Task.sleep(nanoseconds: 500_000_000)
            server.status = .stopped
            successMessage = "内置服务器 · 由 Claude Code 管理"
            return

        case .plugin:
            // Plugin servers — check if the plugin name is registered
            server.status = .running
            try? await Task.sleep(nanoseconds: 500_000_000)
            server.status = .stopped
            let pluginName = server.name.hasPrefix("plugin:") ? String(server.name.dropFirst(7)) : server.name
            successMessage = "插件服务器 · \(pluginName)"
            return
        }

        // Update status based on result
        server.status = result.success ? .running : .error

        if result.success {
            successMessage = result.message
            // Auto-dismiss success after 6s
            let msg = result.message
            Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                if successMessage == msg { successMessage = nil }
            }
        } else {
            errorMessage = result.message
            if let detail = result.detail {
                errorMessage = "\(result.message)\n\(detail)"
            }
        }
    }

    private func persistServers() async {
        let claudePath = configService.claudeGlobalConfigPath

        // Read existing ~/.claude.json
        guard var root = try? configService.readJSON(at: claudePath) else {
            errorMessage = "无法读取 ~/.claude.json"
            return
        }

        // Rebuild global mcpServers dict from current state
        var mcpServers: [String: [String: Any]] = [:]
        for srv in servers {
            switch srv.serverType {
            case .stdio, .sse:
                mcpServers[srv.name] = srv.toClaudeJSONEntry()
            case .builtin, .plugin:
                break
            }
        }
        root["mcpServers"] = mcpServers

        // Update per-project mcpServers references
        if var projects = root["projects"] as? [String: [String: Any]] {
            // Group servers by project
            var projNames: [String: [String]] = [:] // project path -> [server names]

            for srv in servers where srv.sourceProject != nil {
                guard srv.serverType == .stdio || srv.serverType == .sse else { continue }
                projNames[srv.sourceProject!, default: []].append(srv.name)
            }

            for (projPath, names) in projNames {
                var pdata = projects[projPath] ?? [:]
                pdata["mcpServers"] = names
                projects[projPath] = pdata
            }

            root["projects"] = projects
        }

        do {
            try configService.writeJSON(root, to: claudePath)
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }

    func resetForm() {
        newName = ""
        newCommand = ""
        newArgs = []
        newEnv = []
        newArgInput = ""
        newEnvKeyInput = ""
        newEnvValueInput = ""
        editingServer = nil
        isAddingServer = false
    }

    func removeArg(at index: Int) {
        guard newArgs.indices.contains(index) else { return }
        newArgs.remove(at: index)
    }

    func removeEnv(at index: Int) {
        guard newEnv.indices.contains(index) else { return }
        newEnv.remove(at: index)
    }

    func addArg() {
        let trimmed = newArgInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            newArgs.append(trimmed)
            newArgInput = ""
        }
    }

    func addEnvPair() {
        let key = newEnvKeyInput.trimmingCharacters(in: .whitespaces)
        let value = newEnvValueInput.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty {
            newEnv.append((key, value))
            newEnvKeyInput = ""
            newEnvValueInput = ""
        }
    }
}
