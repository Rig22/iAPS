import SwiftUI

/// Aurora Ring — 240° glucose gauge hero.
///
/// Sweeps from −120° (8 o'clock) clockwise through the top to +120° (4 o'clock),
/// gap at the bottom. Value fraction = (glucose − 40) / 260, clamped 0…1.
struct AuroraRing: View {
    let glucose: Double // mg/dL
    let delta: Int? // mg/dL
    let trendCaption: String? // e.g. "Leicht steigend"

    var direction: BloodGlucose.Direction? = nil
    var bolusProgress: Double? = nil
    var bolusTotal: Double? = nil

    var size = CGSize(width: 300, height: 250)
    var radius: CGFloat = 118
    var strokeWidth: CGFloat = 14

    @Environment(\.colorScheme) private var scheme
    @StateObject private var bolusSmooth = AuroraBolusProgressAnimator()

    private var status: AuroraGlucoseStatus { AuroraGlucoseStatus(mgdl: glucose) }

    /// 0…1 fraction across the gauge.
    private var fraction: Double {
        let f = (glucose - 40.0) / (300.0 - 40.0)
        return max(0, min(1, f))
    }

    /// CSS-style angle of the value position, with 0° at the top.
    private var valueAngleCSS: Double { -120 + 240 * fraction }

    private var center: CGPoint { CGPoint(x: size.width / 2, y: 148) }

    private var trackColor: Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color(red: 20 / 255, green: 24 / 255, blue: 32 / 255).opacity(0.07)
    }

    var body: some View {
        ZStack {
            // Track arc — full sweep
            ArcShape(startCSS: -120, endCSS: 120, radius: radius)
                .stroke(trackColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Value arc — glow copy (blurred)
            ArcShape(startCSS: -120, endCSS: valueAngleCSS, radius: radius)
                .stroke(
                    valueGradient,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .blur(radius: 6)
                .opacity(scheme == .dark ? 0.35 : 0.28)

            // Value arc — crisp copy
            ArcShape(startCSS: -120, endCSS: valueAngleCSS, radius: radius)
                .stroke(
                    valueGradient,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )

            // Value tick — white dot with status-color stroke
            tickDot

            // Bolus progress halo — thin outer arc that fills with the bolus.
            // Drawn under the tick dot so the dot stays visually on top.
            if let p = bolusProgress, p > 0 {
                let f = bolusSmooth.fraction
                let outerRadius = radius + 9
                ArcShape(startCSS: -120, endCSS: 120, radius: outerRadius)
                    .stroke(
                        AuroraPalette.hairline(scheme).opacity(0.5),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                ArcShape(startCSS: -120, endCSS: -120 + 240 * f, radius: outerRadius)
                    .stroke(
                        status.main.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
            }

            // Center text stack
            centerText
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
        .onAppear { bolusSmooth.sync(real: bolusProgress, total: bolusTotal) }
        .onChange(of: bolusProgress) { _ in bolusSmooth.sync(real: bolusProgress, total: bolusTotal) }
    }

    private var valueGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: status.main.opacity(0.5), location: 0),
                .init(color: status.main, location: 1)
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private var tickDot: some View {
        let angleRad = (valueAngleCSS - 90) * .pi / 180.0
        let x = center.x + radius * cos(angleRad)
        let y = center.y + radius * sin(angleRad)
        return Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(status.main, lineWidth: 3))
            .position(x: x, y: y)
    }

    private var centerText: some View {
        VStack(spacing: 2) {
            Text(formattedGlucose)
                .font(.system(size: 74, weight: .heavy, design: .rounded))
                .kerning(-2)
                .foregroundStyle(AuroraPalette.textPrimary(scheme))
                .monospacedDigit()

            if let delta = delta {
                Text(formattedDelta(delta))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AuroraPalette.textMuted(scheme))
            }

            // Slot below the delta: either a CGM trend arrow (preferred)
            // or an optional caption if the caller really wants text.
            if let symbol = trendArrowSymbol {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textMuted(scheme))
            } else if let caption = trendCaption {
                Text(caption)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textFaint(scheme))
            }
        }
        .position(x: center.x, y: center.y)
    }

    private var trendArrowSymbol: String? {
        switch direction {
        case .doubleUp,
             .tripleUp: return "arrow.up"
        case .singleUp: return "arrow.up.right"
        case .fortyFiveUp: return "arrow.up.right"
        case .flat: return "arrow.right"
        case .fortyFiveDown: return "arrow.down.right"
        case .singleDown: return "arrow.down.right"
        case .doubleDown,
             .tripleDown: return "arrow.down"
        case nil,
             .notComputable,
             .rateOutOfRange,
             .some(.none): return nil
        }
    }

    private var formattedGlucose: String {
        String(format: "%.0f", glucose)
    }

    private func formattedDelta(_ d: Int) -> String {
        let sign = d > 0 ? "+" : ""
        return "\(sign)\(d) mg/dL"
    }
}

/// A circular arc using CSS-style angles (0° at top, clockwise positive).
private struct ArcShape: Shape {
    let startCSS: Double
    let endCSS: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: 148) // matches AuroraRing.center
        // SwiftUI: 0° points right. Subtract 90° to align CSS-0 (top) with SwiftUI.
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startCSS - 90),
            endAngle: .degrees(endCSS - 90),
            clockwise: false
        )
        return path
    }
}
