import SwiftUI

struct StatusIndicator: View {
    var status: IndicatorStatus
    var label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 12, height: 12)
                )
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .running: Color(red: 0.204, green: 0.780, blue: 0.349)
        case .stopped: .secondary
        case .error: Color(red: 1.0, green: 0.231, blue: 0.188)
        }
    }
}
