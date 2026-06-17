import SwiftUI

struct APIConfigView: View {
    @State private var viewModel = APIConfigViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API 配置")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("配置模型层级和连接参数")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    connectionBadge
                }

                // Provider + Base URL card
                GlassCard(title: "提供商") {
                    VStack(spacing: 12) {
                        Picker("提供商", selection: $viewModel.provider) {
                            ForEach(APIProvider.allCases, id: \.rawValue) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.provider) { _, new in
                            viewModel.baseURL = new.defaultBaseURL
                        }

                        HStack(spacing: 12) {
                            Text("Base URL").font(.callout).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                            GlassTextField(placeholder: "https://api.anthropic.com", text: $viewModel.baseURL, variant: .regular)
                        }
                    }
                }

                // API Key
                GlassCard(title: "认证") {
                    HStack(spacing: 12) {
                        Text("API Key").font(.callout).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                        GlassTextField(placeholder: "sk-...", text: $viewModel.apiKey, variant: .regular, isSecure: true)
                    }
                }

                // Model Tiers — the key new feature
                GlassCard(title: "模型层级") {
                    VStack(spacing: 16) {
                        ForEach(ModelTier.allCases, id: \.rawValue) { tier in
                            modelTierRow(tier)
                        }
                    }
                }

                // Active model
                GlassCard(title: "当前模型") {
                    HStack(spacing: 12) {
                        GlassTextField(placeholder: "选择或输入模型 ID", text: $viewModel.selectedModel, variant: .regular)

                        Menu {
                            ForEach(viewModel.enabledModels, id: \.self) { model in
                                Button(model) { viewModel.selectedModel = model }
                            }
                            if !viewModel.detectedModels.isEmpty {
                                Divider()
                                Text("检测到的模型").font(.caption)
                                ForEach(viewModel.detectedModels, id: \.self) { model in
                                    Button(model) { viewModel.selectedModel = model }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle")
                                .font(.system(size: 16))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .disabled(viewModel.enabledModels.isEmpty && viewModel.detectedModels.isEmpty)
                    }
                }

                // Detection & Connection test
                GlassCard(title: "模型检测") {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            GlassButton(
                                title: viewModel.isDetectingModels ? "检测中..." : "拉取可用模型",
                                systemImage: "antenna.radiowaves.left.and.right",
                                variant: .secondary,
                                size: .small,
                                action: { Task { await viewModel.detectModels() } }
                            )
                            .disabled(viewModel.isDetectingModels)

                            GlassButton(
                                title: viewModel.isTestingConnection ? "测试中..." : "测试连接",
                                systemImage: "arrow.triangle.swap",
                                variant: .secondary,
                                size: .small,
                                action: { Task { await viewModel.testConnection() } }
                            )
                            .disabled(viewModel.isTestingConnection)

                            if viewModel.detectedModels.isEmpty {
                                GlassButton(
                                    title: "自动匹配",
                                    systemImage: "wand.and.stars",
                                    variant: .ghost,
                                    size: .small,
                                    action: { viewModel.autoAssignModels() }
                                )
                            } else {
                                GlassButton(
                                    title: "导入 (发现 \(viewModel.detectedModels.count) 个)",
                                    systemImage: "arrow.down.circle",
                                    variant: .secondary,
                                    size: .small,
                                    action: { viewModel.importDetectedModel() }
                                )
                            }
                        }

                        if !viewModel.detectedModels.isEmpty {
                            Text("检测到: \(viewModel.detectedModels.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Messages + Save
                HStack(spacing: 12) {
                    if let error = viewModel.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    if let success = viewModel.successMessage {
                        Text(success).font(.caption).foregroundStyle(.green)
                    }
                    Spacer()
                    GlassButton(
                        title: viewModel.isSaving ? "保存中..." : "保存配置",
                        systemImage: "square.and.arrow.down",
                        variant: .primary,
                        action: { viewModel.saveConfig() }
                    )
                    .disabled(viewModel.isSaving)
                }
            }
            .padding(32)
            .frame(maxWidth: 720)
        }
        .task { viewModel.loadConfig() }
    }

    // MARK: - Model Tier Row

    private func modelTierRow(_ tier: ModelTier) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tier.icon)
                .font(.system(size: 16))
                .foregroundStyle(tier.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier.displayName)
                    .font(.callout)
                    .fontWeight(.medium)
                Text("env: \(tier.envKey)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 130, alignment: .leading)

            GlassTextField(
                placeholder: defaultModelPlaceholder(tier),
                text: Binding(
                    get: { viewModel.tierModels[tier] ?? "" },
                    set: { viewModel.tierModels[tier] = $0 }
                ),
                variant: .regular
            )

            // Quick-pick menu
            if let knownModels = viewModel.provider.knownModels[tier], !knownModels.isEmpty {
                Menu {
                    ForEach(knownModels, id: \.self) { model in
                        Button(model) {
                            viewModel.tierModels[tier] = model
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }


    private func defaultModelPlaceholder(_ tier: ModelTier) -> String {
        viewModel.provider.knownModels[tier]?.first ?? "模型 ID"
    }

    // MARK: - Connection Badge

    @ViewBuilder
    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            Text(connectionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(connectionColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var connectionColor: Color {
        switch viewModel.connectionStatus {
        case .connected: .green
        case .testing: .yellow
        case .failed: .red
        case .unknown: .secondary
        }
    }

    private var connectionLabel: String {
        switch viewModel.connectionStatus {
        case .connected: "已连接"
        case .testing: "测试中..."
        case .failed(let msg): "失败: \(msg)"
        case .unknown: "未测试"
        }
    }
}
