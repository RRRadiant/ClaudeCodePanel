import SwiftUI

struct MCPServerEditorView: View {
    @Binding var name: String
    @Binding var command: String
    @Binding var args: [String]
    @Binding var env: [(String, String)]
    var argInput: Binding<String>
    var envKeyInput: Binding<String>
    var envValueInput: Binding<String>
    var onAddArg: () -> Void
    var onRemoveArg: (Int) -> Void
    var onAddEnv: () -> Void
    var onRemoveEnv: (Int) -> Void
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        GlassCard(title: "添加 MCP 服务器") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("名称").font(.callout)
                    GlassTextField(placeholder: "服务器名称", text: $name, variant: .regular)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("命令").font(.callout)
                    GlassTextField(placeholder: "npx @anthropic/mcp-server", text: $command, variant: .regular)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("参数").font(.callout)
                    HStack {
                        GlassTextField(placeholder: "添加参数", text: argInput, variant: .compact)
                        GlassButton(title: "添加", variant: .secondary, size: .small, action: onAddArg)
                    }
                    ForEach(Array(args.enumerated()), id: \.offset) { idx, arg in
                        HStack {
                            Text(arg)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button { onRemoveArg(idx) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("环境变量").font(.callout)
                    HStack {
                        GlassTextField(placeholder: "键", text: envKeyInput, variant: .compact)
                        GlassTextField(placeholder: "值", text: envValueInput, variant: .compact)
                        GlassButton(title: "添加", variant: .secondary, size: .small, action: onAddEnv)
                    }
                    ForEach(Array(env.enumerated()), id: \.offset) { idx, pair in
                        HStack {
                            Text("\(pair.0)=\(pair.1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button { onRemoveEnv(idx) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 12) {
                    GlassButton(title: "取消", variant: .ghost, action: onCancel)
                    Spacer()
                    GlassButton(title: "保存服务器", variant: .primary, action: onSave)
                }
            }
        }
    }
}
