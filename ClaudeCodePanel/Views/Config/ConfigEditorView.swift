import SwiftUI

struct ConfigEditorView: View {
    @State private var viewModel = ConfigEditorViewModel()

    var body: some View {
        HSplitView {
            // File list sidebar
            ConfigFileList(
                files: viewModel.files,
                selectedFile: viewModel.selectedFile,
                onSelect: { viewModel.selectFile($0) }
            )
            .frame(minWidth: 200, maxWidth: 260)

            // Editor
            VStack(spacing: 0) {
                if let file = viewModel.selectedFile {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.headline)
                            Text(file.description)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()

                        if viewModel.isModified {
                            Text("已修改")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        GlassButton(title: "还原", systemImage: "arrow.uturn.backward", variant: .ghost, size: .small, action: { viewModel.reloadFile() })
                        GlassButton(title: "保存", systemImage: "square.and.arrow.down", variant: .primary, size: .small, action: { viewModel.saveFile() })
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    GlassDivider()

                    // Code editor
                    ConfigCodeEditor(text: $viewModel.fileContent) { _ in
                        viewModel.isModified = true
                    }
                } else {
                    EmptyState(icon: "doc.text.magnifyingglass", message: "选择一个配置文件")
                }
            }
        }
        .task { viewModel.loadFiles() }
    }
}
