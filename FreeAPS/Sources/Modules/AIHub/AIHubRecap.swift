import CoreData
import Foundation

/// Recap-Engine: deterministischer Perioden-Vergleich (Woche/Monat vs.
/// Vorperiode) plus Prompt-Builder für optionale KI-Beobachtungen.
///
/// Die Zahlen kommen komplett lokal aus CoreData — das LLM formuliert nur
/// den Beobachtungstext und wird pro Tag/Periode gecacht, damit erneutes
/// Öffnen nichts kostet.
enum AIHubRecap {
    // MARK: - Modelle

    struct PeriodStats {
        let readingCount: Int
        let meanMgdl: Double
        let tir: Double // 70–180, 0–1
        let below: Double
        let cv: Double
        let hypoEpisodes: Int
        let tddMean: Double // U/Tag, 0 wenn unbekannt
        let loggedCarbsPerDay: Double
    }

    struct Summary {
        let days: Int
        let current: PeriodStats?
        let previous: PeriodStats?
        let bestBlockText: String?
        let worstBlockText: String?
        let isMmol: Bool
    }

    // MARK: - Berechnung (synchron, off-main aufrufen)

    static func compute(days: Int) -> Summary {
        let context = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        let now = Date()
        let splitDate = now.addingTimeInterval(-Double(days) * 24 * 3600)
        let cutoff = now.addingTimeInterval(-Double(days) * 2 * 24 * 3600)
        let calendar = Calendar.current

        var readings: [(date: Date, glucose: Int)] = []
        var tdds: [(date: Date, tdd: Double)] = []
        var carbs: [(date: Date, grams: Double)] = []

        context.performAndWait {
            let readingsReq = NSFetchRequest<Readings>(entityName: "Readings")
            readingsReq.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
            readingsReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            readings = ((try? context.fetch(readingsReq)) ?? [])
                .compactMap { row in row.date.map { ($0, Int(row.glucose)) } }

            let reasonsReq = NSFetchRequest<Reasons>(entityName: "Reasons")
            reasonsReq.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
            reasonsReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            tdds = ((try? context.fetch(reasonsReq)) ?? [])
                .compactMap { row in
                    guard let date = row.date, let tdd = row.tdd?.doubleValue, tdd > 0 else { return nil }
                    return (date, tdd)
                }

            let mealsReq = NSFetchRequest<Meals>(entityName: "Meals")
            mealsReq.sortDescriptors = [NSSortDescriptor(key: "actualDate", ascending: true)]
            carbs = ((try? context.fetch(mealsReq)) ?? [])
                .compactMap { row in
                    guard let date = row.actualDate ?? row.createdAt, date >= cutoff,
                          let grams = (row.value(forKey: "carbs") as? NSNumber)?.doubleValue, grams > 0
                    else { return nil }
                    return (date, grams)
                }
        }

        let isMmol = (BaseFileStorage().retrieveRaw(OpenAPS.Settings.bgTargets) ?? "")
            .lowercased().contains("mmol")

        let currentReadings = readings.filter { $0.date >= splitDate }
        let previousReadings = readings.filter { $0.date < splitDate }

        let current = periodStats(
            readings: currentReadings,
            tdds: tdds.filter { $0.date >= splitDate },
            carbs: carbs.filter { $0.date >= splitDate },
            days: days,
            calendar: calendar
        )
        let previous = periodStats(
            readings: previousReadings,
            tdds: tdds.filter { $0.date < splitDate },
            carbs: carbs.filter { $0.date < splitDate },
            days: days,
            calendar: calendar
        )

        let (best, worst) = blockHighlights(readings: currentReadings, calendar: calendar, isMmol: isMmol)

        return Summary(
            days: days,
            current: current,
            previous: previous,
            bestBlockText: best,
            worstBlockText: worst,
            isMmol: isMmol
        )
    }

    private static func periodStats(
        readings: [(date: Date, glucose: Int)],
        tdds: [(date: Date, tdd: Double)],
        carbs: [(date: Date, grams: Double)],
        days: Int,
        calendar: Calendar
    ) -> PeriodStats? {
        guard readings.count >= 50 else { return nil }
        let values = readings.map { Double($0.glucose) }
        let mean = values.reduce(0, +) / Double(values.count)
        let sd = (values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)).squareRoot()

        // Hypo-Episoden: zusammenhängende Phasen < 70, Lücken < 20 min
        var episodes = 0
        var inEpisode = false
        var lastLowDate: Date?
        for reading in readings {
            if reading.glucose < 70 {
                if let last = lastLowDate, reading.date.timeIntervalSince(last) > 20 * 60 {
                    inEpisode = false
                }
                if !inEpisode {
                    episodes += 1
                    inEpisode = true
                }
                lastLowDate = reading.date
            } else {
                inEpisode = false
            }
        }

        // TDD: letzter Wert pro Tag (rollierender 24h-Wert), darüber gemittelt
        var tddByDay: [Date: Double] = [:]
        for entry in tdds {
            tddByDay[calendar.startOfDay(for: entry.date)] = entry.tdd
        }
        let tddMean = tddByDay.isEmpty ? 0 : tddByDay.values.reduce(0, +) / Double(tddByDay.count)

