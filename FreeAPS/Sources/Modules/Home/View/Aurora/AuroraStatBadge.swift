import SwiftUI

/// A single glass stat badge.
/// Layout: icon + value + unit on row 1, label below, optional sub-line.
/// If `onTap` is set the whole badge becomes a button (light haptic).
struct AuroraStatBadge: View {
    let icon: String // SF Symbol
    let iconColor: Color
    let value: String
    let unit: String
    let label: String
    var sub: String? = nil
    /// Optional corner pill, e.g. "U200" for non-standard insulin.
    var badge: String? = nil
    /// Fill color for the corner pill — bound to glucose status so it blends
    /// with green/amber instead of clashing red.
    var badgeColor: Color = .red
    /// Show a warning shield in the top-*leading* corner (so it never collides
    /// with the trailing U200 pill). Used for imminent pump/pod expiry.
    var warning: Bool = false
    /// When true the warning shield pulses (e.g. < 2 h of pod life remaining).
    var warningPulsing: Bool = false
    /// Tint for the warning shield — bound to glucose status, same as `badgeColor`.
    var warningColor: Color = .red
    var onTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let onTap = onTap {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTap()
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textMuted(scheme))
            }

            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(AuroraPalette.textMuted(scheme))
                .lineLimit(1)

            if let sub = sub {
                Text(sub)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textFaint(scheme))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(minHeight: 76)
        .auroraGlass(radius: 22)
        .overlay(alignment: .topTrailing) {
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(badgeColor))
                    .offset(x: 4, y: -6)
            }
        }
        .overlay(alignment: .topLeading) {
            if warning {
                PulsingWarningShield(color: warningColor, pulsing: warningPulsing, size: 26)
                    .offset(x: -3, y: -4)
            }
        }
    }
}

/// The top-leading expiry warning shield. Pulses (scale + glow) while
/// `pulsing` is true, otherwise sits static. Self-contained so the animation
/// state lives with the symbol. Reused by the pump tile and the sensor pill.
struct PulsingWarningShield: View {
    let color: Color
    let pulsing: Bool
    var size: CGFloat = 14

    // Declarative pulse: the animation is attached to the view tree via
    // `.animation(_:value:)` and driven by `animate`. This survives the
    // frequent re-renders of the home screen (loop timer, glucose updates),
    // unlike an imperative `withAnimation(.repeatForever)` which gets cancelled.
    @State private var animate = false

    var body: some View {
        Image(systemName: "exclamationmark.shield.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
            .scaleEffect(animate ? 1.22 : 1.0)
            .opacity(animate ? 0.55 : 1.0)
            .shadow(color: color.opacity(animate ? 0.7 : 0), radius: animate ? 5 : 0)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: animate)
            .onChange(of: pulsing, initial: true) { _, isPulsing in
                animate = isPulsing
            }
    }
}
