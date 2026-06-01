import SwiftUI

extension Home {
    struct BreatheBolusOverlay: View {
        let progress: Decimal // 0 ... 1
        let delivered: Decimal // units already given
        let total: Decimal // full requested bolus
        let onCancel: () -> Void

        @State private var pulse = false
        @State private var cancelPressed = false

        private var progressFraction: Double {
            let p = NSDecimalNumber(decimal: progress).doubleValue
            return min(1.0, max(0.0, p))
        }

        private var deliveredString: String {
            let d = NSDecimalNumber(decimal: delivered).doubleValue
            let t = NSDecimalNumber(decimal: total).doubleValue
            return String(format: "%.2f / %.2f E", d, t)
                .replacingOccurrences(of: ".", with: ",")
        }

        var body: some View {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(BreathePalette.daemmer)
                        .scaleEffect(pulse ? 1.08 : 0.92)
                        .opacity(pulse ? 1.0 : 0.75)
                        .animation(
                            .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                            value: pulse
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Bolus läuft")
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .foregroundStyle(.primary.opacity(0.85))
                        Text(deliveredString)
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }

                    Spacer(minLength: 8)

                    Button {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        withAnimation(.easeOut(duration: 0.12)) { cancelPressed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            withAnimation(.easeOut(duration: 0.25)) { cancelPressed = false }
                        }
                        onCancel()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10, weight: .regular))
                            Text("Stoppen")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                        }
                        .foregroundStyle(Color.white.opacity(0.97))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(BreathePalette.daemmer)
                                .shadow(
                                    color: BreathePalette.daemmer.opacity(0.35),
                                    radius: cancelPressed ? 2 : 5,
                                    x: 0,
                                    y: cancelPressed ? 1 : 2
                                )
                        )
                        .scaleEffect(cancelPressed ? 0.96 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Bolus stoppen"))
                }

                // Progress track — rounded capsule with daemmer fill.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        BreathePalette.daemmer.opacity(0.9),
                                        BreathePalette.salbei.opacity(0.9)
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * progressFraction))
                            .animation(.easeInOut(duration: 0.4), value: progressFraction)
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear { pulse = true }
        }
    }
}
