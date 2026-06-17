import SwiftUI

struct GlassButton: View {
    var title: String
    var systemImage: String?
    var variant: ButtonVariant
    var size: ButtonSize
    var action: () -> Void

    enum ButtonVariant {
        case primary
        case secondary
        case ghost
    }

    enum ButtonSize {
        case regular
        case small
    }

    init(
        title: String,
        systemImage: String? = nil,
        variant: ButtonVariant = .primary,
        size: ButtonSize = .regular,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.size = size
        self.action = action
    }

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: size == .small ? 11 : 12))
                }
                Text(title)
                    .font(size == .small ? .caption : .callout)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, size == .small ? 10 : 16)
            .padding(.vertical, size == .small ? 5 : 8)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            isHovered ? Color.accentColor.opacity(0.85) : Color.accentColor
        case .secondary:
            isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.07)
        case .ghost:
            isHovered ? Color.white.opacity(0.07) : .clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: .white
        case .secondary, .ghost: .primary
        }
    }
}
