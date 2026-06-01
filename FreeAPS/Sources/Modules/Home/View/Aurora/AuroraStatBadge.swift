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
    }
}
