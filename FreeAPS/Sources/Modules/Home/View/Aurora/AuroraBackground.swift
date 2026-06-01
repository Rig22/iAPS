import SwiftUI

/// Aurora background: solid/gradient base + three large blurred radial glows.
/// Drop this as the back layer of any Aurora screen.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(AuroraPalette.screenBackground(scheme))

            // Green glow — top-left
            glow(color: AuroraPalette.Glow.green(scheme), size: 320)
                .offset(x: -120, y: -340)

            // Blue glow — top-right
            glow(color: AuroraPalette.Glow.blue(scheme), size: 300)
                .offset(x: 130, y: -360)

            // Violet glow — mid-left
            glow(color: AuroraPalette.Glow.violet(scheme), size: 250)
                .offset(x: -130, y: -40)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func glow(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: color, location: 0),
                        .init(color: color.opacity(0), location: 0.65)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 20)
    }
}
