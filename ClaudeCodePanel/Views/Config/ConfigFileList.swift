import SwiftUI

struct ConfigFileList: View {
    var files: [ConfigFileInfo]
    var selectedFile: ConfigFileInfo?
    var onSelect: (ConfigFileInfo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("配置文件")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            GlassDivider()

            if files.isEmpty {
                EmptyState(icon: "folder.badge.questionmark", message: "未找到配置文件")
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(files) { file in
                            fileRow(file)
                                .onTapGesture { onSelect(file) }
                        }
                    }
                }
            }
        }
        .glassBackgroundEffect(.sidebar)
    }

    private func fileRow(_ file: ConfigFileInfo) -> some View {
        let isSel = selectedFile?.id == file.id
        return HStack(spacing: 10) {
            Image(systemName: file.type.iconName)
                .font(.system(size: 15))
                .foregroundStyle(isSel ? Color.accentColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.type.displayName)
                    .font(.callout)
                    .fontWeight(isSel ? .semibold : .regular)
                    .foregroundStyle(isSel ? Color.accentColor : .primary)
                Text(file.name)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSel ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}
