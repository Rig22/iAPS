import SwiftUI

struct AuroraProfileScreen: View {
    let activeProfileName: String
    let basalRate: String // e.g. "0,75 E/h"
    let carbRatio: String // e.g. "9 g/E"
    let isf: String // e.g. "42 mg/dL/E"
    let dia: String // e.g. "6 h"
    let autosens: String // e.g. "×1,03"
    let smbEnabled: Bool

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Profil")
                    .font(.system(size: 32, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    .padding(.leading, 6)

                AuroraListSection(title: "Aktives Profil") {
                    AuroraListRow(
                        icon: "person.fill",
                        iconColor: AuroraPalette.pump,
                        title: activeProfileName,
                        value: "aktiv",
                        showsChevron: false
                    )
                }

                AuroraListSection(title: "Dosierung") {
                    AuroraListRow(
                        icon: "drop.fill",
                        iconColor: AuroraPalette.drop(scheme),
                        title: "Basalrate",
                        value: basalRate,
                        showsChevron: false
                    )
                    Divider().overlay(AuroraPalette.hairline(scheme))
                    AuroraListRow(
                        icon: "fork.knife",
                        iconColor: AuroraPalette.carbs(scheme),
                        title: "KH-Verhältnis (IC)",
                        value: carbRatio,
                        showsChevron: false
                    )
                    Divider().overlay(AuroraPalette.hairline(scheme))
                    AuroraListRow(
                        icon: "arrow.down.right",
                        iconColor: AuroraPalette.pump,
                        title: "Korrekturfaktor (ISF)",
                        value: isf,
                        showsChevron: false
                    )
                    Divider().overlay(AuroraPalette.hairline(scheme))
                    AuroraListRow(
                        icon: "clock.fill",
                        iconColor: AuroraPalette.sensor,
                        title: "Wirkdauer (DIA)",
                        value: dia,
                        showsChevron: false
                    )
                }

                AuroraListSection(title: "Automatik") {
                    AuroraListRow(
                        icon: "waveform.path.ecg",
                        iconColor: AuroraPalette.pump,
                        title: "Autosens",
                        value: autosens,
                        showsChevron: false
                    )
                    Divider().overlay(AuroraPalette.hairline(scheme))
                    AuroraListRow(
                        icon: "bolt.fill",
                        iconColor: AuroraPalette.drop(scheme),
                        title: "SMB aktiviert",
                        value: smbEnabled ? "Ein" : "Aus",
                        showsChevron: false
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 74)
            .padding(.bottom, 110)
        }
    }
}
