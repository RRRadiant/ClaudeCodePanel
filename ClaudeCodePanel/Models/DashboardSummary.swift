import Foundation

struct DashboardSummary {
    var claudeVersion: String = ""
    var isClaudeInstalled: Bool = false
    var configFileCount: Int = 0
    var mcpServerCount: Int = 0
    var skillCount: Int = 0
    var enabledSkillCount: Int = 0
    var currentModel: String = ""
    var apiProvider: String = ""
    var lastSyncDate: Date?
}
