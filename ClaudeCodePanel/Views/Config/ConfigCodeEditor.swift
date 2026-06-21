import SwiftUI

struct ConfigCodeEditor: View {
    @Binding var text: String
    var fileType: SyntaxFileType?
    var onChange: ((String) -> Void)?

    var body: some View {
        if let ft = fileType {
            HighlightedTextEditor(text: $text, fileType: ft, onChange: onChange)
        } else {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(16)
                .onChange(of: text) { _, newValue in
                    onChange?(newValue)
                }
        }
    }
}
