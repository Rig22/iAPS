import CoreData
import Foundation

/// Deterministische Therapie-Analyse für den AI Hub („Therapy Insights").
///
/// Bewusst OHNE LLM: Score und Vorschläge (Basal, ISF, CR) werden lokal aus
/// Readings, Reasons, Meals und dem aktiven Profil gerechnet — kostenlos,
/// offline, reproduzierbar. Kernregel aus der wöchentlichen Analyse
/// übernommen: Hypos ohne aktives Bolus-Insulin (IOB < 1) und ohne COB sind
/// basal-getrieben → Basal senken, nicht SMB/ISF anfassen. ISF wird nur aus
/// carb-freien Korrektur-Episoden bewertet, CR nur aus geloggten Mahlzeiten
/// (≥ 20 g — kleinere Mengen loggt der Nutzer erfahrungsgemäß nicht
/// zuverlässig; mit `aiHubCarbsComplete` ≥ 10 g, weil dann auch kleine
/// Mahlzeiten verlässlich erfasst sind. Das Flag gibt ISF/CR-Vorschlägen
/// außerdem einen Konfidenz-Bonus: „carb-frei" und „isolierte Mahlzeit"
/// sind dann Fakten statt Vermutungen).
enum AIHubTherapyAnalysis {
    // MARK: - Modelle

    struct Stats {
        let readingCount: Int
        let days: Int
        let meanMgdl: Double
        let tir: Double // Anteil 70–180, 0–1
        let below: Double // Anteil < 70
        let above: Double // Anteil > 180
        let cv: Double // Variationskoeffizient, 0–1

        var gmi: Double { 3.31 + 0.02392 * meanMgdl }
    }

    struct Suggestion: Identifiable {
        enum Kind {
            case basalIncrease
            case basalDecrease
            case isfRaise // ISF-Zahl anheben = schwächere Korrekturen
            case isfLower // ISF-Zahl senken = stärkere Korrekturen
            case crRaise // mehr g/U = weniger Mahlzeiten-Insulin
            case crLower // weniger g/U = mehr Mahlzeiten-Insulin
        }

        /// Maschinenlesbare Form des Vorschlags für die direkte Übernahme
        /// ins aktive Profil (AIHubTherapyApply). Werte in Profil-Einheiten,
        /// identisch gerundet zu den angezeigten Texten.
        enum ApplyPayload {
            /// Basal-Block [startMinute, endMinute) mit Faktor skalieren.
            case basal(startMinute: Int, endMinute: Int, factor: Double)
            /// ISF des Slots mit diesem Offset auf den Wert setzen.
            case isf(slotStartMinute: Int, proposed: Double)
            /// CR des Slots mit diesem Offset auf den Wert setzen.
            case cr(slotStartMinute: Int, proposed: Double)
        }

        let id = UUID()
        let kind: Kind
        /// "HH:mm – HH:mm" des Profil-Slots/Blocks; nil = ganztägig.
        let timeText: String?
        let currentText: String
        let proposedText: String
        let confidence: Int // 0–100
        let rationale: String
        let apply: ApplyPayload
    }

    struct Result {
        let stats: Stats?
        let suggestions: [Suggestion]
        let isMmol: Bool
    }

    // MARK: - Score

    /// 0–100: 50 Punkte TIR (80 % = voll), 25 Punkte Hypo-Vermeidung
    /// (≥ 5 % unter 70 = null), 25 Punkte Stabilität (CV ≤ 30 % = voll,
    /// ≥ 50 % = null).
    static func score(for stats: Stats) -> (value: Int, label: String) {
        let tirFactor = min(stats.tir / 0.80, 1.0)
        let lowFactor = max(0.0, 1.0 - stats.below / 0.05)
        let cvFactor = max(0.0, 1.0 - max(0.0, stats.cv - 0.30) / 0.20)
        let value = Int((50 * tirFactor + 25 * lowFactor + 25 * cvFactor).rounded())
        let label: String
        switch value {
        case 90...: label = hubT("ti.score.excellent")
        case 75...: label = hubT("ti.score.good")
        case 60...: label = hubT("ti.score.solid")
        default: label = hubT("ti.score.needswork")
        }
        return (value, label)
    }

    // MARK: - Analyse

