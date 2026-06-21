import Foundation

// NOTE: @unchecked Sendable is needed because SyncService creates instances
// off the main actor during config parsing. Property writes from testServer()
// callbacks are dispatched to MainActor via the ViewModel.
@Observable
final class MCPServerConfig: Identifiable, Equatable, @unchecked Sendable {
    let id: UUID
    /// Original name from config file (never modified)
    var name: String
    /// Display alias (user-assigned, stored locally — does not modify config)
    var displayAlias: String
    var serverType: MCPServerType
    var command: String
    var url: String
    var args: [String]
    var env: [String: String]
    var enabled: Bool
    var status: MCPServerStatus
    /// Which project this server originates from (nil = global, path = project-specific)
    var sourceProject: String?

    /// What to show in the UI — alias if set, otherwise original name
    var displayName: String {
        displayAlias.isEmpty ? name : displayAlias
    }

    /// Has the user set a custom alias?
    var isRenamed: Bool {
        !displayAlias.isEmpty
    }

    /// Short project name for display
    var sourceLabel: String? {
        guard let proj = sourceProject else { return nil }
        return (proj as NSString).lastPathComponent
    }

    enum MCPServerType: String, Codable {
        case stdio
        case sse
        case builtin
        case plugin

        var label: String {
            switch self {
            case .stdio: "STDIO"
            case .sse: "SSE"
            case .builtin: "内置"
            case .plugin: "插件"
            }
        }
    }

    enum MCPServerStatus: String, Codable {
        case running
        case stopped
        case error
        case starting
        case stopping

        var label: String {
            switch self {
            case .running: "运行中"
            case .starting: "启动中..."
            case .stopping: "停止中..."
            case .stopped: "已停止"
            case .error: "错误"
            }
        }

        var indicatorStatus: IndicatorStatus {
            switch self {
            case .running: .running
            case .starting: .running
            case .stopping, .stopped: .stopped
            case .error: .error
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        displayAlias: String = "",
        serverType: MCPServerType = .stdio,
        command: String = "",
        url: String = "",
        args: [String] = [],
        env: [String: String] = [:],
        enabled: Bool = true,
        status: MCPServerStatus = .stopped,
        sourceProject: String? = nil
    ) {
        self.id = id
        self.name = name
        self.displayAlias = displayAlias
        self.serverType = serverType
        self.command = command
        self.url = url
        self.args = args
        self.env = env
        self.enabled = enabled
        self.status = status
        self.sourceProject = sourceProject
    }

    static func == (lhs: MCPServerConfig, rhs: MCPServerConfig) -> Bool {
        lhs.id == rhs.id
    }

    static func fromJSON(_ dict: [String: Any]) -> MCPServerConfig? {
        guard let name = dict["name"] as? String else { return nil }

        let typeStr = dict["type"] as? String ?? "stdio"

        switch typeStr {
        case "sse":
            guard let url = dict["url"] as? String else { return nil }
            return MCPServerConfig(
                name: name,
                serverType: .sse,
                command: "sse",
                url: url,
                enabled: dict["enabled"] as? Bool ?? true
            )
        default:
            guard let command = dict["command"] as? String else { return nil }
            return MCPServerConfig(
                name: name,
                serverType: .stdio,
                command: command,
                args: dict["args"] as? [String] ?? [],
                env: dict["env"] as? [String: String] ?? [:],
                enabled: dict["enabled"] as? Bool ?? true
            )
        }
    }

    /// Value dict for ~/.claude.json mcpServers entries.
    /// The server name is the key, so this dict does NOT include "name".
    func toClaudeJSONEntry() -> [String: Any] {
        switch serverType {
        case .sse:
            return ["type": "sse", "url": url]
        default:
            var dict: [String: Any] = ["type": "stdio", "command": command]
            if !args.isEmpty { dict["args"] = args }
            if !env.isEmpty { dict["env"] = env }
            return dict
        }
    }
}
