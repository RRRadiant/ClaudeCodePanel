import SwiftUI

struct ConfigDiffView: View {
    var oldText: String
    var newText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("变更对比")
                .font(.headline)

            HStack(spacing: 0) {
                VStack(alignment: .leading) {
                    Text("之前")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(oldText)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)

                VStack(alignment: .leading) {
                    Text("之后")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(newText)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
