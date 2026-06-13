import CoreData
import Foundation

/// Deterministisches Review der Override-Presets („Baustein A" des Preset
/// Designers): bewertet vergangene Aktivierungen rein statistisch — ohne
/// LLM, ohne API-Key, reproduzierbar.
///
/// Datengrundlage: `Override`-Rows sind das Aktivierungs-Log (jede
/// Aktivierung und jedes manuelle Beenden erzeugt eine Row). Eine Episode
/// endet mit der nächsten Row oder dem geplanten Ablauf — wer früher kommt.
/// Bewertet werden nur Presets mit mindestens `minActivations`
/// Aktivierungen (Richards Vorgabe: 5); mehrheitlich vorzeitig beendete
/// Presets gelten als „Dauer zu lang" (ebenfalls Richards Vorgabe).
enum AIHubPresetReview {
    static let minActivations = 5
    static let analysisDays = 30

    // MARK: - Modelle

    struct Recommendation: Identifiable {
        enum Adjustment {
            case percentage(Int)
            case durationMinutes(Int)
        }

        let id = UUID()
        let text: String
        let confidence: Int // 0–100
        let currentText: String
        let proposedText: String
        let adjustment: Adjustment
    }

    struct Review: Identifiable {
        let id: String // Preset-ID
        let name: String
        let emoji: String
        let activationCount: Int
        let tirDuring: Double // 0–1
        let hypoDuring: Int // Episoden mit BG < 70 währenddessen
        let hypoAfter: Int // Episoden mit BG < 70 bis +2 h nach Ende
        let earlyEndCount: Int // vorzeitig beendete Episoden
        let recommendations: [Recommendation]
    }

    struct Result {
        let reviews: [Review]
        /// Presets mit ≥ minActivations — 0 ⇒ View zeigt „noch zu wenig".
        let qualifyingCount: Int
        /// Wegen Cooldown (kürzliche Übernahme) zurückgehaltene Presets.
        let suppressedCount: Int
    }

    private struct Episode {
        let start: Date
        let end: Date
        let plannedMinutes: Int? // nil = unbegrenzt
        let earlyEnded: Bool
        var actualMinutes: Int { Int(end.timeIntervalSince(start) / 60) }
    }

    // MARK: - Analyse (synchron — Caller dispatcht off-main)

