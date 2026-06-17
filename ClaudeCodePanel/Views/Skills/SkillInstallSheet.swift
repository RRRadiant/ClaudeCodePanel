import SwiftUI

struct SkillInstallSheet: View {
    var skill: SkillItem
    var onInstall: () -> Void
    var onCancel: () -> Void

    @State private var isInstalling = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("安装技能")
                .font(.title2)
                .fontWeight(.semibold)

            Text(skill.displayName)
                .font(.headline)

            Text(skill.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                GlassButton(title: "取消", variant: .ghost, action: onCancel)
                GlassButton(
                    title: isInstalling ? "安装中..." : "安装",
                    systemImage: "arrow.down.circle",
                    variant: .primary,
                    action: {
                        isInstalling = true
                        onInstall()
                    }
                )
                .disabled(isInstalling)
            }
        }
        .padding(32)
        .frame(width: 380)
    }
}
