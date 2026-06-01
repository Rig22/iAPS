import SwiftUI

/// Stepper-based bolus delivery sheet. Caller delivers on save.
struct AuroraBolusSheet: View {
    @Binding var units: Double
    let recommendation: Double? // E
    let iob: Double // E
    let onDeliver: (Double) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { AuroraPalette.drop(scheme) }

    var body: some View {
        VStack(spacing: 18) {
            sheetTitle("Bolus abgeben")

            HStack(spacing: 28) {
                stat(label: "Empfehlung", value: recommendation.map { String(format: "%.1f E", $0) } ?? "—")
                stat(label: "Aktives Insulin", value: String(format: "%.1f E", iob))
            }

            AuroraStepper(
                value: $units,
                step: 0.1,
                range: 0 ... 25,
                unit: "E",
                accent: accent,
                format: "%.1f"
            )
            .padding(.vertical, 8)

            AuroraPrimaryButton(
                title: String(format: "%.1f E abgeben", units),
                accent: accent,
                action: {
                    onDeliver(units)
                    dismiss()
                }
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 30)
    }

    private func sheetTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(AuroraPalette.textPrimary(scheme))
            .frame(maxWidth: .infinity)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AuroraPalette.textPrimary(scheme))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AuroraPalette.textMuted(scheme))
        }
        .frame(maxWidth: .infinity)
    }
}
