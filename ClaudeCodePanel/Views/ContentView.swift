import SwiftUI

struct ContentView: View {
    @State private var selectedPanel: AppPanel = .dashboard

    var body: some View {
        HSplitView {
            SidebarView(selectedPanel: $selectedPanel)
                .frame(minWidth: 180, maxWidth: 180)

            panelView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var panelView: some View {
        switch selectedPanel {
        case .dashboard:
            DashboardView()
        case .apiConfig:
            APIConfigView()
        case .configEditor:
            ConfigEditorView()
        case .mcpManager:
            MCPServerListView()
        case .skillManager:
            SkillsListView()
        }
    }
}
