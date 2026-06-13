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
                Text(NSLocalizedString("Settings", comment: ""))
                    .font(.system(size: 32, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    .padding(.leading, 6)

                AuroraListSection(title: hubT("aur.display")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(hubT("aur.appearance"))
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(AuroraPalette.textPrimary(scheme))
                        AuroraSegmentedControl(
                            options: [
                                (LightMode.auto, hubT("aur.theme.system")),
                                (LightMode.light, hubT("aur.theme.light")),
                                (LightMode.dark, hubT("aur.theme.dark"))
                            ],
                            selection: $lightMode
                        )
                        Text(hubT("aur.theme.footer"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AuroraPalette.textMuted(scheme))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }

                AuroraListSection(title: hubT("aur.therapy")) {
                    AuroraListRow(
                        icon: "target",
                        iconColor: AuroraPalette.Status.inMain,
                        title: hubT("aur.range"),
                        value: targetRange,
                        showsChevron: false
                    )
                    Divider().overlay(AuroraPalette.hairline(scheme))
                    AuroraListRow(
                        icon: "drop.fill",
                        iconColor: AuroraPalette.pump,
                        title: hubT("aur.pump"),
                        value: reservoir,
                        showsChevron: false
                    )
                    Divider().overlay(AuroraPalette.hairline(scheme))
                    AuroraListRow(
                        icon: "sensor.tag.radiowaves.forward",
                        iconColor: AuroraPalette.sensor,
                        title: hubT("aur.cgm"),
                        value: sensorAge,
                        showsChevron: false
                    )
                }

                AuroraListSection(title: nil) {
                    AuroraListRow(
                        icon: "ellipsis",
                        iconColor: AuroraPalette.textMuted(scheme).opacity(0.5),
                        title: NSLocalizedString("Advanced Settings", comment: ""),
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
