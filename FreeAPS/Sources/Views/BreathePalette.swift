import SwiftUI

/// Central design palette for the Humane Redesign ("Breathe").
enum BreathePalette {
    // MARK: - Glucose zones

    /// In range — sage green. #8FB5A0
    static let salbei = Color(red: 0.56, green: 0.71, blue: 0.62)

    /// Low — dusk blue. Reassuring, not alarming. #6B8AB8
    static let daemmer = Color(red: 0.42, green: 0.54, blue: 0.72)

    /// High — warm cream. Desaturated so it stays in the calm family. #E8B885
    static let kamille = Color(red: 0.91, green: 0.72, blue: 0.52)

    // MARK: - Accents

    /// Overrides / profiles — muted lavender. #B29ECC
    static let flieder = Color(red: 0.70, green: 0.62, blue: 0.80)

    // MARK: - Swatch / status-tile variants

    //
    // Same hue family as the soft palette, but deeper and more saturated so
    // white text reads cleanly even in light mode. The orb keeps the calm
    // pastel originals — these are *only* for the status swatches.

    /// IOB swatch — deeper dusk blue.
    static let daemmerDeep = Color(red: 0.30, green: 0.44, blue: 0.66)

    /// COB swatch — deeper sage.
    static let salbeiDeep = Color(red: 0.40, green: 0.60, blue: 0.48)

    /// Reservoir swatch — deeper warm tan.
    static let kamilleDeep = Color(red: 0.82, green: 0.60, blue: 0.36)

    /// Loop swatch — deeper lavender.
    static let fliederDeep = Color(red: 0.58, green: 0.48, blue: 0.72)

    // MARK: - Surfaces

    /// Cool off-white for light-mode background tints. #F7F5F0
    static let dunstLight = Color(red: 0.97, green: 0.96, blue: 0.94)

    /// Deep twilight for dark-mode background tints. #17191F
    static let dunstDark = Color(red: 0.09, green: 0.10, blue: 0.13)

    // MARK: - Strokes

    /// Subtle card/container outline in light mode.
    static let strokeLight = Color.black.opacity(0.06)

    /// Subtle card/container outline in dark mode.
    static let strokeDark = Color.white.opacity(0.10)

    // MARK: - Zone resolution with soft transition band

    /// Returns the appropriate zone color for a given glucose value,
    /// with a soft interpolated band across thresholds (no hard snaps).
    /// - Parameters:
    ///   - value: glucose in display units (mg/dL or mmol/L)
    ///   - low: low threshold in display units
    ///   - high: high threshold in display units
    ///   - isMmolL: if true, uses a narrower 0.6 band; otherwise 10 mg/dL
    static func zoneColor(
        value: Double,
        low: Double,
        high: Double,
        isMmolL: Bool = false
    ) -> Color {
        let band: Double = isMmolL ? 0.6 : 10
        if value <= low - band { return daemmer }
        if value >= high + band { return kamille }
        if value < low + band {
            let t = (value - (low - band)) / (2 * band)
            return blend(daemmer, salbei, t: t)
        }
        if value > high - band {
            let t = (value - (high - band)) / (2 * band)
            return blend(salbei, kamille, t: t)
        }
        return salbei
    }

    /// Linear interpolation between two SwiftUI colors in device RGB.
    static func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        let c = min(max(t, 0), 1)
        let ua = UIColor(a)
        let ub = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ua.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        ub.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: Double(ar + (br - ar) * CGFloat(c)),
            green: Double(ag + (bg - ag) * CGFloat(c)),
            blue: Double(ab + (bb - ab) * CGFloat(c))
        )
    }
}