    static func analyze() -> Result {
        let context = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        let cutoff = Date().addingTimeInterval(-Double(analysisDays) * 24 * 3600)
        let now = Date()

        // (date, enabled, presetID bei Preset-Aktivierung, Dauer, unbegrenzt)
        var rows: [(date: Date, presetID: String?, durationMinutes: Int, indefinite: Bool)] = []
        var presets: [(id: String, name: String, emoji: String, percentage: Double, durationMinutes: Int, indefinite: Bool)] = []
        var readings: [(date: Date, glucose: Int)] = []

        context.performAndWait {
            let overridesReq = NSFetchRequest<Override>(entityName: "Override")
            overridesReq.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
            overridesReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            rows = ((try? context.fetch(overridesReq)) ?? []).compactMap { row in
                guard let date = row.date else { return nil }
                let presetID = (row.enabled && row.isPreset) ? row.id : nil
                return (date, presetID, Int(truncating: row.duration ?? 0), row.indefinite)
            }

            let presetsReq = NSFetchRequest<OverridePresets>(entityName: "OverridePresets")
            presets = ((try? context.fetch(presetsReq)) ?? []).compactMap { preset in
                guard let id = preset.id, let name = preset.name, !name.isEmpty else { return nil }
                return (
                    id,
                    name,
                    preset.emoji ?? "",
                    preset.percentage,
                    Int(truncating: preset.duration ?? 0),
                    preset.indefinite
                )
            }

            let readingsReq = NSFetchRequest<Readings>(entityName: "Readings")
            readingsReq.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
            readingsReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            readings = ((try? context.fetch(readingsReq)) ?? [])
                .compactMap { row in row.date.map { ($0, Int(row.glucose)) } }
        }

        // Episoden rekonstruieren: Ende = nächste Row oder geplanter Ablauf
        var episodesByPreset: [String: [Episode]] = [:]
        for (index, row) in rows.enumerated() {
            guard let presetID = row.presetID else { continue }
            let plannedEnd = row.indefinite ? nil : row.date.addingTimeInterval(Double(row.durationMinutes) * 60)
            let nextDate = index + 1 < rows.count ? rows[index + 1].date : nil

            let end: Date
            var earlyEnded = false
            switch (plannedEnd, nextDate) {
            case (nil, nil):
                continue // unbegrenzt und noch aktiv
            case let (nil, .some(next)):
                end = next
            case let (.some(planned), nil):
                end = planned
            case let (.some(planned), .some(next)):
                end = min(planned, next)
                // Richards Regel: manuell beendet = Dauer war zu lang
                earlyEnded = next < planned.addingTimeInterval(-10 * 60)
            }
            guard end <= now else { continue } // läuft noch
            guard end.timeIntervalSince(row.date) >= 15 * 60 else { continue } // Fehl-Aktivierung

            // Re-Aktivierung desselben Presets < 15 min nach Ende =
            // Verlängerung, keine neue Episode (und kein „zu lang"-Signal)
            if var existing = episodesByPreset[presetID], let last = existing.last,
               row.date.timeIntervalSince(last.end) < 15 * 60
            {
                existing[existing.count - 1] = Episode(
                    start: last.start,
                    end: end,
                    plannedMinutes: last.plannedMinutes,
                    earlyEnded: false
                )
                episodesByPreset[presetID] = existing
            } else {
                episodesByPreset[presetID, default: []].append(Episode(
                    start: row.date,
                    end: end,
                    plannedMinutes: row.indefinite ? nil : row.durationMinutes,
                    earlyEnded: earlyEnded
                ))
            }
        }

        let readingDates = readings.map(\.date)

        var reviews: [Review] = []
        var qualifying = 0
        var suppressed = 0

        for preset in presets {
            guard let episodes = episodesByPreset[preset.id], episodes.count >= minActivations else { continue }
            qualifying += 1

            if AIHubTherapyApply.isCoolingDown(target: .preset, slot: AIHubTherapyApply.presetSlot(preset.id)) {
                suppressed += 1
                continue
            }

            // Statistik über alle Episoden
            var inRange = 0
            var total = 0
            var hypoDuring = 0
            var hypoAfter = 0
            var highDuring = 0
            var earlyCount = 0
            var actualDurations: [Int] = []

            for episode in episodes {
                let during = readingsIn(from: episode.start, to: episode.end, readings, readingDates)
                total += during.count
                inRange += during.filter { $0 >= 70 && $0 <= 180 }.count
                let isHypo = during.contains { $0 < 70 }
                if isHypo { hypoDuring += 1 }
                if !during.isEmpty, !isHypo,
                   during.reduce(0, +) / during.count > 170 { highDuring += 1 }

                let after = readingsIn(
                    from: episode.end,
                    to: episode.end.addingTimeInterval(2 * 3600),
                    readings,
                    readingDates
                )
                if after.contains(where: { $0 < 70 }) { hypoAfter += 1 }

                if episode.earlyEnded {
                    earlyCount += 1
                    actualDurations.append(episode.actualMinutes)
                }
            }

            let count = episodes.count
            var recommendations: [Recommendation] = []
            let pct = Int(preset.percentage.rounded())

            // Regel 1: Hypos währenddessen → Prozent weiter senken
            if hypoDuring >= 2, hypoDuring * 2 >= count {
                let proposed = max(50, pct - 10)
                if proposed < pct {
                    recommendations.append(Recommendation(
                        text: hubT("pr.rec.lowerpct", hypoDuring, count, pct, proposed),
                        confidence: min(90, 45 + hypoDuring * 15),
                        currentText: "\(pct) %",
                        proposedText: "\(proposed) %",
                        adjustment: .percentage(proposed)
                    ))
                }
            } else if hypoDuring == 0, highDuring * 5 >= count * 3 {
                // Regel 3: konsistent erhöht ohne Hypos → Prozent anheben
                let proposed = min(150, pct + 10)
                if proposed > pct {
                    recommendations.append(Recommendation(
                        text: hubT("pr.rec.raisepct", highDuring, count, pct, proposed),
                        confidence: min(90, Int(Double(highDuring) / Double(count) * 90)),
                        currentText: "\(pct) %",
                        proposedText: "\(proposed) %",
                        adjustment: .percentage(proposed)
                    ))
                }
            }

            // Regel 2: Hypos im Nachlauf → Dauer verlängern
            // (nur zeitbegrenzte Presets)
            var durationRuleFired = false
            if !preset.indefinite, preset.durationMinutes > 0, hypoAfter >= 2, hypoAfter * 2 >= count {
                let proposed = min(1440, preset.durationMinutes + 60)
                if proposed > preset.durationMinutes {
                    durationRuleFired = true
                    recommendations.append(Recommendation(
                        text: hubT("pr.rec.longer", hypoAfter, count, preset.durationMinutes, proposed),
                        confidence: min(90, 45 + hypoAfter * 15),
                        currentText: "\(preset.durationMinutes) min",
                        proposedText: "\(proposed) min",
                        adjustment: .durationMinutes(proposed)
                    ))
                }
            }

            // Regel 4 (Richards Regel): mehrheitlich vorzeitig beendet →
            // Dauer auf die typische tatsächliche Nutzungsdauer kürzen.
            // Nur wenn Regel 2 nicht zog — beide zugleich wären widersprüchlich,
            // und Hypos schlagen Komfort.
            if !durationRuleFired, !preset.indefinite, preset.durationMinutes > 0,
               earlyCount * 2 >= count, !actualDurations.isEmpty
            {
                let median = actualDurations.sorted()[actualDurations.count / 2]
                let proposed = max(30, Int((Double(median) / 15.0).rounded()) * 15)
                if proposed < preset.durationMinutes {
                    recommendations.append(Recommendation(
                        text: hubT("pr.rec.shorter", earlyCount, count, median, preset.durationMinutes, proposed),
                        confidence: min(90, Int(Double(earlyCount) / Double(count) * 90)),
                        currentText: "\(preset.durationMinutes) min",
                        proposedText: "\(proposed) min",
                        adjustment: .durationMinutes(proposed)
                    ))
                }
            }

            guard !recommendations.isEmpty else { continue }
            reviews.append(Review(
                id: preset.id,
                name: preset.name,
                emoji: preset.emoji,
                activationCount: count,
                tirDuring: total > 0 ? Double(inRange) / Double(total) : 0,
                hypoDuring: hypoDuring,
                hypoAfter: hypoAfter,
                earlyEndCount: earlyCount,
                recommendations: Array(recommendations.sorted { $0.confidence > $1.confidence }.prefix(2))
            ))
        }

        return Result(
            reviews: reviews.sorted { ($0.recommendations.first?.confidence ?? 0) > ($1.recommendations.first?.confidence ?? 0) },
            qualifyingCount: qualifying,
            suppressedCount: suppressed
        )
    }

    // MARK: - Helpers

    private static func readingsIn(
        from start: Date,
        to end: Date,
        _ readings: [(date: Date, glucose: Int)],
        _ dates: [Date]
    ) -> [Int] {
        let lower = lowerBound(dates, start)
        let upper = lowerBound(dates, end)
        guard lower < upper else { return [] }
        return readings[lower ..< upper].map(\.glucose)
    }

    private static func lowerBound(_ dates: [Date], _ target: Date) -> Int {
        var low = 0
        var high = dates.count
        while low < high {
            let mid = (low + high) / 2
            if dates[mid] < target { low = mid + 1 } else { high = mid }
        }
        return low
    }
}
