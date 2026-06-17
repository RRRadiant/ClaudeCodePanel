import SwiftUI

enum AppPanel: String, CaseIterable {
    case dashboard
    case apiConfig
    case configEditor
    case mcpManager
    case skillManager

    var title: String {
        switch self {
        case .dashboard: "概览"
        case .apiConfig: "API 配置"
        case .configEditor: "配置文件"
        case .mcpManager: "MCP 服务器"
        case .skillManager: "技能"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.fill"
        case .apiConfig: "key.fill"
        case .configEditor: "doc.text.fill"
        case .mcpManager: "server.rack"
        case .skillManager: "puzzlepiece.extension.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedPanel: AppPanel

    var body: some View {
        VStack(spacing: 2) {
            Spacer().frame(height: 12)

            ForEach(AppPanel.allCases, id: \.rawValue) { panel in
                SidebarItem(
                    icon: panel.icon,
                    title: panel.title,
                    isSelected: selectedPanel == panel,
                    action: { selectedPanel = panel }
                )
            }

            Spacer()
        }
        .frame(width: 180)
        .glassBackgroundEffect(.sidebar)
    }
}
