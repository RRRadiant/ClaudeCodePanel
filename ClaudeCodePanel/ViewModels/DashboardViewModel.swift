import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    var claudeVersion: String = ""
    var isClaudeInstalled: Bool = false
    var configFileCount: Int = 0
    var mcpServerCount: Int = 0
    var activeMCPServerCount: Int = 0
    var skillCount: Int = 0
    var enabledSkillCount: Int = 0
    var currentModel: String = ""
    var apiProvider: String = ""
    var baseURL: String = ""
    var isLoading: Bool = false
    var apiConnected: Bool = false
    var tierModels: [ModelTier: String] = [:]

    private let configService = ConfigFileService.shared

    var isConfigured: Bool {
        !currentModel.isEmpty && currentModel != "未设置"
    }

    func loadSummary() async {
        isLoading = true

        // Detect Claude CLI (dynamic home dir, not blocking main actor)
        await detectClaudeCLI()

        // Sync config
        let synced = SyncService.shared.syncAll()
        apiProvider = synced.provider.displayName
        baseURL = synced.baseURL
        currentModel = synced.selectedModel.isEmpty ? "未设置" : synced.selectedModel
        apiConnected = !synced.apiKey.isEmpty

        mcpServerCount = synced.mcpServers.count
        activeMCPServerCount = synced.mcpServers.filter(\.enabled).count

        // Tier models from SyncService (already merged settings + local overrides)
        tierModels = synced.tierModels
        // Fallback: use provider defaults for missing tiers
        for tier in ModelTier.allCases where tierModels[tier]?.isEmpty ?? true {
            tierModels[tier] = synced.provider.knownModels[tier]?.first ?? ""
        }

        configFileCount = configService.listConfigFiles().count

        let localSkills = SkillRepositoryService.shared.scanLocalSkills()
        let pluginIds = SkillRepositoryService.shared.enabledPluginSkillIds()
        skillCount = localSkills.count + pluginIds.count
        enabledSkillCount = skillCount

        isLoading = false
    }

    // MARK: - Claude CLI Detection

    /// Detect the Claude Code CLI version without blocking the main actor.
    private func detectClaudeCLI() async {
        let home = NSHomeDirectory()
        let claudePaths = [
            "\(home)/.npm-global/bin/claude",
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "claude",
        ]

        for path in claudePaths {
            let task = Task.detached { () -> (String, Bool) in
                let process = Process()
                if path.contains("/") {
                    process.executableURL = URL(fileURLWithPath: path)
                    process.arguments = ["--version"]
                } else {
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = [path, "--version"]
                }

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let raw = String(data: data, encoding: .utf8) ?? ""
                        let version = raw
                            .trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "Claude Code ", with: "")
                            .replacingOccurrences(of: "Claude Code CLI ", with: "")
                        return (version, true)
                    }
                } catch {}
                return ("", false)
            }

            let found = await task.value
            if found.1 {
                claudeVersion = found.0
                isClaudeInstalled = true
                return
            }
        }
    }
}
