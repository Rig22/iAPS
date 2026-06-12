import Foundation
import LoopKit

/// Übernimmt einen Therapy-Insights-Vorschlag ins aktive Profil.
///
/// Schreibt exakt die Dateien und nutzt exakt die Pfade der offiziellen
/// Editoren: ISF/CR werden nur in insulin_sensitivities.json bzw.
/// carb_ratios.json gespeichert (wie ISFEditor/CREditor), Basal wird wie im
/// BasalProfileEditor ERST zur Pumpe gesynct und nur bei Erfolg in
/// basal_profile.json geschrieben — die Datei darf nie von der Pumpe
/// abweichen. Aufruf nur nach expliziter Bestätigung durch den Nutzer
/// (Disclaimer-Alert in AIHubTherapyInsightsView) und nur, wenn der
/// Settings-Toggle `aiHubAllowApply` gesetzt ist.
enum AIHubTherapyApply {
    enum ApplyError: LocalizedError {
        case profileMissing

        var errorDescription: String? { hubT("ti.apply.error.profile") }
    }

    /// Completion läuft auf dem Main-Thread; nil = Erfolg.
    static func apply(_ suggestion: AIHubTherapyAnalysis.Suggestion, completion: @escaping (Error?) -> Void) {
        switch suggestion.apply {
        case let .basal(startMinute, endMinute, factor):
            applyBasal(startMinute: startMinute, endMinute: endMinute, factor: factor, completion: completion)
        case let .isf(slotStartMinute, proposed):
            finish(applyISF(slotStartMinute: slotStartMinute, proposed: proposed), completion)
        case let .cr(slotStartMinute, proposed):
            finish(applyCR(slotStartMinute: slotStartMinute, proposed: proposed), completion)
        }
    }

    private static func finish(_ error: Error?, _ completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { completion(error) }
    }

    // MARK: - ISF / CR (reine Datei-Saves, wie die Editoren)

    private static func applyISF(slotStartMinute: Int, proposed: Double) -> Error? {
        let storage = BaseFileStorage()
        guard let profile = storage.retrieve(OpenAPS.Settings.insulinSensitivities, as: InsulinSensitivities.self),
              profile.sensitivities.contains(where: { $0.offset == slotStartMinute }),
              let value = decimal(proposed, fractionDigits: profile.units == .mmolL ? 1 : 0)
        else { return ApplyError.profileMissing }

        let sensitivities = profile.sensitivities.map { entry in
            entry.offset == slotStartMinute
                ? InsulinSensitivityEntry(sensitivity: value, offset: entry.offset, start: entry.start)
                : entry
        }
        storage.save(
            InsulinSensitivities(
                units: profile.units,
                userPrefferedUnits: profile.userPrefferedUnits,
                sensitivities: sensitivities
            ),
            as: OpenAPS.Settings.insulinSensitivities
        )
        return nil
    }

    private static func applyCR(slotStartMinute: Int, proposed: Double) -> Error? {
        let storage = BaseFileStorage()
        guard let profile = storage.retrieve(OpenAPS.Settings.carbRatios, as: CarbRatios.self),
              profile.schedule.contains(where: { $0.offset == slotStartMinute }),
              let value = decimal(proposed, fractionDigits: 1)
        else { return ApplyError.profileMissing }

        let schedule = profile.schedule.map { entry in
            entry.offset == slotStartMinute
                ? CarbRatioEntry(start: entry.start, offset: entry.offset, ratio: value)
                : entry
        }
        storage.save(CarbRatios(units: profile.units, schedule: schedule), as: OpenAPS.Settings.carbRatios)
        return nil
    }

    // MARK: - Basal (Pumpen-Sync zuerst, Datei nur bei Erfolg)

