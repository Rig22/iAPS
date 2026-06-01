import SwiftUI

/// Glass material for cards, badges, sheets, pills.
/// Layers: ultraThin material + theme tint + 0.5px hairline border + soft drop shadow.
/// Optional inner shine via `shine: true`.
struct AuroraGlass: ViewModifier {
    var radius: CGFloat = 26
    var shine: Bool = false

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint)

                    if shine {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: shineColors,
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .blendMode(.plusLighter)
                            .opacity(0.6)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    private var tint: Color {
        scheme == .dark
            ? Color(red: 46 / 255, green: 46 / 255, blue: 52 / 255).opacity(0.55)
            : Color.white.opacity(0.66)
    }

    private var border: Color {
        scheme == .dark
            ? Color.white.opacity(0.13)
            : Color.white.opacity(0.9)
    }

    private var shadowColor: Color {
        scheme == .dark
            ? Color.black.opacity(0.45)
            : Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255).opacity(0.12)
    }

    private var shadowRadius: CGFloat { scheme == .dark ? 30 : 26 }
    private var shadowY: CGFloat { scheme == .dark ? 10 : 8 }

    private var shineColors: [Color] {
        scheme == .dark
            ? [Color.white.opacity(0.12), .clear]
            : [Color.white.opacity(0.9), Color.white.opacity(0.4)]
    }
}

extension View {
    /// Applies the Aurora glass material with the given corner radius.
    /// Set `shine: true` for the inner highlight (used by primary cards).
    func auroraGlass(radius: CGFloat = 26, shine: Bool = false) -> some View {
        modifier(AuroraGlass(radius: radius, shine: shine))
    }
}
