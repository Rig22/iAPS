import SwiftUI

/// Plus/minus stepper with a large central value.
/// Step + bounds are caller-controlled.
struct AuroraStepper: View {
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let unit: String
    let accent: Color
    var format: String = "%.0f"

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 14) {
            stepButton(symbol: "minus") {
                value = max(range.lowerBound, value - step)
            }

            VStack(spacing: -4) {
                Text(String(format: format, value))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textMuted(scheme))
            }
            .frame(maxWidth: .infinity)

            stepButton(symbol: "plus") {
                value = min(range.upperBound, value + step)
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }, label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AuroraPalette.textPrimary(scheme))
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                )
        })
            .buttonStyle(.plain)
    }
}
