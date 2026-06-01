import SwiftUI

struct AuroraSettingsScreen: View {
    @Binding var lightMode: LightMode
    let targetRange: String // e.g. "70–180 mg/dL"
    let reservoir: String // e.g. "78 E"
    let sensorAge: String // e.g. "6 Tg"
    let onOpenAdvanced: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Einstellungen")
                    .font(.system(size: 32, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    .padding(.leading, 6)

                AuroraListSection(title: "Darstellung") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Erscheinungsbild")
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(AuroraPalette.textPrimary(scheme))
                        AuroraSegmentedControl(
                            options: [
                                (LightMode.auto, "System"),
                                (LightMode.light, "Hell"),
                                (LightMode.dark, "Dunkel")
                            ],
                            selection: $lightMode
                        )
                        Text("Steuert das Theme der gesamten App.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AuroraPalette.textMuted(scheme))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }

                AuroraListSection(title: "Therapie") {
                    AuroraListRow(
                        icon: "target",
                        iconColor: AuroraPalette.Status.inMain,
                        title: "Zielbereich",
                        value: targetRange,
                        showsChevron: false
                    )
                    Divider().overlay(AuroraPalette.hairline(scheme))
                    AuroraListRow(
                        icon: "drop.fill",
                        iconColor: AuroraPalette.pump,
                        title: "Insulin-Pumpe",
                        value: reservoir,
                        showsChevron: false
                    )
                    Divider().overlay(AuroraPalette.hairline(scheme))
                    AuroraListRow(
                        icon: "sensor.tag.radiowaves.forward",
                        iconColor: AuroraPalette.sensor,
                        title: "CGM-Sensor",
                        value: sensorAge,
                        showsChevron: false
                    )
                }

                AuroraListSection(title: nil) {
                    AuroraListRow(
                        icon: "ellipsis",
                        iconColor: AuroraPalette.textMuted(scheme).opacity(0.5),
                        title: "Erweiterte Einstellungen",
                        onTap: onOpenAdvanced
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 74)
            .padding(.bottom, 110)
        }
    }
}