    /// Synchron — Caller dispatcht off-main.
    static func analyze(days: Int) -> Result {
        let context = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let calendar = Calendar.current

        var readings: [(date: Date, glucose: Int)] = []
        var reasons: [(date: Date, iob: Double, cob: Double)] = []
        var meals: [(date: Date, carbs: Double)] = []

        context.performAndWait {
            let readingsReq = NSFetchRequest<Readings>(entityName: "Readings")
            readingsReq.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
            readingsReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            readings = ((try? context.fetch(readingsReq)) ?? [])
                .compactMap { row in row.date.map { ($0, Int(row.glucose)) } }

            let reasonsReq = NSFetchRequest<Reasons>(entityName: "Reasons")
            reasonsReq.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
            reasonsReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            reasons = ((try? context.fetch(reasonsReq)) ?? [])
                .compactMap { row in
                    row.date.map { ($0, row.iob?.doubleValue ?? 0, row.cob?.doubleValue ?? 0) }
                }

            // Meals: `date` ist beim Speichern nicht gesetzt — `actualDate`
            // ist das zuverlässige Datum. Core Data enthält nur echte
            // Einträge, keine FPU-Äquivalente.
            let mealsReq = NSFetchRequest<Meals>(entityName: "Meals")
            mealsReq.sortDescriptors = [NSSortDescriptor(key: "actualDate", ascending: true)]
            meals = ((try? context.fetch(mealsReq)) ?? [])
                .compactMap { row -> (Date, Double)? in
                    guard let date = row.actualDate ?? row.createdAt, date >= cutoff else { return nil }
                    let carbs = (row.value(forKey: "carbs") as? NSNumber)?.doubleValue ?? 0
                    return carbs > 0 ? (date, carbs) : nil
                }
                .sorted { $0.0 < $1.0 }
        }

        let isMmol = (BaseFileStorage().retrieveRaw(OpenAPS.Settings.bgTargets) ?? "")
            .lowercased().contains("mmol")

        guard readings.count >= 50 else {
            return Result(stats: nil, suggestions: [], isMmol: isMmol)
        }

        // Gesamt-Statistik
        let values = readings.map { Double($0.glucose) }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        let sd = variance.squareRoot()
        let stats = Stats(
            readingCount: readings.count,
            days: days,
            meanMgdl: mean,
            tir: Double(readings.filter { $0.glucose >= 70 && $0.glucose <= 180 }.count) / Double(readings.count),
            below: Double(readings.filter { $0.glucose < 70 }.count) / Double(readings.count),
            above: Double(readings.filter { $0.glucose > 180 }.count) / Double(readings.count),
            cv: mean > 0 ? sd / mean : 0
        )

        let basal = basalSuggestions(
            readings: readings,
            reasons: reasons,
            days: days,
            calendar: calendar,
            isMmol: isMmol
        )
        let isf = isfSuggestions(
            readings: readings,
            reasons: reasons,
            meals: meals,
            calendar: calendar,
            isMmol: isMmol
        )
        let cr = crSuggestions(
            readings: readings,
            meals: meals,
            calendar: calendar,
            isMmol: isMmol
        )

        let combined = (basal + isf + cr).sorted { $0.confidence > $1.confidence }
        return Result(stats: stats, suggestions: Array(combined.prefix(4)), isMmol: isMmol)
    }

    // MARK: - Basal-Engine

    private static let blockLength = 3 // Stunden pro Analyse-Block

