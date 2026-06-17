import SwiftUI

struct SidebarItem: View {
    var icon: String
    var title: String
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(title)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) :
                          (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .padding(.horizontal, 8)
    }
}
