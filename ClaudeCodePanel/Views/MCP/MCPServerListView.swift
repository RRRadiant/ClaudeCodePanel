import SwiftUI

struct MCPServerListView: View {
    @State private var viewModel = MCPManagerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MCP 服务器")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("\(viewModel.servers.count) 个服务器 · 从 mcp.json 同步")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        GlassButton(
                            title: viewModel.isSyncing ? "同步中..." : "同步",
                            systemImage: "arrow.triangle.2.circlepath",
                            variant: .secondary,
                            size: .small,
                            action: { viewModel.syncNow() }
                        )
                        .disabled(viewModel.isSyncing)
                        GlassButton(
                            title: "添加",
                            systemImage: "plus",
                            variant: .primary,
                            size: .small,
                            action: { viewModel.isAddingServer = true }
                        )
                    }
                }

                // Success/error message
                if let msg = viewModel.successMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                if let msg = viewModel.errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                if viewModel.isAddingServer {
                    MCPServerEditorView(
                        name: $viewModel.newName,
                        command: $viewModel.newCommand,
                        args: $viewModel.newArgs,
                        env: $viewModel.newEnv,
                        argInput: $viewModel.newArgInput,
                        envKeyInput: $viewModel.newEnvKeyInput,
                        envValueInput: $viewModel.newEnvValueInput,
                        onAddArg: { viewModel.addArg() },
                        onRemoveArg: { viewModel.removeArg(at: $0) },
                        onAddEnv: { viewModel.addEnvPair() },
                        onRemoveEnv: { viewModel.removeEnv(at: $0) },
                        onSave: { Task { await viewModel.saveServer() } },
                        onCancel: { viewModel.resetForm() }
                    )
                }

                if viewModel.servers.isEmpty && !viewModel.isAddingServer {
                    EmptyState(icon: "server.rack", message: "暂无 MCP 服务器\n点击「同步」从 claude.json 加载")
                } else {
                    // Group by source
                    let globalServers = viewModel.servers.filter { $0.sourceProject == nil }
                    let projectServers = viewModel.servers.filter { $0.sourceProject != nil }

                    if !globalServers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("全局").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                            ForEach(globalServers) { server in
                                serverCard(server)
                            }
                        }
                    }

                    if !projectServers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("项目专属").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                            ForEach(projectServers) { server in
                                serverCard(server)
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 720)
        }
        .task { viewModel.loadServers() }
    }

    @ViewBuilder
    private func serverCard(_ server: MCPServerConfig) -> some View {
        let isRenaming = viewModel.renamingServerID == server.id
        MCPServerCard(
            server: server,
            onTest: { Task { await viewModel.testServer(server) } },
            onConfigure: { viewModel.startEditing(server) },
            onDelete: { viewModel.deleteServer(server) },
            onStartRename: { viewModel.startRenaming(server) },
            onCommitRename: { viewModel.commitRename() },
            onCancelRename: { viewModel.cancelRename() },
            renameInput: $viewModel.renameInput,
            isRenaming: isRenaming
        )
    }
}
