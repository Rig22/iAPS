import SwiftUI

/// Quick-Add picker — two large option tiles (Carbs / Bolus).
struct AuroraQuickAddSheet: View {
    let onCarbs: () -> Void
    let onBolus: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 14) {
            sheetTitle("Hinzufügen")

            tile(
                icon: "fork.knife",
                title: "Kohlenhydrate",
                accent: AuroraPalette.carbs(scheme),
                action: onCarbs
            )
            tile(
                icon: "syringe.fill",
                title: "Bolus",
                accent: AuroraPalette.drop(scheme),
                action: onBolus
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
            .padding(.bottom, 4)
    }

    private func tile(icon: String, title: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }, label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent)
                    )

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textMuted(scheme))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .auroraGlass(radius: 22)
        })
            .buttonStyle(.plain)
    }
}
