import SwiftUI

struct AsyncButton: View {
    var title: String
    var systemImage: String?
    var role: ButtonRole?
    var action: () async -> Void

    @State private var isRunning = false

    var body: some View {
        Button(role: role) {
            isRunning = true
            Task {
                await action()
                isRunning = false
            }
        } label: {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .disabled(isRunning)
    }
}
