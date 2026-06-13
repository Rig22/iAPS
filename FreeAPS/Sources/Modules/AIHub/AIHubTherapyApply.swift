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
///
/// Zusätzlich (Richards Test-Feedback):
/// - **Undo-Stack:** Vor jedem Schreiben wird die komplette Datei als
///   Raw-Snapshot gesichert (UserDefaults, max. 10 Einträge). „Rückgängig"
///   stellt den Snapshot verbatim wieder her — Basal inklusive Pumpen-Sync.
/// - **Cooldown:** Jede Übernahme merkt sich Ziel+Slot+Datum. Die Engine
///   unterdrückt für diesen Slot 3 Tage lang weitere Vorschläge, weil die
///   Analyse sonst auf Daten der ALTEN Einstellung dieselbe Änderung gleich
///   nochmal vorschlagen würde (Stapel-Gefahr).
enum AIHubTherapyApply {
    enum ApplyError: LocalizedError {
        case profileMissing

        var errorDescription: String? { hubT("ti.apply.error.profile") }
    }

    enum Target: String, Codable {
        case basal
        case isf
        case cr
        case preset
    }

    /// Stabiler Slot für Preset-Cooldowns (SipHash von String ist pro
    /// App-Start randomisiert — deshalb djb2 über die UTF8-Bytes).
    static func presetSlot(_ id: String) -> Int {
        var hash: UInt64 = 5381
        for byte in id.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Int(truncatingIfNeeded: hash)
    }

    // MARK: - Apply

    /// Completion läuft auf dem Main-Thread; nil = Erfolg.
    /// `summary` ist die fertig lokalisierte Kurzbeschreibung für die
    /// Undo-Zeile (z. B. „Basalrate 18:00 – 21:00: 0.60 → 0.55 U/h").
    static func apply(
        _ suggestion: AIHubTherapyAnalysis.Suggestion,
        summary: String,
        completion: @escaping (Error?) -> Void
    ) {
        switch suggestion.apply {
        case let .basal(startMinute, endMinute, factor):
            applyBasal(startMinute: startMinute, endMinute: endMinute, factor: factor, summary: summary, completion: completion)
        case let .isf(slotStartMinute, proposed):
            finish(applyISF(slotStartMinute: slotStartMinute, proposed: proposed, summary: summary), completion)
        case let .cr(slotStartMinute, proposed):
            finish(applyCR(slotStartMinute: slotStartMinute, proposed: proposed, summary: summary), completion)
        }
    }

    private static func finish(_ error: Error?, _ completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { completion(error) }
    }

    // MARK: - ISF / CR (reine Datei-Saves, wie die Editoren)

    private static func applyISF(slotStartMinute: Int, proposed: Double, summary: String) -> Error? {
        let storage = BaseFileStorage()
        guard let snapshot = storage.retrieveRaw(OpenAPS.Settings.insulinSensitivities),
              let profile = storage.retrieve(OpenAPS.Settings.insulinSensitivities, as: InsulinSensitivities.self),
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
        didApply(target: .isf, slot: slotStartMinute, snapshot: snapshot, summary: summary)
        return nil
    }

    private static func applyCR(slotStartMinute: Int, proposed: Double, summary: String) -> Error? {
        let storage = BaseFileStorage()
        guard let snapshot = storage.retrieveRaw(OpenAPS.Settings.carbRatios),
              let profile = storage.retrieve(OpenAPS.Settings.carbRatios, as: CarbRatios.self),
              profile.schedule.contains(where: { $0.offset == slotStartMinute }),
              let value = decimal(proposed, fractionDigits: 1)
        else { return ApplyError.profileMissing }

        let schedule = profile.schedule.map { entry in
            entry.offset == slotStartMinute
                ? CarbRatioEntry(start: entry.start, offset: entry.offset, ratio: value)
                : entry
        }
        storage.save(CarbRatios(units: profile.units, schedule: schedule), as: OpenAPS.Settings.carbRatios)
        didApply(target: .cr, slot: slotStartMinute, snapshot: snapshot, summary: summary)
        return nil
    }

    // MARK: - Preset-Review (OverridePresets-Row anpassen)

    /// Snapshot-Format für Preset-Undo: alte Werte + Preset-ID als JSON.
    private struct PresetSnapshot: Codable {
        let id: String
        let percentage: Double
        let duration: Double
    }

    /// Passt Prozent und/oder Dauer eines Override-Presets an (synchron,
    /// Core-Data-viewContext wie OverrideStorage). Ein laufender Override
    /// bleibt unberührt — die Aktivierung kopiert die Preset-Werte.
    static func applyPresetAdjustment(
        presetID: String,
        newPercentage: Double?,
        newDurationMinutes: Int?,
        summary: String
    ) -> Error? {
        guard let preset = OverrideStorage().fetchPreset(id: presetID) else { return ApplyError.profileMissing }

        let context = CoreDataStack.shared.persistentContainer.viewContext
        let snapshot = PresetSnapshot(
            id: presetID,
            percentage: preset.percentage,
            duration: Double(truncating: preset.duration ?? 0)
        )
        guard let snapshotData = try? JSONEncoder().encode(snapshot),
              let snapshotString = String(data: snapshotData, encoding: .utf8)
        else { return ApplyError.profileMissing }

        context.performAndWait {
            if let newPercentage = newPercentage {
                preset.percentage = newPercentage
            }
            if let newDurationMinutes = newDurationMinutes {
                preset.duration = NSDecimalNumber(value: newDurationMinutes)
            }
            try? context.save()
        }
        didApply(target: .preset, slot: presetSlot(presetID), snapshot: snapshotString, summary: summary)
        return nil
    }