        return PeriodStats(
            readingCount: readings.count,
            meanMgdl: mean,
            tir: Double(readings.filter { $0.glucose >= 70 && $0.glucose <= 180 }.count) / Double(values.count),
            below: Double(readings.filter { $0.glucose < 70 }.count) / Double(values.count),
            cv: mean > 0 ? sd / mean : 0,
            hypoEpisodes: episodes,
            tddMean: tddMean,
            loggedCarbsPerDay: carbs.map(\.grams).reduce(0, +) / Double(days)
        )
    }

    /// Bester/schwierigster 3h-Block der aktuellen Periode.
    private static func blockHighlights(
        readings: [(date: Date, glucose: Int)],
        calendar: Calendar,
        isMmol: Bool
    ) -> (best: String?, worst: String?) {
        var blocks: [(start: Int, inRange: Double, mean: Double)] = []
        for blockStart in stride(from: 0, to: 24, by: 3) {
            let hours = blockStart ..< (blockStart + 3)
            let blockValues = readings
                .filter { hours.contains(calendar.component(.hour, from: $0.date)) }
                .map(\.glucose)
            guard blockValues.count >= 20 else { continue }
            blocks.append((
                blockStart,
                Double(blockValues.filter { $0 >= 70 && $0 <= 180 }.count) / Double(blockValues.count),
                Double(blockValues.reduce(0, +)) / Double(blockValues.count)
            ))
        }
        guard blocks.count >= 2 else { return (nil, nil) }

        func label(_ block: (start: Int, inRange: Double, mean: Double), prefix: String) -> String {
            let range = String(format: "%02d–%02d Uhr", block.start, (block.start + 3) % 24)
            let tir = String(format: "%.0f %% TIR", block.inRange * 100)
            return "\(prefix) \(range) (\(tir), Mittel \(AIHubTherapyAnalysis.formatGlucose(block.mean, isMmol: isMmol)))"
        }

        let best = blocks.max { $0.inRange < $1.inRange }.map { label($0, prefix: "Stärkste Zeit:") }
        let worst = blocks.min { $0.inRange < $1.inRange }.map { label($0, prefix: "Schwierigste Zeit:") }
        return (best, worst)
    }

    // MARK: - KI-Beobachtungen

    static func narrativePrompt(for summary: Summary) -> String {
        var lines: [String] = []
        lines.append(
            """
            You are the AI assistant inside iAPS (DIY closed-loop insulin app). Write a short \
            "\(summary.days == 7 ? "weekly" : "monthly")" recap of the user's glucose data IN GERMAN.

            Rules:
            - Exactly 3 to 4 observations as bullet points starting with "•", each 1–2 sentences.
            - Use concrete numbers from the data; compare with the previous period where notable.
            - Friendly, encouraging tone. Observations, not instructions — at most a gentle hint \
            what could be worth watching.
            - Glucose values in the data are mg/dL; present them in \(summary
                .isMmol ? "mmol/L (divide by 18, one decimal)" : "mg/dL").
            - Logged carbs are incomplete (the user does not log every meal) — never interpret \
            low carb totals as fasting.
            - No greeting, no closing line, only the bullet points.
            """
        )
        lines.append("=== DATA ===")
        if let current = summary.current {
            lines.append("Current period (\(summary.days) days): " + describe(current))
        }
        if let previous = summary.previous {
            lines.append("Previous period (\(summary.days) days before that): " + describe(previous))
        }
        if let best = summary.bestBlockText { lines.append(best) }
        if let worst = summary.worstBlockText { lines.append(worst) }
        return lines.joined(separator: "\n")
    }

    private static func describe(_ stats: PeriodStats) -> String {
        String(
            format: "mean %.0f mg/dL, TIR 70-180 %.1f%%, below 70 %.1f%%, CV %.0f%%, " +
                "hypo episodes %d, mean TDD %.1f U, logged carbs %.0f g/day",
            stats.meanMgdl,
            stats.tir * 100,
            stats.below * 100,
            stats.cv * 100,
            stats.hypoEpisodes,
            stats.tddMean,
            stats.loggedCarbsPerDay
        )
    }

    // MARK: - Narrative-Cache (pro Tag und Periode, damit erneutes Öffnen nichts kostet)

    private static func cacheKey(days: Int) -> String { "iAPS.aiHubRecapText.\(days)" }
    private static func cacheDateKey(days: Int) -> String { "iAPS.aiHubRecapDate.\(days)" }

    static func cachedNarrative(days: Int) -> String? {
        guard let date = UserDefaults.standard.object(forKey: cacheDateKey(days: days)) as? Date,
              Calendar.current.isDateInToday(date)
        else { return nil }
        return UserDefaults.standard.string(forKey: cacheKey(days: days))
    }

    static func storeNarrative(_ text: String, days: Int) {
        UserDefaults.standard.set(text, forKey: cacheKey(days: days))
        UserDefaults.standard.set(Date(), forKey: cacheDateKey(days: days))
    }
}
