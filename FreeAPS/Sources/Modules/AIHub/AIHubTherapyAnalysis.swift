import CoreData
import Foundation

/// Deterministische Therapie-Analyse für den AI Hub („Therapy Insights").
///
/// Bewusst OHNE LLM: Score und Basal-Vorschläge werden lokal aus Readings,
/// Reasons und dem aktiven Profil gerechnet — kostenlos, offline,
/// reproduzierbar. Kernregel aus der wöchentlichen Analyse übernommen:
/// Hypos ohne aktives Bolus-Insulin (IOB < 1) und ohne COB sind
/// basal-getrieben → Basal senken, nicht SMB/ISF anfassen.
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
        }

        let id = UUID()
        let kind: Kind
        let startHour: Int
        let endHour: Int
        let currentRate: Double
        let proposedRate: Double
        let confidence: Int // 0–100
        let rationale: String
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
        case 90...: label = "Exzellent"
        case 75...: label = "Gut"
        case 60...: label = "Solide"
        default: label = "Verbesserungswürdig"
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

        let suggestions = basalSuggestions(
            readings: readings,
            reasons: reasons,
            days: days,
            calendar: calendar,
            isMmol: isMmol
        )

        return Result(stats: stats, suggestions: suggestions, isMmol: isMmol)
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
                    startHour: blockStart,
                    endHour: blockEnd,
                    currentRate: currentRate,
                    proposedRate: proposed,
                    confidence: confidence,
                    rationale: "Zwischen \(hh(blockStart)) und \(hh(blockEnd)) Uhr gab es " +
                        "\(blockEpisodes.count) Unterzuckerungs-Episoden, davon \(basalDrivenCount) " +
                        "ohne nennenswertes Bolus-Insulin (IOB < 1) und ohne Kohlenhydrate — das spricht " +
                        "für eine zu hohe Basalrate in diesem Zeitraum. Eine Senkung um ca. 10 % " +
                        "reduziert das Hypo-Risiko, ohne die Mahlzeiten-Abdeckung zu verändern."
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
                    startHour: blockStart,
                    endHour: blockEnd,
                    currentRate: currentRate,
                    proposedRate: proposed,
                    confidence: confidence,
                    rationale: "Zwischen \(hh(blockStart)) und \(hh(blockEnd)) Uhr lag der Mittelwert bei " +
                        "\(formatGlucose(blockMean, isMmol: isMmol)) — erhöht an \(elevatedDays) von " +
                        "\(dayMeans.count) Tagen, bei minimalem Hypo-Risiko " +
                        "(\(String(format: "%.1f", blockLowShare * 100)) % unter 70). Eine Anhebung der " +
                        "Basalrate um ca. \(pct) % kann diesen Zeitraum sicher absenken. Kleine Schritte: " +
                        "erst beobachten, dann ggf. nachjustieren."
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

    // MARK: - Basal-Profil

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

    // MARK: - Helpers

    private static func roundedRate(_ rate: Double) -> Double {
        max(0.05, (rate / 0.05).rounded() * 0.05)
    }

    private static func hh(_ hour: Int) -> String {
        String(format: "%02d:00", hour % 24)
    }

    static func formatGlucose(_ mgdl: Double, isMmol: Bool) -> String {
        isMmol ? String(format: "%.1f mmol/L", mgdl / 18.0) : "\(Int(mgdl.rounded())) mg/dL"
    }
}