    private static func undoPreset(_ record: UndoRecord) -> Error? {
        guard let data = record.snapshot.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(PresetSnapshot.self, from: data),
              let preset = OverrideStorage().fetchPreset(id: snapshot.id)
        else { return ApplyError.profileMissing }

        let context = CoreDataStack.shared.persistentContainer.viewContext
        context.performAndWait {
            preset.percentage = snapshot.percentage
            preset.duration = NSDecimalNumber(value: snapshot.duration)
            try? context.save()
        }
        return nil
    }

    // MARK: - Basal (Pumpen-Sync zuerst, Datei nur bei Erfolg)

    private static func applyBasal(
        startMinute: Int,
        endMinute: Int,
        factor: Double,
        summary: String,
        completion: @escaping (Error?) -> Void
    ) {
        let storage = BaseFileStorage()
        guard let snapshot = storage.retrieveRaw(OpenAPS.Settings.basalProfile),
              let newProfile = transformedBasalProfile(startMinute: startMinute, endMinute: endMinute, factor: factor)
        else { return finish(ApplyError.profileMissing, completion) }

        syncAndSaveBasal(newProfile) { error in
            if error == nil {
                didApply(target: .basal, slot: startMinute, snapshot: snapshot, summary: summary)
            }
            completion(error)
        }
    }

    /// Pumpen-Sync (falls Pumpe vorhanden), Datei-Save nur bei Erfolg.
    /// Completion auf Main.
    private static func syncAndSaveBasal(_ profile: [BasalProfileEntry], completion: @escaping (Error?) -> Void) {
        let storage = BaseFileStorage()

        // Ohne Pumpe: nur Datei (wie BasalProfileEditor.Provider.saveProfile)
        guard let pump = FreeAPSApp.resolver.resolve(DeviceDataManager.self)?.pumpManager else {
            storage.save(profile, as: OpenAPS.Settings.basalProfile)
            return finish(nil, completion)
        }

        let concentration = CoreDataStorage().insulinConcentration().concentration
        let syncValues = profile.map {
            RepeatingScheduleValue(
                startTime: TimeInterval($0.minutes * 60),
                value: Double($0.rate) / concentration
            )
        }
        pump.syncBasalRateSchedule(items: syncValues) { result in
            switch result {
            case .success:
                storage.save(profile, as: OpenAPS.Settings.basalProfile)
                finish(nil, completion)
            case let .failure(error):
                finish(error, completion)
            }
        }
    }

    /// Wendet den Block-Faktor auf das aktuelle Basal-Profil an: An den
    /// Blockgrenzen werden bei Bedarf neue Einträge eingezogen, nur die
    /// Segmente in [startMinute, endMinute) werden skaliert, benachbarte
    /// gleiche Raten zusammengefasst.
    private static func transformedBasalProfile(
        startMinute: Int,
        endMinute: Int,
        factor: Double
    ) -> [BasalProfileEntry]? {
        let storage = BaseFileStorage()
        guard let profile = storage.retrieve(OpenAPS.Settings.basalProfile, as: [BasalProfileEntry].self),
              !profile.isEmpty
        else { return nil }

        let supportedRates = FreeAPSApp.resolver.resolve(DeviceDataManager.self)?.pumpManager?.supportedBasalRates

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
            if segmentEnd > endMinute {
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
            newProfile.append(BasalProfileEntry(
                start: String(format: "%02d:%02d:00", piece.minute / 60, piece.minute % 60),
                minutes: piece.minute,
                rate: piece.rate
            ))
        }
        guard let first = newProfile.first, first.minutes == 0 else { return nil }
        return newProfile
    }

    // MARK: - Block-Vorschau für den Bestätigungs-Dialog

