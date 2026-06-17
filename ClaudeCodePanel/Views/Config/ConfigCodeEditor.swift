import SwiftUI

struct ConfigCodeEditor: View {
    @Binding var text: String
    var onChange: ((String) -> Void)?

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(16)
            .onChange(of: text) { _, newValue in
                onChange?(newValue)
            }
    }
}
