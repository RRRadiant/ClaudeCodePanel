import SwiftUI

struct GlassCard<Content: View>: View {
    var title: String?
    var variant: CardVariant
    @ViewBuilder let content: () -> Content

    enum CardVariant {
        case standard
        case compact
    }

    init(title: String? = nil, variant: CardVariant = .standard, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.variant = variant
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: variant == .compact ? 8 : 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            content()
        }
        .padding(variant == .compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}