    /// Liefert pro betroffenem Basal-Segment im Block eine Zeile
    /// „18:00 – 19:00: 0.60 → 0.55 U/h" — damit im Disclaimer-Alert
    /// unmissverständlich ist, dass der GANZE Block angepasst wird,
    /// nicht nur ein einzelner Stundenwert.
    static func basalPreviewLines(startMinute: Int, endMinute: Int, factor: Double) -> [String] {
        let storage = BaseFileStorage()
        guard let profile = storage.retrieve(OpenAPS.Settings.basalProfile, as: [BasalProfileEntry].self),
              !profile.isEmpty
        else { return [] }

        let supportedRates = FreeAPSApp.resolver.resolve(DeviceDataManager.self)?.pumpManager?.supportedBasalRates

        let sorted = profile.sorted { $0.minutes < $1.minutes }
        var lines: [String] = []
        for (index, entry) in sorted.enumerated() {
            let segmentStart = entry.minutes
            let segmentEnd = index + 1 < sorted.count ? sorted[index + 1].minutes : 24 * 60
            let innerStart = max(segmentStart, startMinute)
            let innerEnd = min(segmentEnd, endMinute)
            guard innerStart < innerEnd else { continue }
            let scaled = scaledRate(entry.rate, factor: factor, supportedRates: supportedRates)
            lines.append(String(
                format: "%02d:%02d – %02d:%02d:  %.2f → %.2f U/h",
                innerStart / 60,
                innerStart % 60,
                (innerEnd / 60) % 24,
                innerEnd % 60,
                Double(truncating: entry.rate as NSNumber),
                Double(truncating: scaled as NSNumber)
            ))
        }
        return lines
    }

    // MARK: - Undo (Raw-Snapshot der Datei vor der Übernahme)

    struct UndoRecord: Codable {
        let target: Target
        let slot: Int
        let snapshot: String
        let date: Date
        let summary: String
    }

    private static let undoKey = "iAPS.aiHubApplyUndoStack"
    private static let maxUndoDepth = 10

    static var undoStack: [UndoRecord] {
        get {
            guard let data = UserDefaults.standard.data(forKey: undoKey),
                  let stack = try? JSONDecoder().decode([UndoRecord].self, from: data)
            else { return [] }
            return stack
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: undoKey)
        }
    }

    static var lastUndoRecord: UndoRecord? { undoStack.last }

    /// Macht die letzte Übernahme rückgängig: Snapshot verbatim zurück in
    /// die Datei (Basal zusätzlich zuerst zur Pumpe). Entfernt bei Erfolg
    /// auch den Cooldown des Slots, damit die Engine wieder vorschlagen darf.
    static func undoLast(completion: @escaping (Error?) -> Void) {
        guard let record = undoStack.last else { return finish(ApplyError.profileMissing, completion) }

        let done: (Error?) -> Void = { error in
            if error == nil {
                var stack = undoStack
                stack.removeLast()
                undoStack = stack
                removeCooldown(target: record.target, slot: record.slot)
            }
            completion(error)
        }

        switch record.target {
        case .basal:
            guard let data = record.snapshot.data(using: .utf8),
                  let profile = try? JSONCoding.decoder.decode([BasalProfileEntry].self, from: data),
                  !profile.isEmpty
            else { return finish(ApplyError.profileMissing, completion) }
            syncAndSaveBasal(profile) { error in done(error) }
        case .isf:
            BaseFileStorage().save(record.snapshot, as: OpenAPS.Settings.insulinSensitivities)
            finish(nil, done)
        case .cr:
            BaseFileStorage().save(record.snapshot, as: OpenAPS.Settings.carbRatios)
            finish(nil, done)
        case .preset:
            finish(undoPreset(record), done)
        }
    }

    private static func didApply(target: Target, slot: Int, snapshot: String, summary: String) {
        var stack = undoStack
        stack.append(UndoRecord(target: target, slot: slot, snapshot: snapshot, date: Date(), summary: summary))
        if stack.count > maxUndoDepth { stack.removeFirst(stack.count - maxUndoDepth) }
        undoStack = stack
        recordCooldown(target: target, slot: slot)
    }

    // MARK: - Cooldown (3 Tage Sperre pro Ziel+Slot nach Übernahme)

    private struct CooldownRecord: Codable {
        let target: Target
        let slot: Int
        let date: Date
    }

    private static let cooldownKey = "iAPS.aiHubApplyCooldowns"
    static let cooldownDays = 3

    private static var cooldowns: [CooldownRecord] {
        get {
            guard let data = UserDefaults.standard.data(forKey: cooldownKey),
                  let records = try? JSONDecoder().decode([CooldownRecord].self, from: data)
            else { return [] }
            return records
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: cooldownKey)
        }
    }

    /// Engine-Check: Wurde dieser Slot in den letzten `cooldownDays` Tagen
    /// per Übernahme geändert? Dann erst neue Daten abwarten. Räumt
    /// abgelaufene Einträge gleich mit auf.
    static func isCoolingDown(target: Target, slot: Int) -> Bool {
        let cutoff = Date().addingTimeInterval(-Double(cooldownDays) * 24 * 3600)
        let active = cooldowns.filter { $0.date > cutoff }
        if active.count != cooldowns.count { cooldowns = active }
        return active.contains { $0.target == target && $0.slot == slot }
    }

    private static func recordCooldown(target: Target, slot: Int) {
        var records = cooldowns.filter { !($0.target == target && $0.slot == slot) }
        records.append(CooldownRecord(target: target, slot: slot, date: Date()))
        cooldowns = records
    }

    private static func removeCooldown(target: Target, slot: Int) {
        cooldowns = cooldowns.filter { !($0.target == target && $0.slot == slot) }
    }

    // MARK: - Helpers

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
