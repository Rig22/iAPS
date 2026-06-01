import SwiftUI

/// Stepper-based carb entry sheet. Caller persists the value on save.
struct AuroraCarbSheet: View {
    @Binding var grams: Double
    let onSave: (Double) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    private let quickChips: [Double] = [10, 20, 40, 60]

    private var accent: Color { AuroraPalette.carbs(scheme) }

    var body: some View {
        VStack(spacing: 18) {
            sheetTitle("Kohlenhydrate")

            AuroraStepper(
                value: $grams,
                step: 5,
                range: 0 ... 250,
                unit: "g",
                accent: accent
            )
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                ForEach(quickChips, id: \.self) { value in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        grams = value
                    } label: {
                        Text("\(Int(value)) g")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AuroraPalette.textPrimary(scheme))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            AuroraPrimaryButton(
                title: "\(Int(grams)) g eintragen",
                accent: accent,
                action: {
                    onSave(grams)
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
}
