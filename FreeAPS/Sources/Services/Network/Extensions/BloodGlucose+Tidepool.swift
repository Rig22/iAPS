import Foundation
import HealthKit
import LoopKit

extension BloodGlucose.Direction {
    /// Maps iAPS' Nightscout-style direction enum onto LoopKit's `GlucoseTrend` (7 levels).
    var loopKitTrend: GlucoseTrend? {
        switch self {
        case .tripleUp: return .upUpUp
        case .doubleUp: return .upUp
        case .fortyFiveUp,
             .singleUp: return .up
        case .flat: return .flat
        case .fortyFiveDown,
             .singleDown: return .down
        case .doubleDown: return .downDown
        case .tripleDown: return .downDownDown
        case .none,
             .notComputable,
             .rateOutOfRange: return nil
        }
    }
}

extension BloodGlucose {
    /// Builds the LoopKit type Tidepool expects in `uploadGlucoseData`.
    /// Returns nil if the reading has no glucose value at all.
    func asStoredGlucoseSample(provenance: String) -> StoredGlucoseSample? {
        guard let mgdl = glucose ?? sgv else { return nil }
        let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: Double(mgdl))
        return StoredGlucoseSample(
            uuid: nil,
            provenanceIdentifier: provenance,
            syncIdentifier: _id,
            syncVersion: 1,
            startDate: dateString,
            quantity: quantity,
            condition: nil,
            trend: direction?.loopKitTrend,
            trendRate: nil,
            isDisplayOnly: false,
            wasUserEntered: type == "Manual",
            device: nil,
            healthKitEligibleDate: nil
        )
    }
}
