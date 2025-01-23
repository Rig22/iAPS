import SwiftUI

struct CurrentGlucoseView: View {
    @Binding var recentGlucose: BloodGlucose?
    @Binding var timerDate: Date
    @Binding var delta: Int?
    @Binding var units: GlucoseUnits
    @Binding var alarm: GlucoseAlarm?
    @Binding var lowGlucose: Decimal
    @Binding var highGlucose: Decimal
    @Binding var bolusProgress: Double?

    @State private var rotationDegrees: Double = 0
    @State private var bumpEffect: Double = 0

    // var backgroundColor: Color //falls triangel während bolus in backgroundColor gewünscht ist

    // Bedingte Farbauswahl für das Dreieck
    private var currentTriangleColor: Color {
        if let progress = bolusProgress, progress < 1.0 {
            return Color.clear
        } else {
            return Color.white
        }
    }

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = units == .mmolL ? 1 : 0
        formatter.roundingMode = .halfUp
        return formatter
    }

    private var deltaFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "  +"
        formatter.negativePrefix = "  -"
        return formatter
    }

    private var timaAgoFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    var body: some View {
        // let triangleColor = Color(red: 0.18, green: 0.35, blue: 0.58)
        // let triangleColor = Color.white.opacity(0.7)
        let triangleColor = colourGlucoseText.opacity(0.7)

        let angularGradient = AngularGradient(
            gradient: Gradient(colors: [
                /* Color.blue.opacity(0.7),
                 Color.blue.opacity(0.6),
                 Color.blue.opacity(0.6),
                 Color.blue.opacity(0.5),
                 Color.blue.opacity(0.5),
                 Color.blue.opacity(0.5),
                 Color.blue.opacity(0.6),
                 Color.blue.opacity(0.6),
                 Color.blue.opacity(0.7)*/
                Color.darkGray.opacity(0.4)
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )

        ZStack {
            Circle()
                .fill(angularGradient)
                .frame(width: 110, height: 110)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 0)
                )

            // TriangleShape(color: triangleColor)
            TriangleShape(color: currentTriangleColor)
                .rotationEffect(.degrees(rotationDegrees + bumpEffect))
                .animation(.easeInOut(duration: 3.0), value: rotationDegrees)

            /* Circle()
             .fill(Color.clear.opacity(1.0))
             .frame(width: 110, height: 110)*/

            VStack(alignment: .center) {
                HStack {
                    Text(
                        (recentGlucose?.glucose ?? 100) == 400 ? "HIGH" : recentGlucose?.glucose
                            .map {
                                glucoseFormatter
                                    .string(from: Double(units == .mmolL ? $0.asMmolL : Decimal($0)) as NSNumber)!
                            } ?? "--"
                    )
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(alarm == nil ? colourGlucoseText : .yellow)
                    // .foregroundStyle(Color.white)
                }
                HStack {
                    let elapsedSeconds = -1 * (recentGlucose?.dateString.timeIntervalSinceNow ?? 0)
                    let elapsedMinutes = elapsedSeconds / 60
                    let timeText = timaAgoFormatter.string(for: floor(elapsedMinutes)) ?? ""

                    Text(
                        elapsedSeconds < 60 ? "Now" : "\(timeText) min"
                    )
                    .font(.caption2)
                    .foregroundStyle(Color.white)

                    Text(
                        delta
                            .map {
                                deltaFormatter.string(from: Double(units == .mmolL ? $0.asMmolL : Decimal($0)) as NSNumber)!
                            } ?? "--"
                    )
                    .font(.caption2)
                    .foregroundStyle(Color.white)
                }
            }
        }
        .onChange(of: recentGlucose?.direction) { newDirection in
            switch newDirection {
            case .doubleUp,
                 .singleUp,
                 .tripleUp:
                rotationDegrees = -90
            case .fortyFiveUp:
                rotationDegrees = -45
            case .flat:
                rotationDegrees = 0
            case .fortyFiveDown:
                rotationDegrees = 45
            case .doubleDown,
                 .singleDown,
                 .tripleDown:
                rotationDegrees = 90
            case .none?,
                 .notComputable,
                 .rateOutOfRange:
                rotationDegrees = 0
            @unknown default:
                rotationDegrees = 0
            }

            withAnimation(.interpolatingSpring(stiffness: 100, damping: 5).delay(0.5)) {
                bumpEffect = 5
                bumpEffect = 0
            }
        }
    }

    var colourGlucoseText: Color {
        let whichGlucose = recentGlucose?.glucose ?? 0
        let defaultColor = Color.green

        guard lowGlucose < highGlucose else { return .primary }

        switch whichGlucose {
        case 0 ..< Int(lowGlucose):
            return .red
        case Int(lowGlucose) ..< Int(highGlucose):
            return defaultColor
        case Int(highGlucose)...:
            return .yellow
        default:
            return defaultColor
        }
    }
}

struct TrendShape: View {
    let gradient: AngularGradient
    let color: Color

    var body: some View {
        HStack(alignment: .center) {
            ZStack {
                Group {
                    TriangleShape(color: color)
                }
            }
        }
    }
}

struct TriangleShape: View {
    let color: Color

    var body: some View {
        Triangle()
            .fill(color)
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(90))
            .offset(x: 70)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 15))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.midY + 10))
        path.closeSubpath()

        return path
    }
}
