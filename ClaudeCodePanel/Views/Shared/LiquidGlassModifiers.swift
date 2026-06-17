import SwiftUI

enum IndicatorStatus {
    case running
    case stopped
    case error
}

enum GlassMaterial {
    case window
    case sidebar
    case content
    case selection
    case overlay

    var regularMaterial: Material {
        switch self {
        case .selection: .regularMaterial
        default: .regular
        }
    }
}

extension View {
    func glassBackgroundEffect(_ material: GlassMaterial) -> some View {
        self.background(material.regularMaterial)
    }
}

struct GlassDivider: View {
    var body: some View {
        Divider().opacity(0.3)
    }
}