    private static func basalSuggestions(
        readings: [(date: Date, glucose: Int)],
        reasons: [(date: Date, iob: Double, cob: Double)],
        days: Int,
        calendar: Calendar,
        isMmol: Bool
    ) -> [Suggestion] {
        guard let schedule = basalSchedule(), !schedule.isEmpty else { return [] }

        // Hypo-Episoden: zusammenhängende Phasen < 70, Lücken < 20 min
        var episodes: [(start: Date, basalDriven: Bool)] = []
        var episodeStart: Date?
        var lastLowDate: Date?
        for reading in readings {
            if reading.glucose < 70 {
                if let last = lastLowDate, reading.date.timeIntervalSince(last) > 20 * 60 {
                    episodeStart = nil // Lücke zu groß → neue Episode
                }
                if episodeStart == nil {
                    episodeStart = reading.date
                    episodes.append((reading.date, isBasalDriven(at: reading.date, reasons: reasons)))
                }
                lastLowDate = reading.date
            } else {
                episodeStart = nil
            }
        }

        var suggestions: [Suggestion] = []

        for blockStart in stride(from: 0, to: 24, by: blockLength) {
            let blockEnd = blockStart + blockLength
            let blockHours = blockStart ..< blockEnd
            let blockReadings = readings.filter { blockHours.contains(calendar.component(.hour, from: $0.date)) }

            // Mindestens ~50 % CGM-Abdeckung im Block
            guard blockReadings.count >= days * 12 else { continue }

            let currentRate = rate(forHour: blockStart, in: schedule)
            guard currentRate > 0 else { continue }

            let blockEpisodes = episodes.filter { blockHours.contains(calendar.component(.hour, from: $0.start)) }
            let basalDrivenCount = blockEpisodes.filter(\.basalDriven).count

            // Regel 1: wiederholte basal-getriebene Hypos → Basal senken
            if blockEpisodes.count >= 2, basalDrivenCount * 2 >= blockEpisodes.count {
                let proposed = roundedRate(currentRate * 0.90)
                guard proposed < currentRate else { continue }
                let confidence = min(90, 45 + basalDrivenCount * 15)
                suggestions.append(Suggestion(
                    kind: .basalDecrease,
                    timeText: timeRange(blockStart * 60, blockEnd * 60),
                    currentText: String(format: "%.2f U/h", currentRate),
                    proposedText: String(format: "%.2f U/h", proposed),
                    confidence: confidence,
                    rationale: hubT(
                        "ti.rationale.decrease",
                        hh(blockStart),
                        hh(blockEnd),
                        blockEpisodes.count,
                        basalDrivenCount
                    ),
                    apply: .basal(startMinute: blockStart * 60, endMinute: blockEnd * 60, factor: 0.90)
                ))
                continue
            }

            // Regel 2: konsistent erhöhter Block bei geringem Hypo-Risiko → Basal anheben
            let blockMean = Double(blockReadings.map(\.glucose).reduce(0, +)) / Double(blockReadings.count)
            let blockLowShare = Double(blockReadings.filter { $0.glucose < 70 }.count) / Double(blockReadings.count)

            var meansByDay: [Date: (sum: Int, count: Int)] = [:]
            for reading in blockReadings {
                let day = calendar.startOfDay(for: reading.date)
                let entry = meansByDay[day] ?? (0, 0)
                meansByDay[day] = (entry.sum + reading.glucose, entry.count + 1)
            }
            let dayMeans = meansByDay.values.map { Double($0.sum) / Double($0.count) }
            let elevatedDays = dayMeans.filter { $0 > 150 }.count

            if blockMean > 160, blockLowShare < 0.01, dayMeans.count >= 3,
               Double(elevatedDays) / Double(dayMeans.count) >= 0.6
            {
                let factor = blockMean > 190 ? 1.10 : 1.05
                let proposed = roundedRate(currentRate * factor)
                guard proposed > currentRate else { continue }
                let confidence = Int(Double(elevatedDays) / Double(dayMeans.count) * 90)
                let pct = Int(((factor - 1) * 100).rounded())
                suggestions.append(Suggestion(
                    kind: .basalIncrease,
                    timeText: timeRange(blockStart * 60, blockEnd * 60),
                    currentText: String(format: "%.2f U/h", currentRate),
                    proposedText: String(format: "%.2f U/h", proposed),
                    confidence: confidence,
                    rationale: hubT(
                        "ti.rationale.increase",
                        hh(blockStart),
                        hh(blockEnd),
                        formatGlucose(blockMean, isMmol: isMmol),
                        elevatedDays,
                        dayMeans.count,
                        String(format: "%.1f", blockLowShare * 100),
                        pct
                    ),
                    apply: .basal(startMinute: blockStart * 60, endMinute: blockEnd * 60, factor: factor)
                ))
            }
        }

        return Array(suggestions.sorted { $0.confidence > $1.confidence }.prefix(3))
    }

