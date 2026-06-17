import Foundation
import Observation

@MainActor
@Observable
final class ConfigEditorViewModel {
    var files: [ConfigFileInfo] = []
    var selectedFile: ConfigFileInfo?
    var fileContent: String = ""
    var isModified: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    private let configService = ConfigFileService.shared

    func loadFiles() {
        files = configService.listConfigFiles()
        if let first = files.first, selectedFile == nil {
            selectFile(first)
        }
    }

    func selectFile(_ file: ConfigFileInfo) {
        selectedFile = file
        errorMessage = nil
        do {
            fileContent = try configService.readFile(at: file.path)
            isModified = false
        } catch {
            errorMessage = "读取文件失败: \(error.localizedDescription)"
            fileContent = ""
        }
    }

    func saveFile() {
        guard let file = selectedFile else { return }
        do {
            let url = URL(fileURLWithPath: file.path)
            try fileContent.write(to: url, atomically: true, encoding: .utf8)
            isModified = false
            loadFiles()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }

    func reloadFile() {
        guard let file = selectedFile else { return }
        selectFile(file)
    }
}
