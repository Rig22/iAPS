import SwiftUI

/// Breathing Glucose Orb — Concept #1 of the Humane Redesign.
///
/// A gently breathing circle that represents the current glucose value.
/// Inhale 4 s, exhale 6 s (total 10 s cycle) — mirrors a calming breath rhythm.
/// Colors transition softly between zones instead of hard traffic-light jumps.
struct BreathingGlucoseOrb: View {
    let glucose: Decimal // current value, already in display units
    let units: GlucoseUnits
    let lowThreshold: Decimal // in display units
    let highThreshold: Decimal // in display units

    /// Optional — trend direction (from CGM). Renders a subtle angled stroke below the orb.
    var direction: BloodGlucose.Direction? = nil
    /// Optional — raw mg/dL delta. Only shown when absolutely significant.
    var delta: Int? = nil
    /// Optional — minutes since last reading. Shown as subdued caption.
    var minutesAgo: Double? = nil
    /// Outer ring diameter.
    var size: CGFloat = 180

    /// Enable/disable the breathing animation (e.g. for reduce-motion).
    var animated: Bool = true

    // MARK: - Breathing curve

    /// Phase in [0, 1] mapped to a breathing scale in ~[0.88, 1.00].
    /// Asymmetric: 40% inhale, 60% exhale. Uses a soft cosine, not linear.
    private func breathingScale(at time: Date) -> CGFloat {
        guard animated else { return 0.94 }
        let cycle: TimeInterval = 10
        let t = time.timeIntervalSince1970.truncatingRemainder(dividingBy: cycle)
        let inhaleDuration: TimeInterval = 4
        let normalized: Double
        if t < inhaleDuration {
            // 0 → 1 over 4 s
            normalized = t / inhaleDuration
        } else {
            // 1 → 0 over 6 s
            normalized = 1 - ((t - inhaleDuration) / (cycle - inhaleDuration))
        }
        // Cosine ease: starts/ends slow, peaks smoothly in the middle.
        let eased = (1 - cos(normalized * .pi)) / 2
        return 0.88 + 0.12 * eased
    }

    // MARK: - Zone color (soft transitions)

    /// Returns the orb's primary color, interpolating across a narrow band
    /// around each threshold so there are no visible "snaps" between zones.
    private var zoneColor: Color {
        ZenPalette.zoneColor(
            value: NSDecimalNumber(decimal: glucose).doubleValue,
            low: NSDecimalNumber(decimal: lowThreshold).doubleValue,
            high: NSDecimalNumber(decimal: highThreshold).doubleValue,
            isMmolL: units == .mmolL
        )
    }

    // MARK: - Number formatting

    private var glucoseString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            formatter.roundingMode = .halfUp
        } else {
            formatter.maximumFractionDigits = 0
        }
        return formatter.string(from: glucose as NSNumber) ?? "—"
    }

    // MARK: - Satellites

    /// Rotation angle in degrees for the trend arrow (0 = up, 90 = flat, 180 = down).
    private var directionAngle: Double? {
        guard let direction = direction else { return nil }
        switch direction {
        case .doubleUp,
             .singleUp,
             .tripleUp: return 0
        case .fortyFiveUp: return 45
        case .flat: return 90
        case .fortyFiveDown: return 135
        case .doubleDown,
             .singleDown,
             .tripleDown: return 180
        case .none,
             .notComputable,
             .rateOutOfRange: return nil
        }
    }

    /// Formatted delta string, or nil if delta is absent / too small to matter.
    private var deltaString: String? {
        guard let delta = delta else { return nil }
        // Only surface a delta when it's actually a signal — otherwise it's noise.
        if units == .mmolL {
            let mmol = Double(delta) * 0.0555
            if abs(mmol) < 0.3 { return nil }
            let sign = mmol > 0 ? "+" : "−"
            return String(format: "%@%.1f", sign, abs(mmol))
        } else {
            if abs(delta) < 5 { return nil }
            let sign = delta > 0 ? "+" : "−"
            return "\(sign)\(abs(delta))"
        }
    }

    private var minutesAgoString: String? {
        guard let m = minutesAgo else { return nil }
        if m < 1 { return NSLocalizedString("Now", comment: "") }
        let mInt = Int(m)
        return "\(NSLocalizedString("vor", comment: "ago")) \(mInt) \(NSLocalizedString("min", comment: ""))"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            orb

            // Satellite row — arrow + minutes + delta, all tiny and humble.
            HStack(spacing: 8) {
                if let angle = directionAngle {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .light))
                        .rotationEffect(.degrees(angle))
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.6), value: angle)
                }
                if let m = minutesAgoString {
                    Text(m)
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(.secondary)
                }
                if let d = deltaString {
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Text(d)
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 16)
        }
    }

    private var orb: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { context in
            let scale = breathingScale(at: context.date)
            let color = zoneColor

            ZStack {
                // Outer soft glow — breathes slightly more than the orb itself.
                Circle()
                    .fill(color.opacity(0.18))
                    .blur(radius: 24)
                    .scaleEffect(scale * 1.08)

                // Main orb — radial gradient, center slightly brighter.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(0.95),
                                color.opacity(0.65)
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: size / 2
                        )
                    )
                    .scaleEffect(scale)
                    .shadow(color: color.opacity(0.35), radius: 12, x: 0, y: 4)

                // Inner highlight — a touch of luminosity, top-left.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.0)],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 2,
                            endRadius: size / 3
                        )
                    )
                    .scaleEffect(scale)
                    .blendMode(.plusLighter)

                // Glucose number — humanistic serif for warmth.
                Text(glucoseString)
                    .font(.system(size: size * 0.24, weight: .light, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
            .frame(width: size, height: size)
            .animation(.easeInOut(duration: 1.2), value: color)
        }
    }
}

// MARK: - Preview

#Preview("In Range — breathing") {
    BreathingGlucoseOrb(
        glucose: 112,
        units: .mgdL,
        lowThreshold: 70,
        highThreshold: 180
    )
    .padding(40)
    .background(Color(red: 0.98, green: 0.96, blue: 0.93))
}

#Preview("Low") {
    BreathingGlucoseOrb(
        glucose: 62,
        units: .mgdL,
        lowThreshold: 70,
        highThreshold: 180
    )
    .padding(40)
    .background(Color(red: 0.10, green: 0.12, blue: 0.18))
}

#Preview("High") {
    BreathingGlucoseOrb(
        glucose: 215,
        units: .mgdL,
        lowThreshold: 70,
        highThreshold: 180
    )
    .padding(40)
    .background(Color(red: 0.98, green: 0.96, blue: 0.93))
}

#Preview("mmol/L transition edge") {
    BreathingGlucoseOrb(
        glucose: 4.1,
        units: .mmolL,
        lowThreshold: 3.9,
        highThreshold: 10.0
    )
    .padding(40)
    .background(Color(red: 0.98, green: 0.96, blue: 0.93))
}
