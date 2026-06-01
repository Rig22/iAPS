import SwiftUI

/// Glucose-driven status used for ring/chart/now-dot/FAB/loop-dot accent colors.
enum AuroraGlucoseStatus {
    case low // < 70 mg/dL
    case inRange // 70 ... 180
    case high // > 180

    static let lowThreshold: Double = 70
    static let highThreshold: Double = 180

    init(mgdl: Double) {
        if mgdl < Self.lowThreshold {
            self = .low
        } else if mgdl > Self.highThreshold {
            self = .high
        } else {
            self = .inRange
        }
    }

    var main: Color {
        switch self {
        case .low: return AuroraPalette.Status.lowMain
        case .inRange: return AuroraPalette.Status.inMain
        case .high: return AuroraPalette.Status.highMain
        }
    }

    var glow: Color {
        switch self {
        case .low: return AuroraPalette.Status.lowGlow
        case .inRange: return AuroraPalette.Status.inGlow
        case .high: return AuroraPalette.Status.highGlow
        }
    }

    var soft: Color {
        switch self {
        case .low: return AuroraPalette.Status.lowSoft
        case .inRange: return AuroraPalette.Status.inSoft
        case .high: return AuroraPalette.Status.highSoft
        }
    }

    var caption: String {
        switch self {
        case .low: return "mg/dL · unter Zielbereich"
        case .inRange: return "mg/dL · im Zielbereich"
        case .high: return "mg/dL · über Zielbereich"
        }
    }
}
