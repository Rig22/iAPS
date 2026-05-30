import Foundation
import LoopKit

extension PumpHistoryEvent {
    var isBolusLike: Bool {
        switch type {
        case .bolus,
             .correctionBolus,
             .isExternal,
             .mealBolus,
             .smb,
             .snackBolus: return true
        default: return false
        }
    }

    /// One-shot conversion for bolus-style events.
    /// External insulin is marked `manuallyEntered = true` and `automatic = false`.
    func asBolusDoseEntry(provenance _: String) -> DoseEntry? {
        guard isBolusLike, let amount = amount else { return nil }
        let units = Double(truncating: amount as NSNumber)
        let isExt = (type == .isExternal) || (isExternal == true)
        let isSMBOrAuto = (isSMB == true) || type == .smb

        return DoseEntry(
            type: .bolus,
            startDate: timestamp,
            endDate: timestamp,
            value: units,
            unit: .units,
            deliveredUnits: units,
            description: note,
            syncIdentifier: id,
            scheduledBasalRate: nil,
            insulinType: nil,
            automatic: isExt ? false : isSMBOrAuto,
            manuallyEntered: isExt,
            isMutable: false,
            wasProgrammedByPumpUI: false
        )
    }

    /// Converts a `tempBasal` + `tempBasalDuration` pair with matching timestamps into a single
    /// `DoseEntry.tempBasal`. Pass the rate event as `self` and the duration event explicitly.
    func asTempBasalDoseEntry(durationEvent: PumpHistoryEvent, provenance _: String) -> DoseEntry? {
        guard type == .tempBasal,
              durationEvent.type == .tempBasalDuration,
              durationEvent.timestamp == timestamp,
              let rate = rate,
              let durationMin = durationEvent.durationMin
        else { return nil }

        let rateValue = Double(truncating: rate as NSNumber)
        let end = timestamp.addingTimeInterval(TimeInterval(durationMin) * 60)
        return DoseEntry(
            type: .tempBasal,
            startDate: timestamp,
            endDate: end,
            value: rateValue,
            unit: .unitsPerHour,
            deliveredUnits: nil,
            description: nil,
            syncIdentifier: id,
            scheduledBasalRate: nil,
            insulinType: nil,
            automatic: true,
            manuallyEntered: false,
            isMutable: false,
            wasProgrammedByPumpUI: false
        )
    }

    /// Pump suspend / resume markers as `DoseEntry`.
    func asSuspendResumeDoseEntry() -> DoseEntry? {
        switch type {
        case .pumpSuspend: return DoseEntry(suspendDate: timestamp, automatic: false)
        case .pumpResume: return DoseEntry(resumeDate: timestamp, automatic: false)
        default: return nil
        }
    }

    /// Non-dose events (alarms, prime, rewind) as `PersistedPumpEvent`.
    func asPersistedPumpEvent() -> PersistedPumpEvent? {
        let pumpType: PumpEventType?
        switch type {
        case .pumpAlarm: pumpType = .alarm
        case .prime: pumpType = .prime
        case .rewind: pumpType = .rewind
        default: return nil
        }

        // PersistedPumpEvent.objectIDURL is required (LoopKit's CoreData id).
        // iAPS has no CoreData here, so fabricate a stable URL from the event's sync id.
        let url = URL(string: "iaps://pump-event/\(id)") ?? URL(fileURLWithPath: "/dev/null")

        return PersistedPumpEvent(
            date: timestamp,
            persistedDate: timestamp,
            dose: nil,
            isUploaded: false,
            objectIDURL: url,
            raw: nil,
            title: note,
            type: pumpType,
            automatic: nil,
            alarmType: nil
        )
    }
}

extension Array where Element == PumpHistoryEvent {
    /// Walks the recent-pump-history array and returns LoopKit dose entries.
    /// Pairs adjacent `.tempBasal` / `.tempBasalDuration` events with identical timestamps
    /// (the storage layout iAPS already produces — see PumpHistoryStorage.nightscoutTretmentsNotUploaded).
    func toDoseEntries(provenance: String) -> [DoseEntry] {
        var result: [DoseEntry] = []
        var i = 0
        while i < count {
            let event = self[i]
            if event.isBolusLike {
                if let dose = event.asBolusDoseEntry(provenance: provenance) { result.append(dose) }
                i += 1
                continue
            }
            if event.type == .tempBasal, i + 1 < count, self[i + 1].type == .tempBasalDuration,
               self[i + 1].timestamp == event.timestamp
            {
                if let dose = event.asTempBasalDoseEntry(durationEvent: self[i + 1], provenance: provenance) {
                    result.append(dose)
                }
                i += 2
                continue
            }
            if let dose = event.asSuspendResumeDoseEntry() {
                result.append(dose)
                i += 1
                continue
            }
            i += 1
        }
        return result
    }

    func toPersistedPumpEvents() -> [PersistedPumpEvent] {
        compactMap { $0.asPersistedPumpEvent() }
    }
}