    private static func applyBasal(
        startMinute: Int,
        endMinute: Int,
        factor: Double,
        completion: @escaping (Error?) -> Void
    ) {
        let storage = BaseFileStorage()
        guard let profile = storage.retrieve(OpenAPS.Settings.basalProfile, as: [BasalProfileEntry].self),
              !profile.isEmpty
        else { return finish(ApplyError.profileMissing, completion) }

        let pump = FreeAPSApp.resolver.resolve(DeviceDataManager.self)?.pumpManager
        let supportedRates = pump?.supportedBasalRates

        // Block-Grenzen einziehen und nur die Segmente im Block skalieren —
        // Raten außerhalb von [startMinute, endMinute) bleiben unangetastet.
        let sorted = profile.sorted { $0.minutes < $1.minutes }
        var pieces: [(minute: Int, rate: Decimal)] = []
        for (index, entry) in sorted.enumerated() {
            let segmentStart = entry.minutes
            let segmentEnd = index + 1 < sorted.count ? sorted[index + 1].minutes : 24 * 60
            guard segmentEnd > segmentStart else { continue }

            let scaled = scaledRate(entry.rate, factor: factor, supportedRates: supportedRates)
            // Teilstück vor dem Block
            if segmentStart < startMinute {
                pieces.append((segmentStart, entry.rate))
            }
            // Teilstück im Block
            let innerStart = max(segmentStart, startMinute)
            let innerEnd = min(segmentEnd, endMinute)
            if innerStart < innerEnd {
                pieces.append((innerStart, scaled))
            }
            // Teilstück nach dem Block
            if segmentEnd > endMinute, segmentStart < segmentEnd {
                let tailStart = max(segmentStart, endMinute)
                if tailStart < segmentEnd {
                    pieces.append((tailStart, entry.rate))
                }
            }
        }

        // Benachbarte gleiche Raten zusammenfassen
        var newProfile: [BasalProfileEntry] = []
        for piece in pieces.sorted(by: { $0.minute < $1.minute }) {
            if let last = newProfile.last, last.rate == piece.rate { continue }
            if let last = newProfile.last, last.minutes == piece.minute { newProfile.removeLast() }
            newProfile.append(BasalProfileEntry(
                start: String(format: "%02d:%02d:00", piece.minute / 60, piece.minute % 60),
                minutes: piece.minute,
                rate: piece.rate
            ))
        }
        guard let first = newProfile.first, first.minutes == 0
        else { return finish(ApplyError.profileMissing, completion) }

        // Ohne Pumpe: nur Datei (wie BasalProfileEditor.Provider.saveProfile)
        guard let pump = pump else {
            storage.save(newProfile, as: OpenAPS.Settings.basalProfile)
            return finish(nil, completion)
        }

        let concentration = CoreDataStorage().insulinConcentration().concentration
        let syncValues = newProfile.map {
            RepeatingScheduleValue(
                startTime: TimeInterval($0.minutes * 60),
                value: Double($0.rate) / concentration
            )
        }
        pump.syncBasalRateSchedule(items: syncValues) { result in
            switch result {
            case .success:
                storage.save(newProfile, as: OpenAPS.Settings.basalProfile)
                finish(nil, completion)
            case let .failure(error):
                finish(error, completion)
            }
        }
    }

    /// Skaliert eine Basalrate und rundet auf die von der Pumpe
    /// unterstützten Raten (ohne Pumpe: 0,05er-Raster wie in der Engine).
    private static func scaledRate(_ rate: Decimal, factor: Double, supportedRates: [Double]?) -> Decimal {
        let target = Double(truncating: rate as NSNumber) * factor
        if let supported = supportedRates, !supported.isEmpty {
            let nearest = supported.min { abs($0 - target) < abs($1 - target) } ?? target
            return decimal(nearest, fractionDigits: 3) ?? rate
        }
        let gridded = max(0.05, (target / 0.05).rounded() * 0.05)
        return decimal(gridded, fractionDigits: 2) ?? rate
    }

    /// Double → Decimal über String, damit keine Binär-Artefakte
    /// (0.8500000001) in den JSON-Dateien landen.
    private static func decimal(_ value: Double, fractionDigits: Int) -> Decimal? {
        Decimal(string: String(format: "%.\(fractionDigits)f", locale: Locale(identifier: "en_US_POSIX"), value))
    }
}