    /// Hypo ohne aktives Bolus-Insulin und ohne COB = basal-getrieben.
    /// Herangezogen wird der letzte Loop-Zyklus bis 45 min vor Episodenstart.
    private static func isBasalDriven(
        at date: Date,
        reasons: [(date: Date, iob: Double, cob: Double)]
    ) -> Bool {
        guard let reason = reasons.last(where: {
            $0.date <= date && date.timeIntervalSince($0.date) <= 45 * 60
        }) else { return false }
        return reason.iob < 1.0 && reason.cob <= 0
    }

    // MARK: - ISF-Engine

    /// Korrektur-Episoden: Loop-Zyklus mit IOB ≥ 1, COB = 0 und BG ≥ 160,
    /// die folgenden 3 h frei von COB und geloggten Carbs. Bewertet wird der
    /// tatsächliche Abfall gegen die Profil-Erwartung (IOB × ISF) sowie
    /// Hypos im 4-h-Fenster.
    private static func isfSuggestions(
        readings: [(date: Date, glucose: Int)],
        reasons: [(date: Date, iob: Double, cob: Double)],
        meals: [(date: Date, carbs: Double)],
        calendar: Calendar,
        isMmol _: Bool
    ) -> [Suggestion] {
        guard let profile = isfProfile(), !profile.entries.isEmpty else { return [] }

        let readingDates = readings.map(\.date)
        let cobDates = reasons.filter { $0.cob > 0 }.map(\.date)
        let mealDates = meals.map(\.date)

        // (Slot-Index, Hypo im Fenster, Korrektur deutlich zu schwach, End-BG)
        var episodes: [(slot: Int, isHypo: Bool, isWeak: Bool, endBG: Double)] = []
        var blockedUntil = Date.distantPast

        for reason in reasons {
            guard reason.date > blockedUntil, reason.iob >= 1.0, reason.cob <= 0 else { continue }
            guard let startBG = nearestGlucose(to: reason.date, tolerance: 10 * 60, readings, readingDates),
                  startBG >= 160 else { continue }
            let windowEnd = reason.date.addingTimeInterval(3 * 3600)

            // Kontamination: COB oder geloggte Carbs rund ums Fenster → Episode verwerfen
            guard !containsDate(cobDates, after: reason.date, until: windowEnd),
                  !containsDate(mealDates, after: reason.date.addingTimeInterval(-3600), until: windowEnd)
            else { blockedUntil = windowEnd
                continue }

            guard let endBG = nearestGlucose(to: windowEnd, tolerance: 20 * 60, readings, readingDates)
            else { blockedUntil = windowEnd
                continue }

            let minBG = minGlucose(
                from: reason.date,
                to: reason.date.addingTimeInterval(4 * 3600),
                readings,
                readingDates
            ) ?? endBG
            let slot = slotIndex(forMinute: minuteOfDay(reason.date, calendar), in: profile.entries.map(\.startMinute))
            let expectedDrop = reason.iob * profile.entries[slot].mgdlPerU
            episodes.append((
                slot: slot,
                isHypo: minBG < 70,
                isWeak: (startBG - endBG) < 0.5 * expectedDrop && endBG > 160,
                endBG: endBG
            ))
            blockedUntil = windowEnd
        }

        // Vollständiges Logging macht den Carb-frei-Filter zum Faktum
        // statt zur Vermutung → Vorschläge dürfen höher gewichtet werden.
        let carbBonus = UserDefaults.standard.aiHubCarbsComplete ? 10 : 0

        var suggestions: [Suggestion] = []
        for (index, entry) in profile.entries.enumerated() {
            let slotEpisodes = episodes.filter { $0.slot == index }
            guard slotEpisodes.count >= 4 else { continue }
            let hypoCount = slotEpisodes.filter(\.isHypo).count
            let weakCount = slotEpisodes.filter(\.isWeak).count
            let timeText = slotTimeText(profile.entries.map(\.startMinute), index)

            if hypoCount >= 2, hypoCount * 2 >= slotEpisodes.count {
                // Korrekturen enden zu oft im Unterzucker → ISF-Zahl anheben
                let proposed = roundedISF(entry.display * 1.10, isMmol: profile.isMmol)
                guard proposed > entry.display else { continue }
                suggestions.append(Suggestion(
                    kind: .isfRaise,
                    timeText: timeText,
                    currentText: formatISF(entry.display, isMmol: profile.isMmol),
                    proposedText: formatISF(proposed, isMmol: profile.isMmol),
                    confidence: min(90, 45 + hypoCount * 15 + carbBonus),
                    rationale: hubT("ti.rationale.isf.raise", hypoCount, slotEpisodes.count),
                    apply: .isf(slotStartMinute: entry.startMinute, proposed: proposed)
                ))
            } else if hypoCount == 0, weakCount * 5 >= slotEpisodes.count * 3 {
                // Korrekturen bringen konsistent weniger als die Hälfte der
                // erwarteten Senkung → ISF-Zahl senken
                let proposed = roundedISF(entry.display * 0.90, isMmol: profile.isMmol)
                guard proposed < entry.display else { continue }
                let weakMeanEnd = slotEpisodes.filter(\.isWeak).map(\.endBG).reduce(0, +) / Double(weakCount)
                suggestions.append(Suggestion(
                    kind: .isfLower,
                    timeText: timeText,
                    currentText: formatISF(entry.display, isMmol: profile.isMmol),
                    proposedText: formatISF(proposed, isMmol: profile.isMmol),
                    confidence: min(90, Int(Double(weakCount) / Double(slotEpisodes.count) * 90) + carbBonus),
                    rationale: hubT(
                        "ti.rationale.isf.lower",
                        weakCount,
                        slotEpisodes.count,
                        formatGlucose(weakMeanEnd, isMmol: profile.isMmol)
                    ),
                    apply: .isf(slotStartMinute: entry.startMinute, proposed: proposed)
                ))
            }
        }
        return suggestions
    }

