import SwiftUI

extension Home {
    struct StatusCards: View {
        @ObservedObject var state: Home.StateModel
        @Environment(\.colorScheme) var colorScheme

        // Formatter für die IOB Anzeige (1 Nachkommastellen)
        private var targetFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1 // 2
            formatter.minimumFractionDigits = 1 // 2
            return formatter
        }

        @FetchRequest(
            entity: InsulinConcentration.entity(),
            sortDescriptors: [NSSortDescriptor(
                key: "date",
                ascending: true
            )]
        ) var concentration: FetchedResults<InsulinConcentration>

        var body: some View {
            let patchStatus: String = {
                guard let expiresAt = state.pumpExpiresAtDate else {
                    return "--"
                }

                let remaining = expiresAt.timeIntervalSince(Date())

                if remaining <= 0 {
                    return NSLocalizedString("Replace", comment: "")
                }

                let totalMinutes = Int(remaining / 60)
                let days = totalMinutes / (24 * 60)
                let hours = (totalMinutes % (24 * 60)) / 60
                let minutes = totalMinutes % 60

                return "\(days)d \(hours)h \(minutes)m"
            }()

            HStack(alignment: .top, spacing: 10) {
                // 1. IOB Card
                statusCard(
                    value: targetFormatter.string(from: (state.data.iob ?? 0) as NSNumber) ?? "0.0",
                    unit: "U",
                    title: "Insulin on Board",
                    icon: {
                        AnyView(ModernBolusDrop(size: 18))
                    }
                )

                // 2. Reservoir & Patch Card
                let concentrationValue = Double(truncating: (concentration.last?.concentration ?? 1) as NSNumber)
                let adjustedReservoir = Double(truncating: (state.reservoir ?? 0) as NSNumber) * concentrationValue
                let isReplaceActive = (patchStatus == NSLocalizedString("Replace", comment: ""))

                // DYNAMISCHE KAPAZITÄT
                let maxCapacity: Double = {
                    if let maxRes = state.openAPSSettings?.maximumReservoir {
                        return Double(truncating: maxRes as! NSNumber)
                    }
                    return 200.0
                }()

                let physicalReservoir = Double(truncating: (state.reservoir ?? 0) as NSNumber)
                let portion = 1.0 - max(0, min(1, physicalReservoir / maxCapacity))

                statusCard(
                    value: "\(Int(adjustedReservoir))",
                    unit: "U",
                    title: "\(patchStatus)",
                    icon: {
                        AnyView(
                            ZStack {
                                let isMedtrum = state.pumpName.contains("Medtrum")
                                let imageName = isMedtrum ? "nano" : (colorScheme == .dark ? "pod_dark" : "pod_light")

                                // 1. Das UIImage aus den Assets laden
                                if let uiImage = UIImage(named: imageName) {
                                    let fillStyleColor: Color = adjustedReservoir < 20 ? .red : .insulin
                                    uiImage.fillImageUpToPortion(
                                        color: fillStyleColor.opacity(0.8),
                                        portion: portion
                                    )
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: isMedtrum ? 20 : 26, height: 26)
                                    .opacity(isReplaceActive ? 0.5 : 1.0)
                                }

                                if isReplaceActive {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.red)
                                        .background(Circle().fill(.white).frame(width: 10, height: 10))
                                        .offset(x: 8, y: -8)
                                }
                            }
                        )
                    },
                    isCritical: isReplaceActive,
                    onTap: {
                        if state.pumpDisplayState != nil {
                            state.setupPump = true
                        }
                    }
                )
                .overlay(alignment: .topLeading) {
                    if concentrationValue != 1, !state.settingsManager.settings.hideInsulinBadge {
                        NonStandardInsulin(
                            concentration: Double(concentrationValue),
                            pump: state.pumpName.contains("Medtrum") ? .medtrum : .pod
                        )
                        .offset(x: 0, y: 30)
                    }
                }

                // 3. COB Card
                statusCard(
                    value: "\(Int(state.data.suggestion?.cob ?? 0))",
                    unit: "g",
                    title: "Carbs",
                    icon: {
                        AnyView(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.loopYellow)
                        )
                    }
                )
            }
            .padding(.horizontal)
            .frame(height: 60)
        }

        // MARK: - Card Builder

        @ViewBuilder func statusCard(
            value: String,
            unit: String,
            title: LocalizedStringKey,
            @ViewBuilder icon: @escaping () -> AnyView,
            isCritical: Bool = false,
            onTap: (() -> Void)? = nil
        ) -> some View {
            let cardContent = VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    icon()
                        .frame(width: 25)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.system(size: 24, design: .rounded))
                        Text(unit)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0) // Drückt den Inhalt nach links
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCritical ? .red : .secondary)
                    .lineLimit(1)
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.0) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0 : 0.05), lineWidth: 1)
                    )
                    // 1. Kernschatten
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.08), radius: 2, x: 0, y: 1)
                    // 2. Umgebungslicht für Tiefe
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, x: 0, y: 6)
            )

            if let onTap = onTap {
                cardContent
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
            } else {
                cardContent
            }
        }
    }
}
