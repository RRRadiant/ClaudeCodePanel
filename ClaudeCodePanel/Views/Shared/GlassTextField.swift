import SwiftUI

struct GlassTextField: View {
    var placeholder: String
    @Binding var text: String
    var variant: FieldVariant
    var isSecure: Bool = false

    enum FieldVariant {
        case regular
        case compact
    }

    var body: some View {
        let field = Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        return field
            .textFieldStyle(.plain)
            .padding(variant == .compact ? 8 : 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}
