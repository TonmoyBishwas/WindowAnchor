import SwiftUI

/// Liquid Glass container: native `.glassEffect` on macOS 26+, with an
/// ultra-thin material fallback on earlier systems.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}
