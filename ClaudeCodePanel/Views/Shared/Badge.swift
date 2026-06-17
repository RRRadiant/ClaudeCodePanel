import SwiftUI

enum BadgeVariant {
    case info
    case success
    case neutral

    var backgroundColor: Color {
        switch self {
        case .info: return Color.accentColor.opacity(0.10)
        case .success: return Color(red: 0.204, green: 0.780, blue: 0.349).opacity(0.10)
        case .neutral: return Color.secondary.opacity(0.10)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .info: return Color.accentColor
        case .success: return Color(red: 0.204, green: 0.780, blue: 0.349)
        case .neutral: return Color.secondary
        }
    }
}

struct Badge: View {
    var text: String
    var variant: BadgeVariant = .info

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(variant.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(variant.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
