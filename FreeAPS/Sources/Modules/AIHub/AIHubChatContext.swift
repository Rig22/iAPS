import CoreData
import Foundation

/// Baut den kompakten Daten-Kontext für den AI-Hub-Chat.
///
/// Bewusst NICHT `InsightsExportLite` wiederverwendet: der Export liefert
/// 90 Tage Rohdaten (mehrere MB) — viel zu groß für einen Prompt. Hier
/// werden dieselben Quellen (Readings, Reasons, Meals, FileStorage-Profil)
/// zu wenigen KB aggregiert: Profil-Schedules roh, Glukose als Stunden-
/// Mittelwerte, aktueller Loop-State aus dem letzten Reason-Eintrag.
enum AIHubChatContext {
    /// Synchron — Caller muss off-main dispatchen.
    static func build() -> String {
        let context = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        let now = Date()
        let cutoff7d = now.addingTimeInterval(-7 * 24 * 3600)
        let cutoff24h = now.addingTimeInterval(-24 * 3600)

        var readings: [(date: Date, glucose: Int)] = []
        var lastReason: Reasons?
        var carbsByDay: [Date: Decimal] = [:]

        context.performAndWait {
            let readingsReq = NSFetchRequest<Readings>(entityName: "Readings")
            readingsReq.predicate = NSPredicate(format: "date >= %@", cutoff7d as NSDate)
            readingsReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            readings = ((try? context.fetch(readingsReq)) ?? [])
                .compactMap { row in row.date.map { ($0, Int(row.glucose)) } }

            let reasonReq = NSFetchRequest<Reasons>(entityName: "Reasons")
            reasonReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            reasonReq.fetchLimit = 1
            lastReason = (try? context.fetch(reasonReq))?.first

            // Meals: `date` ist beim Speichern nicht gesetzt — `actualDate`
            // ist das zuverlässige Datum (siehe InsightsExportLite).
            let mealsReq = NSFetchRequest<Meals>(entityName: "Meals")
            mealsReq.sortDescriptors = [NSSortDescriptor(key: "actualDate", ascending: true)]
            let meals = (try? context.fetch(mealsReq)) ?? []
            let calendar = Calendar.current
            for meal in meals {
                guard let date = meal.actualDate ?? meal.createdAt, date >= cutoff7d else { continue }
                guard let carbs = (meal.value(forKey: "carbs") as? NSNumber)?.decimalValue, carbs > 0 else { continue }
                let day = calendar.startOfDay(for: date)
                carbsByDay[day, default: 0] += carbs
            }
        }

        var sections: [String] = []
        sections.append("Exported at: \(iso(now))")
        sections.append(unitsSection())
        sections.append(profileSection())
        if let reason = lastReason {
            sections.append(loopStateSection(reason))
        }
        sections.append(glucoseSection(title: "Glucose last 24h", readings: readings.filter { $0.date >= cutoff24h }))
        sections.append(glucoseSection(title: "Glucose last 7 days", readings: readings))
        sections.append(carbsSection(carbsByDay))
        return sections.joined(separator: "\n\n")
    }

    // MARK: - Starter-Vorschläge

    /// Statische Defaults, bis die datengetriebenen Vorschläge geladen sind.
    static let fallbackStarters = [
        "Wie sind meine Nacht-Einstellungen?",
        "Wo war ich diese Woche zu oft niedrig?",
        "Passt mein Basal am Morgen?"
    ]

    private static let starterPool = [
        "Wie sind meine Nacht-Einstellungen?",
        "Wo war ich diese Woche zu oft niedrig?",
        "Passt mein Basal am Morgen?",
        "Wie war meine letzte Woche insgesamt?",
        "Welche Tageszeit läuft bei mir am schlechtesten?",
        "Passt mein ISF zu meinen Korrekturen?",
        "Wie stabil sind meine Nächte im Vergleich zum Tag?",
        "Was waren diese Woche meine höchsten Werte?"
    ]

    /// Datengetriebene Starter-Fragen für den leeren Chat: schaut auf die
    /// letzten 7 Tage und schlägt vor, was tatsächlich auffällig ist.
    /// Aufgefüllt wird aus dem Pool. Synchron — Caller dispatcht off-main.
    static func starterSuggestions() -> [String] {
        let context = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)

        var readings: [(hour: Int, glucose: Int)] = []
        context.performAndWait {
            let req = NSFetchRequest<Readings>(entityName: "Readings")
            req.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
            let calendar = Calendar.current
            readings = ((try? context.fetch(req)) ?? [])
                .compactMap { row in
                    row.date.map { (calendar.component(.hour, from: $0), Int(row.glucose)) }
                }
        }

        var suggestions: [String] = []

