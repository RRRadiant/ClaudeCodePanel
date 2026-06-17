import SwiftUI

struct MCPServerCard: View {
    var server: MCPServerConfig
    var onTest: () -> Void
    var onConfigure: () -> Void
    var onDelete: () -> Void
    var onStartRename: () -> Void
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    var renameInput: Binding<String>
    var isRenaming: Bool

    @State private var isExpanded = false
    @State private var isHovered = false

    private func serverTypeBadgeVariant(_ type: MCPServerConfig.MCPServerType) -> BadgeVariant {
        switch type {
        case .stdio: return .info
        case .sse: return .neutral
        case .builtin: return .success
        case .plugin: return .info
        }
    }

    var body: some View {
        GlassCard(variant: .compact) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)

                    if isRenaming {
                        HStack(spacing: 6) {
                            TextField("别名", text: renameInput)
                                .textFieldStyle(.plain)
                                .font(.headline)
                                .frame(width: 160)
                                .onSubmit { onCommitRename() }
                            Button(action: onCommitRename) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                            Button(action: onCancelRename) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(server.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            if server.isRenamed {
                                Text(server.name)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Always-visible rename button on hover
                        if isHovered {
                            Button(action: onStartRename) {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("重命名")
                        }
                    }

                    Spacer()

                    StatusIndicator(
                        status: server.status.indicatorStatus,
                        label: server.status.label
                    )

                    if isHovered && !isRenaming {
                        Menu {
                            Button(action: onStartRename) {
                                Label("重命名", systemImage: "pencil")
                            }
                            Button(action: onTest) {
                                Label("测试连接", systemImage: "arrow.triangle.swap")
                            }
                            Button(action: onConfigure) {
                                Label("配置…", systemImage: "gearshape")
                            }
                            Divider()
                            Button(role: .destructive, action: onDelete) {
                                Label("删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isRenaming {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        GlassDivider()

                        HStack(spacing: 6) {
                            Badge(text: server.serverType.label, variant: serverTypeBadgeVariant(server.serverType))
                            if let src = server.sourceLabel {
                                Badge(text: src, variant: .info)
                            }
                            if server.isRenamed {
                                Badge(text: "已重命名", variant: .neutral)
                            }
                        }

                        switch server.serverType {
                        case .sse:
                            Text("URL: \(server.url)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        case .builtin, .plugin:
                            Text("类型: \(server.serverType.label)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        case .stdio:
                            Text("命令: \(server.command)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if !server.args.isEmpty {
                                Text("参数: \(server.args.joined(separator: " "))")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                            }
                        }

                        if !server.env.isEmpty {
                            Text("环境变量: \(server.env.count) 个")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
