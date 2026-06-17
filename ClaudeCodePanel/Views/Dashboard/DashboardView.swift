import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text("概览")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView().scaleEffect(0.7)
                    }
                }

                // Status row
                statusBar

                // Model tier cards
                modelTierGrid

                // Stats grid
                statsGrid
            }
            .padding(32)
            .frame(maxWidth: 720)
        }
        .task { await viewModel.loadSummary() }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 0) {
            statusIndicator(
                icon: viewModel.isClaudeInstalled ? "terminal.fill" : "terminal",
                label: "Claude Code",
                value: viewModel.isClaudeInstalled ? viewModel.claudeVersion : "未安装",
                isGood: viewModel.isClaudeInstalled
            )
            divider
            statusIndicator(
                icon: viewModel.apiConnected ? "checkmark.icloud.fill" : "icloud.slash",
                label: "API",
                value: viewModel.apiConnected ? viewModel.apiProvider : "未配置",
                isGood: viewModel.apiConnected
            )
            divider
            statusIndicator(
                icon: viewModel.isConfigured ? "cpu.fill" : "cpu",
                label: "模型",
                value: viewModel.currentModel,
                isGood: viewModel.isConfigured
            )
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusIndicator(icon: String, label: String, value: String, isGood: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(isGood ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 32)
            .padding(.horizontal, 8)
    }

    // MARK: - Model Tiers

    private var modelTierGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("模型层级")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(ModelTier.allCases, id: \.rawValue) { tier in
                    tierCard(tier)
                }
            }
        }
    }

    private func tierCard(_ tier: ModelTier) -> some View {
        let model = viewModel.tierModels[tier] ?? "未设置"
        let isSet = !model.isEmpty && model != "未设置"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: tier.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(tier.color)
                Text(tier.shortName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Text(isSet ? model : "未配置")
                .font(.caption)
                .foregroundStyle(isSet ? .primary : .tertiary)
                .lineLimit(2)

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .background(tier.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tier.color.opacity(0.15), lineWidth: 0.5)
        )
    }


    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("配置摘要")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statTile(icon: "doc.text.fill", label: "配置文件", value: "\(viewModel.configFileCount)", color: .orange)
                statTile(icon: "server.rack", label: "MCP 服务器", value: "\(viewModel.activeMCPServerCount)/\(viewModel.mcpServerCount)", color: .teal)
                statTile(icon: "puzzlepiece.extension.fill", label: "技能", value: "\(viewModel.enabledSkillCount)", color: .pink)
            }
        }
    }

    private func statTile(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