        // Mindestens ~½ Tag CGM-Daten, sonst nur Pool
        if readings.count >= 100 {
            // Hypo-Häufung nach Tagesabschnitt (≥ 6 Readings ≈ ½ Stunde)
            let dayparts: [(name: String, range: Range<Int>)] = [
                ("nachts", 0 ..< 6),
                ("vormittags", 6 ..< 12),
                ("nachmittags", 12 ..< 18),
                ("abends", 18 ..< 24)
            ]
            let lows = readings.filter { $0.glucose < 70 }
            if let worst = dayparts
                .map({ part in (part.name, lows.filter { part.range.contains($0.hour) }.count) })
                .max(by: { $0.1 < $1.1 }), worst.1 >= 6
            {
                suggestions.append("Warum war ich diese Woche \(worst.0) öfter niedrig?")
            }

            // Erhöhte Nächte
            let nightValues = readings.filter { $0.hour < 6 }.map(\.glucose)
            if !nightValues.isEmpty, nightValues.reduce(0, +) / nightValues.count > 150 {
                suggestions.append("Warum bin ich nachts zu hoch?")
            }

            // TIR unter Ziel
            let inRange = readings.filter { $0.glucose >= 70 && $0.glucose <= 180 }.count
            if Double(inRange) / Double(readings.count) < 0.7 {
                suggestions.append("Wie kann ich meine Time in Range verbessern?")
            }

            // Viel Zeit über Range
            let high = readings.filter { $0.glucose > 180 }.count
            if Double(high) / Double(readings.count) > 0.25 {
                suggestions.append("Zu welcher Tageszeit bin ich am häufigsten zu hoch?")
            }
        }

        for question in starterPool.shuffled() where suggestions.count < 3 {
            if !suggestions.contains(question) {
                suggestions.append(question)
            }
        }
        return Array(suggestions.prefix(3))
    }

    // MARK: - Sections

    private static func unitsSection() -> String {
        let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.bgTargets) ?? ""
        let isMmol = raw.lowercased().contains("mmol")
        return "User glucose display unit: \(isMmol ? "mmol/L" : "mg/dL")"
    }

    private static func profileSection() -> String {
        let storage = BaseFileStorage()
        var lines = ["Active profile (raw schedule JSON, times are local):"]
        let files: [(String, String)] = [
            ("Basal rates", OpenAPS.Settings.basalProfile),
            ("ISF (insulin sensitivity)", OpenAPS.Settings.insulinSensitivities),
            ("CR (carb ratios)", OpenAPS.Settings.carbRatios),
            ("BG targets", OpenAPS.Settings.bgTargets)
        ]
        for (label, file) in files {
            if let raw = storage.retrieveRaw(file) {
                lines.append("\(label): \(compactJSON(raw))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func loopStateSection(_ reason: Reasons) -> String {
        var lines = ["Current loop state (latest loop cycle):"]
        if let date = reason.date { lines.append("time: \(iso(date))") }
        let fields: [(String, NSDecimalNumber?)] = [
            ("glucose (mg/dL)", reason.glucose),
            ("IOB (U)", reason.iob),
            ("COB (g)", reason.cob),
            ("ISF", reason.isf),
            ("CR", reason.cr),
            ("target (mg/dL)", reason.target),
            ("temp basal rate (U/h)", reason.rate),
            ("autosens ratio", reason.ratio),
            ("TDD (U)", reason.tdd)
        ]
        for (label, value) in fields {
            if let value = value { lines.append("\(label): \(value)") }
        }
        return lines.joined(separator: "\n")
    }

    private static func glucoseSection(title: String, readings: [(date: Date, glucose: Int)]) -> String {
        guard !readings.isEmpty else { return "\(title): no data" }
        let values = readings.map(\.glucose)
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let inRange = values.filter { $0 >= 70 && $0 <= 180 }.count
        let low = values.filter { $0 < 70 }.count
        let high = values.filter { $0 > 180 }.count
        func pct(_ n: Int) -> String { String(format: "%.1f%%", Double(n) / Double(values.count) * 100) }

        // Stunden-Mittelwerte (lokale Zeit) — das Kernstück für Fragen wie
        // „Wie sind meine Nacht-Einstellungen?"
        let calendar = Calendar.current
        var buckets: [[Int]] = Array(repeating: [], count: 24)
        for reading in readings {
            buckets[calendar.component(.hour, from: reading.date)].append(reading.glucose)
        }
        let hourly = (0 ..< 24).map { hour -> String in
            let bucket = buckets[hour]
            guard !bucket.isEmpty else { return String(format: "%02d:00 -", hour) }
            let avg = bucket.reduce(0, +) / bucket.count
            return String(format: "%02d:00 %d", hour, avg)
        }

        return """
        \(title) (\(values.count) readings, mg/dL):
        mean: \(Int(mean.rounded())), time in range 70-180: \(pct(inRange)), below 70: \(pct(low)), above 180: \(pct(high))
        hourly means (local time):
        \(hourly.joined(separator: ", "))
        """
    }

    private static func carbsSection(_ carbsByDay: [Date: Decimal]) -> String {
        guard !carbsByDay.isEmpty else {
            return "Logged carbs last 7 days: none. Note: the user does not log every meal — "
                + "absence of carb entries does not mean no food was eaten."
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let lines = carbsByDay.keys.sorted().map { day in
            "\(formatter.string(from: day)): \(carbsByDay[day] ?? 0) g"
        }
        return """
        Logged carbs per day, last 7 days (entries may be incomplete — the user does not log every meal):
        \(lines.joined(separator: ", "))
        """
    }

    // MARK: - Helpers

    private static func compactJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let compact = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: compact, encoding: .utf8)
        else { return raw.replacingOccurrences(of: "\n", with: " ") }
        return string
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
