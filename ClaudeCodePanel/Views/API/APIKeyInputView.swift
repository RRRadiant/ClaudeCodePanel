import SwiftUI

struct APIKeyInputView: View {
    @Binding var apiKey: String
    var placeholder: String = "sk-..."

    var body: some View {
        GlassTextField(
            placeholder: placeholder,
            text: $apiKey,
            variant: .regular,
            isSecure: true
        )
    }
}
