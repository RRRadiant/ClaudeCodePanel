import SwiftUI

struct SkillCard: View {
    var skill: SkillItem
    var actionTitle: String
    var actionRole: ButtonRole?
    var onAction: () -> Void

    var body: some View {
        GlassCard(variant: .compact) {
            HStack(spacing: 14) {
                Image(systemName: skill.isLocal ? "folder.fill" : "shippingbox.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(skill.installed ? Color.accentColor : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(skill.displayName)
                            .font(.callout)
                            .fontWeight(.medium)
                        if skill.installed && skill.enabled {
                            Badge(text: "已启用", variant: .success)
                        } else if skill.installed {
                            Badge(text: "已安装", variant: .neutral)
                        }
                    }
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !skill.source.isEmpty && skill.source != "local" && skill.source != "plugin" {
                        Text("来源: \(skill.source)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Button(role: actionRole) {
                    onAction()
                } label: {
                    Text(actionTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }
}