    // MARK: - CR-Engine

    /// Mahlzeiten-Episoden: geloggte Mahlzeiten ≥ 20 g bzw. ≥ 10 g bei
    /// vollständigem Logging (Einträge < 90 min
    /// Abstand zusammengefasst), ohne weitere Mahlzeit im 4-h-Fenster.
    /// Bewertet wird der BG-Verlauf bis +4 h gegen den Vor-Mahlzeiten-Wert
    /// sowie Hypos bis +5 h.
    private static func crSuggestions(
        readings: [(date: Date, glucose: Int)],
        meals: [(date: Date, carbs: Double)],
        calendar: Calendar,
        isMmol: Bool
    ) -> [Suggestion] {
        guard let profile = crProfile(), !profile.isEmpty else { return [] }

        let readingDates = readings.map(\.date)

        // Einträge < 90 min Abstand zu einer Mahlzeit zusammenfassen
        var merged: [(date: Date, carbs: Double)] = []
        for meal in meals {
            if let last = merged.last, meal.date.timeIntervalSince(last.date) < 90 * 60 {
                merged[merged.count - 1].carbs += meal.carbs
            } else {
                merged.append(meal)
            }
        }

        // Bei vollständigem Logging sind auch kleine Mahlzeiten verlässlich
        // erfasst und die Fenster-Isolation ist ein Faktum → niedrigere
        // Schwelle, Konfidenz-Bonus.
        let carbsComplete = UserDefaults.standard.aiHubCarbsComplete
        let minMealCarbs: Double = carbsComplete ? 10 : 20
        let carbBonus = carbsComplete ? 10 : 0

        // (Slot-Index, Hypo bis +5 h, deutlich erhöht bei +4 h, Anstieg)
        var episodes: [(slot: Int, isHypo: Bool, isHigh: Bool, rise: Double)] = []

        for (index, meal) in merged.enumerated() where meal.carbs >= minMealCarbs {
            // Überlappung mit Nachbar-Mahlzeit → Zuordnung unklar, auslassen
            if index > 0, meal.date.timeIntervalSince(merged[index - 1].date) < 4 * 3600 { continue }
            if index + 1 < merged.count, merged[index + 1].date.timeIntervalSince(meal.date) < 4 * 3600 { continue }

            guard let preBG = nearestGlucose(to: meal.date, tolerance: 30 * 60, readings, readingDates),
                  let endBG = nearestGlucose(
                      to: meal.date.addingTimeInterval(4 * 3600),
                      tolerance: 30 * 60,
                      readings,
                      readingDates
                  )
            else { continue }
            let minBG = minGlucose(
                from: meal.date,
                to: meal.date.addingTimeInterval(5 * 3600),
                readings,
                readingDates
            ) ?? endBG
            let slot = slotIndex(forMinute: minuteOfDay(meal.date, calendar), in: profile.map(\.startMinute))
            episodes.append((
                slot: slot,
                isHypo: minBG < 70,
                isHigh: endBG - preBG > 50 && endBG > 180,
                rise: endBG - preBG
            ))
        }

        var suggestions: [Suggestion] = []
        for (index, entry) in profile.enumerated() {
            let slotEpisodes = episodes.filter { $0.slot == index }
            guard slotEpisodes.count >= 4 else { continue }
            let hypoCount = slotEpisodes.filter(\.isHypo).count
            let highCount = slotEpisodes.filter(\.isHigh).count
            let timeText = slotTimeText(profile.map(\.startMinute), index)

            if hypoCount >= 2, hypoCount * 2 >= slotEpisodes.count {
                // Nach Mahlzeiten zu oft Unterzucker → mehr Gramm pro Einheit
                let proposed = roundedCR(entry.ratio * 1.10)
                guard proposed > entry.ratio else { continue }
                suggestions.append(Suggestion(
                    kind: .crRaise,
                    timeText: timeText,
                    currentText: formatCR(entry.ratio),
                    proposedText: formatCR(proposed),
                    confidence: min(90, 45 + hypoCount * 15 + carbBonus),
                    rationale: hubT("ti.rationale.cr.raise", hypoCount, slotEpisodes.count),
                    apply: .cr(slotStartMinute: entry.startMinute, proposed: proposed)
                ))
            } else if hypoCount == 0, highCount * 5 >= slotEpisodes.count * 3 {
                // Mahlzeiten enden konsistent deutlich über dem Ausgangswert
                // → weniger Gramm pro Einheit
                let proposed = roundedCR(entry.ratio * 0.90)
                guard proposed < entry.ratio else { continue }
                let highMeanRise = slotEpisodes.filter(\.isHigh).map(\.rise).reduce(0, +) / Double(highCount)
                suggestions.append(Suggestion(
                    kind: .crLower,
                    timeText: timeText,
                    currentText: formatCR(entry.ratio),
                    proposedText: formatCR(proposed),
                    confidence: min(90, Int(Double(highCount) / Double(slotEpisodes.count) * 90) + carbBonus),
                    rationale: hubT(
                        "ti.rationale.cr.lower",
                        highCount,
                        slotEpisodes.count,
                        formatGlucose(highMeanRise, isMmol: isMmol)
                    ),
                    apply: .cr(slotStartMinute: entry.startMinute, proposed: proposed)
                ))
            }
        }
        return suggestions
    }

