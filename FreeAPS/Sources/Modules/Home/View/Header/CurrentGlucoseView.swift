import SwiftUI

struct CurrentGlucoseView: View {
    @Binding var recentGlucose: BloodGlucose?
    @Binding var delta: Int?
    @Binding var units: GlucoseUnits
    @Binding var alarm: GlucoseAlarm?
    @Binding var lowGlucose: Decimal
    @Binding var highGlucose: Decimal
    @Binding var alwaysUseColors: Bool
    @Binding var displayDelta: Bool
    @Binding var scrolling: Bool
    @Binding var displaySAGE: Bool
    @Binding var displayExpiration: Bool
    @Binding var sensordays: Double
    @Binding var timerDate: Date

    var eventualBG: Int? = nil

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) private var fontSize

    // MARK: - Formatters

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            formatter.roundingMode = .halfUp
        }
        return formatter
    }

    private var timaAgoFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.negativePrefix = ""
        return formatter
    }

    // MARK: - Rotations-Logik

    private var adjustments: (degree: Double, x: CGFloat, y: CGFloat) {
        guard let direction = recentGlucose?.direction else {
            return (90, 0, 0)
        }
        switch direction {
        case .doubleUp,
             .singleUp,
             .tripleUp: return (0, 0, 0) // ↑
        case .fortyFiveUp: return (45, 0, 0) // ↗︎
        case .flat: return (90, 0, 0) // →
        case .fortyFiveDown: return (135, 0, 0) // ↘︎
        case .doubleDown,
             .singleDown,
             .tripleDown: return (180, 0, 0) // ↓
        case .none,
             .notComputable,
             .rateOutOfRange: return (90, 0, 0)
        }
    }

    // MARK: - Body

    var body: some View {
        glucoseView
            .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.xLarge)
    }

    var glucoseView: some View {
        ZStack(alignment: .center) {
            if let recent = recentGlucose {
                // EBENE 1: Der Hintergrund
                ZStack {
                    // 1a. Der Haupt-Kreis
                    Circle()
                        .fill(colorScheme == .dark ? .white.opacity(0.15) : .white)
                        .frame(
                            width: scrolling ? 90 : 165,
                            height: scrolling ? 90 : 165
                        )
                        .background(
                            Group {
                                if colorScheme != .dark {
                                    Circle()
                                        .fill(Color.white)
                                        .shadow(color: colorOfGlucose.opacity(0.15), radius: 15, x: 0, y: 8)
                                } else {
                                    Color.clear
                                }
                            }
                        )

                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: colorScheme == .dark ? [
                                    Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.6),
                                    Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.8),
                                    Color(red: 0.0, green: 0.2, blue: 0.7).opacity(1.0)
                                ] : [
                                    Color(red: 0.7, green: 0.9, blue: 0.5).opacity(0.10),
                                    Color(red: 0.3, green: 0.8, blue: 0.6).opacity(0.15),
                                    Color(red: 0.1, green: 0.6, blue: 0.9).opacity(0.20)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: scrolling ? 85 : 158, height: scrolling ? 85 : 158)
                        .blur(radius: 2)

                    // 1c. Die Spitze (Beak) - NUR DIESER TEIL DREHT SICH
                    if !scrolling {
                        Image(systemName: "triangle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 14)
                            .foregroundStyle(colorScheme == .dark ? Color(white: 0.20) : .white)
                            .offset(y: -88)

                            // Hier ist die Drehung nur für den Beak:
                            .rotationEffect(.degrees(adjustments.degree))
                            .animation(.bouncy(duration: 0.8), value: adjustments.degree)
                    }
                }

                // EBENE 2: Die Werte (Zentral, feststehend)
                VStack(spacing: 2) {
                    let val = Double(units == .mmolL ? recent.glucose?.asMmolL ?? 0 : Decimal(recent.glucose ?? 0))

                    Text(glucoseFormatter.string(from: val as NSNumber) ?? "--")
                        .font(.system(size: scrolling ? 34 : 62, design: .rounded))
                        .foregroundColor(alwaysUseColors ? colorOfGlucose : .primary)

                    if !scrolling {
                        VStack(spacing: 0) {
                            /*   let deltaValue = delta ?? 0
                             let deltaString = deltaValue > 0 ? "+\(deltaValue)" : "\(deltaValue)"

                             Text("\(deltaString) Δ")
                                 .font(.system(size: 16, weight: .bold, design: .rounded))
                                 .foregroundColor(deltaColor)*/

                            let minutesAgo = timerDate.timeIntervalSince(recent.dateString) / 60
                            let timeText = timaAgoFormatter.string(for: Double(minutesAgo)) ?? ""
                            Text(minutesAgo <= 1 ? "Jetzt" : "vor \(timeText) Min")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                    }
                }
                // (Prediction etc.)
                /*  if !scrolling, let deltaInt = delta {
                     HStack(spacing: 4) {
                         Image(systemName: "arrow.right")
                             .font(.system(size: 14))
                             .foregroundStyle(.secondary)

                         Text("\(eventualBG ?? (recent.glucose ?? 0) + deltaInt)")
                             .font(.system(size: 20, weight: .semibold))

                         Text(units.rawValue)
                             .font(.system(size: 12))
                             .foregroundStyle(.secondary)
                     }
                     .offset(x: 145)
                 }*/
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var colorOfGlucose: Color {
        let whichGlucose = recentGlucose?.glucose ?? 0
        guard lowGlucose < highGlucose else { return Color(red: 0.15, green: 0.83, blue: 0.55) }

        if whichGlucose < Int(lowGlucose) {
            return Color(red: 1.0, green: 0.2, blue: 0.3) // Ein "leuchtendes" Rot-Pink
        }
        if whichGlucose > Int(highGlucose) {
            return Color.orange
        }

        // Smaragd-Grün
        return Color(red: 0.15, green: 0.83, blue: 0.55)
    }

    private var deltaColor: Color {
        guard let delta = delta else { return .secondary }

        if delta > 10 {
            return Color.red.opacity(0.7) // Grün bei starkem Anstieg (>10)
        } else if delta < -10 {
            return Color.red.opacity(0.7) // Rot bei starkem Abfall (<-10)
        } else {
            return .secondary // Bei kleinen Änderungen (±10) = Neutral
        }
    }
}
