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
            sheetTitle(NSLocalizedString("Enact bolus", comment: "Aurora bolus sheet title"))

            HStack(spacing: 28) {
                stat(
                    label: NSLocalizedString("Recommendation", comment: "Aurora bolus sheet recommendation label"),
                    value: recommendation
                        .map { String(format: "%.1f%@", $0, NSLocalizedString(" U", comment: "Insulin unit")) } ?? "—"
                )
                stat(
                    label: NSLocalizedString("Insulin on Board", comment: "Aurora bolus sheet IOB label"),
                    value: String(format: "%.1f%@", iob, NSLocalizedString(" U", comment: "Insulin unit"))
                )
            }

            AuroraStepper(
                value: $units,
                step: 0.1,
                range: 0 ... 25,
                unit: NSLocalizedString(" U", comment: "Insulin unit").trimmingCharacters(in: .whitespaces),
                accent: accent,
                format: "%.1f"
            )
            .padding(.vertical, 8)

            AuroraPrimaryButton(
                title: NSLocalizedString("Enact bolus", comment: "Aurora bolus sheet deliver button")
                    + String(format: " (%.1f%@)", units, NSLocalizedString(" U", comment: "Insulin unit")),
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