    // MARK: - Profil-Dateien

    /// Liest basal_profile.json: `[{"start":"00:00:00","minutes":0,"rate":0.85}, …]`
    private static func basalSchedule() -> [(startMinute: Int, rate: Double)]? {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.basalProfile),
              let data = raw.data(using: .utf8),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        return entries.compactMap { entry in
            guard let rate = (entry["rate"] as? NSNumber)?.doubleValue else { return nil }
            let minutes = (entry["minutes"] as? NSNumber)?.intValue ?? 0
            return (minutes, rate)
        }.sorted { $0.startMinute < $1.startMinute }
    }

    private static func rate(forHour hour: Int, in schedule: [(startMinute: Int, rate: Double)]) -> Double {
        schedule.last(where: { $0.startMinute <= hour * 60 })?.rate ?? schedule.first?.rate ?? 0
    }

    /// Liest insulin_sensitivities.json. `display` ist der Wert in
    /// Profil-Einheiten (so wie in den Einstellungen sichtbar),
    /// `mgdlPerU` der Rechenwert.
    private static func isfProfile() -> (entries: [(startMinute: Int, mgdlPerU: Double, display: Double)], isMmol: Bool)? {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.insulinSensitivities),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = object["sensitivities"] as? [[String: Any]]
        else { return nil }
        let isMmol = ((object["units"] as? String) ?? "").lowercased().contains("mmol")
        let entries = list.compactMap { entry -> (Int, Double, Double)? in
            guard let value = (entry["sensitivity"] as? NSNumber)?.doubleValue, value > 0 else { return nil }
            let offset = (entry["offset"] as? NSNumber)?.intValue ?? 0
            return (offset, isMmol ? value * 18.0 : value, value)
        }.sorted { $0.0 < $1.0 }
        return (entries, isMmol)
    }

    /// Liest carb_ratios.json: `{"units":"grams","schedule":[{"offset":0,"ratio":10}, …]}`
    private static func crProfile() -> [(startMinute: Int, ratio: Double)]? {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.carbRatios),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = object["schedule"] as? [[String: Any]]
        else { return nil }
        return list.compactMap { entry -> (Int, Double)? in
            guard let ratio = (entry["ratio"] as? NSNumber)?.doubleValue, ratio > 0 else { return nil }
            let offset = (entry["offset"] as? NSNumber)?.intValue ?? 0
            return (offset, ratio)
        }.sorted { $0.startMinute < $1.startMinute }
    }

    private static func slotIndex(forMinute minute: Int, in startMinutes: [Int]) -> Int {
        startMinutes.lastIndex(where: { $0 <= minute }) ?? 0
    }

    /// Zeitfenster eines Profil-Slots; nil bei nur einem Eintrag (ganztägig).
    private static func slotTimeText(_ startMinutes: [Int], _ index: Int) -> String? {
        guard startMinutes.count > 1 else { return nil }
        let end = index + 1 < startMinutes.count ? startMinutes[index + 1] : 24 * 60
        return timeRange(startMinutes[index], end)
    }

    // MARK: - Reading-Lookups (binäre Suche über sortierte Daten)

    private static func lowerBound(_ dates: [Date], _ target: Date) -> Int {
        var low = 0
        var high = dates.count
        while low < high {
            let mid = (low + high) / 2
            if dates[mid] < target { low = mid + 1 } else { high = mid }
        }
        return low
    }

    private static func containsDate(_ dates: [Date], after start: Date, until end: Date) -> Bool {
        let index = lowerBound(dates, start)
        return index < dates.count && dates[index] <= end
    }

    private static func nearestGlucose(
        to target: Date,
        tolerance: TimeInterval,
        _ readings: [(date: Date, glucose: Int)],
        _ dates: [Date]
    ) -> Double? {
        let index = lowerBound(dates, target)
        var best: (interval: TimeInterval, glucose: Int)?
        for candidate in [index - 1, index] where candidate >= 0 && candidate < readings.count {
            let interval = abs(readings[candidate].date.timeIntervalSince(target))
            if interval <= tolerance, interval < (best?.interval ?? .infinity) {
                best = (interval, readings[candidate].glucose)
            }
        }
        return best.map { Double($0.glucose) }
    }

    private static func minGlucose(
        from start: Date,
        to end: Date,
        _ readings: [(date: Date, glucose: Int)],
        _ dates: [Date]
    ) -> Double? {
        let lower = lowerBound(dates, start)
        let upper = lowerBound(dates, end)
        guard lower < upper else { return nil }
        return readings[lower ..< upper].map { Double($0.glucose) }.min()
    }

    // MARK: - Helpers

    private static func roundedRate(_ rate: Double) -> Double {
        max(0.05, (rate / 0.05).rounded() * 0.05)
    }

    private static func roundedISF(_ value: Double, isMmol: Bool) -> Double {
        isMmol ? (value * 10).rounded() / 10 : value.rounded()
    }

    private static func roundedCR(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private static func formatISF(_ value: Double, isMmol: Bool) -> String {
        isMmol ? String(format: "%.1f mmol/L/U", value) : String(format: "%.0f mg/dL/U", value)
    }

    private static func formatCR(_ value: Double) -> String {
        String(format: "%.1f g/U", value)
    }

    private static func minuteOfDay(_ date: Date, _ calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func timeRange(_ startMinute: Int, _ endMinute: Int) -> String {
        String(
            format: "%02d:%02d – %02d:%02d",
            startMinute / 60,
            startMinute % 60,
            (endMinute / 60) % 24,
            endMinute % 60
        )
    }

    private static func hh(_ hour: Int) -> String {
        String(format: "%02d:00", hour % 24)
    }

    static func formatGlucose(_ mgdl: Double, isMmol: Bool) -> String {
        isMmol ? String(format: "%.1f mmol/L", mgdl / 18.0) : "\(Int(mgdl.rounded())) mg/dL"
    }
}
