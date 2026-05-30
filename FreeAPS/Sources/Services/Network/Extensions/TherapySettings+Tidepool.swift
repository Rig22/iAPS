import Foundation
import HealthKit
import LoopKit

extension GlucoseUnits {
    var hkUnit: HKUnit {
        self == .mgdL ? .milligramsPerDeciliter : .millimolesPerLiter
    }
}

extension Array where Element == BasalProfileEntry {
    func asBasalRateSchedule(timeZone: TimeZone = .current) -> BasalRateSchedule? {
        let items = map { entry in
            RepeatingScheduleValue(startTime: TimeInterval(entry.minutes * 60), value: Double(entry.rate))
        }
        return BasalRateSchedule(dailyItems: items, timeZone: timeZone)
    }
}

extension CarbRatios {
    func asCarbRatioSchedule(timeZone: TimeZone = .current) -> CarbRatioSchedule? {
        let items = schedule.map { entry in
            RepeatingScheduleValue(startTime: TimeInterval(entry.offset * 60), value: Double(entry.ratio))
        }
        return CarbRatioSchedule(unit: .gram(), dailyItems: items, timeZone: timeZone)
    }
}

extension InsulinSensitivities {
    func asInsulinSensitivitySchedule(timeZone: TimeZone = .current) -> InsulinSensitivitySchedule? {
        // `units` comes from the data model itself, not the user's display preference.
        let unit = units.hkUnit
        let items = sensitivities.map { entry in
            RepeatingScheduleValue(startTime: TimeInterval(entry.offset * 60), value: Double(entry.sensitivity))
        }
        return InsulinSensitivitySchedule(unit: unit, dailyItems: items, timeZone: timeZone)
    }
}

extension BGTargets {
    func asGlucoseRangeSchedule(timeZone: TimeZone = .current) -> GlucoseRangeSchedule? {
        let unit = units.hkUnit
        let items = targets.map { entry in
            RepeatingScheduleValue(
                startTime: TimeInterval(entry.offset * 60),
                value: DoubleRange(minValue: Double(entry.low), maxValue: Double(entry.high))
            )
        }
        let schedule = DailyQuantitySchedule(unit: unit, dailyItems: items, timeZone: timeZone)
        return schedule.map { GlucoseRangeSchedule(rangeSchedule: $0) }
    }
}

extension Preferences {
    /// Maps iAPS' oref insulin curve + pump insulin type onto LoopKit's `StoredInsulinModel`.
    func asStoredInsulinModel(insulinType: InsulinType?, dia: Double) -> StoredInsulinModel {
        let modelType: StoredInsulinModel.ModelType
        let preset: ExponentialInsulinModelPreset
        switch curve {
        case .bilinear,
             .rapidActing:
            modelType = .rapidAdult
            preset = .rapidActingAdult
        case .ultraRapid:
            let isLyumjev = insulinType == .lyumjev
            modelType = isLyumjev ? .lyumjev : .fiasp
            preset = isLyumjev ? .lyumjev : .fiasp
        }

        let peakActivity: TimeInterval = useCustomPeakTime
            ? .minutes(Double(insulinPeakTime))
            : preset.peakActivity

        return StoredInsulinModel(
            modelType: modelType,
            delay: preset.delay,
            actionDuration: .hours(dia),
            peakActivity: peakActivity
        )
    }
}
