import CoreData
import Foundation
import UserNotifications

/// „Was-wäre-wenn"-Mahlzeiten-Simulator.
///
/// Zweistufig: ein **deterministischer Bolus-Anker** (klassische Bolus-Wizard-
/// Rechnung aus dem aktiven Profil — kostenlos, reproduzierbar, offline) und
/// darauf aufbauend eine **KI-Strategie** (Timing, Splitting, Extended-Bolus,
/// Aktivität). Das LLM rechnet bewusst nicht die Zahlen — es bekommt die
/// fertigen Anker und formuliert nur die Strategie. So bleiben die Zahlen
/// vertrauenswürdig und die KI liefert den qualitativen Mehrwert.
///
/// Profilwerte (ISF/CR/Ziel/Basal) werden zur GEWÄHLTEN Tageszeit gelesen —
/// der Nutzer kann also auch ein Abendessen „durchspielen", während er
/// vormittags plant. BG/IOB/COB werden aus dem letzten Loop-Zyklus
/// vorbefüllt, sind aber frei editierbar.
enum AIHubMealSim {
    // MARK: - Modelle

    /// Aus dem aktiven Profil zur gewählten Tageszeit gelesene Rechenbasis.
    struct ProfileContext {
        let isfMgdlPerU: Double // ISF als mg/dL pro Einheit (Rechenwert)
        let crGramsPerU: Double // Kohlenhydrate pro Einheit
        let targetMgdl: Double // Ziel-BG (untere Grenze)
        let basalUPerH: Double // Basalrate zur Tageszeit
        let dia: Double // Insulinwirkdauer in Stunden
        let isMmol: Bool
    }

    /// Aktueller Zustand aus dem letzten Loop-Zyklus (Vorbelegung).
    struct LivePrefill {
        let bgMgdl: Double?
        let iob: Double?
        let cob: Double?
    }

    /// Gespeicherte Lieblingsspeise aus den AddCarbs-Presets (Rohwerte, wie in
    /// der Saved-Foods-Liste angezeigt).
    struct SavedFood: Identifiable, Hashable {
        let id: UUID
        let name: String
        let carbs: Double
        let fat: Double
        let protein: Double
        let imageURL: String?
    }

    /// Maschinenlesbarer Bolus-Plan, den die KI am Ende der Strategie ausgibt.
    /// `now` = sofort empfohlene Menge, `later`/`afterMinutes` = optionaler
    /// Split-Anteil und sein zeitlicher Abstand.
    struct BolusPlan: Equatable {
        let now: Double
        let later: Double
        let afterMinutes: Int

        var isSplit: Bool { later > 0 && afterMinutes > 0 }
        var total: Double { now + later }
    }

    /// Geplante Aktivität nach der Mahlzeit — fließt nur in die KI-Strategie,
    /// nicht in den deterministischen Anker.
    enum Activity: String, CaseIterable, Identifiable {
        case none
        case light
        case intense

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: return hubT("sim.activity.none")
            case .light: return hubT("sim.activity.light")
            case .intense: return hubT("sim.activity.intense")
            }
        }
    }

    /// Vom Nutzer eingegebene Mahlzeit (BG bereits in mg/dL normalisiert).
    struct Inputs {
        var bgMgdl: Double
        var carbs: Double
        var fat: Double
        var protein: Double
        var iob: Double
        var timeOfDay: Date
        var activity: Activity
    }

    /// Deterministisches Ergebnis der Bolus-Rechnung.
    struct Calc {
        let carbInsulin: Double
        let correctionInsulin: Double // kann negativ sein
        let iob: Double
        let recommendedBolus: Double // ≥ 0
        let profile: ProfileContext
    }

    // MARK: - Vorbelegung (synchron, off-main aufrufen)

    static func livePrefill() -> LivePrefill {
        let context = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        var prefill = LivePrefill(bgMgdl: nil, iob: nil, cob: nil)
        context.performAndWait {
            let req = NSFetchRequest<Reasons>(entityName: "Reasons")
            req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            req.fetchLimit = 1
            guard let reason = (try? context.fetch(req))?.first else { return }
            prefill = LivePrefill(
                bgMgdl: reason.glucose?.doubleValue,
                iob: reason.iob?.doubleValue,
                cob: reason.cob?.doubleValue
            )
        }
        return prefill
    }

    /// Gespeicherte Lieblingsspeisen (CoreData `Presets`). Rohwerte wie in der
    /// AddCarbs-Saved-Foods-Liste; leere/Platzhalter-Einträge gefiltert.
    static func savedFoods() -> [SavedFood] {
        let context = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        var result: [SavedFood] = []
        context.performAndWait {
            let req = NSFetchRequest<Presets>(entityName: "Presets")
            req.sortDescriptors = [NSSortDescriptor(key: "dish", ascending: true)]
            for preset in (try? context.fetch(req)) ?? [] {
                guard let dish = preset.dish, !dish.isEmpty, dish != "Empty" else { continue }
                result.append(SavedFood(
                    id: preset.foodID ?? UUID(),
                    name: dish,
                    carbs: preset.carbs?.doubleValue ?? 0,
                    fat: preset.fat?.doubleValue ?? 0,
                    protein: preset.protein?.doubleValue ?? 0,
                    imageURL: preset.imageURL
                ))
            }
        }
        return result
    }

    // MARK: - Erinnerung für den späteren Bolus-Anteil

    /// Plant eine lokale Erinnerung für den 2. Bolus-Anteil. Bewusst KEINE
    /// automatische Abgabe — die Erinnerung führt den Nutzer in den offiziellen
    /// Bolus-Screen, der den dann aktuellen BZ berücksichtigt.
    static func scheduleLaterBolusReminder(units: Double, afterMinutes: Int, isMmol _: Bool) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = hubT("sim.reminder.title")
            content.body = hubT("sim.reminder.body", String(format: "%.2f", units))
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(max(1, afterMinutes) * 60),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "iAPS.aiHubLaterBolus.\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request, withCompletionHandler: nil)
        }
    }

    // MARK: - Bolus-Plan aus der KI-Antwort

    /// Trennt die `[BOLUSPLAN]`-Zeile vom Strategietext (wie `parseReply` für
    /// `[FOLLOWUP]`). Fehlt sie, kommt der Text unverändert zurück.
    static func parseStrategy(_ raw: String) -> (text: String, plan: BolusPlan?) {
        let marker = "[BOLUSPLAN]"
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: marker, options: .backwards) else {
            return (trimmed, nil)
        }
        let text = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = String(trimmed[range.upperBound...])

        func value(_ key: String) -> Double? {
            guard let keyRange = rest.range(of: key + "=") else { return nil }
            let after = rest[keyRange.upperBound...]
            let number = after.prefix { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
            return Double(number.replacingOccurrences(of: ",", with: "."))
        }

        let now = max(0, value("now") ?? 0)
        let later = max(0, value("later") ?? 0)
        let afterMin = max(0, Int(value("afterMin") ?? 0))
        let plan = BolusPlan(now: now, later: later, afterMinutes: afterMin)
        return (text.isEmpty ? trimmed : text, plan)
    }

    // MARK: - Profil-Kontext zur Tageszeit

    /// Liest ISF/CR/Ziel/Basal/DIA zur gegebenen Tageszeit aus den aktiven
    /// Profil-Dateien. nil, wenn das Profil unvollständig ist.
    static func profileContext(at date: Date) -> ProfileContext? {
        let minute = minuteOfDay(date)
        guard let isf = isfAt(minute),
              let cr = crAt(minute),
              let basal = basalAt(minute)
        else { return nil }
        let target = targetAt(minute) ?? 100
        return ProfileContext(
            isfMgdlPerU: isf.mgdlPerU,
            crGramsPerU: cr,
            targetMgdl: target,
            basalUPerH: basal,
            dia: dia() ?? 6,
            isMmol: isf.isMmol
        )
    }

    // MARK: - Deterministische Bolus-Rechnung

    static func calculate(_ inputs: Inputs, profile: ProfileContext) -> Calc {
        let carbInsulin = profile.crGramsPerU > 0 ? inputs.carbs / profile.crGramsPerU : 0
        let correction = profile.isfMgdlPerU > 0
            ? (inputs.bgMgdl - profile.targetMgdl) / profile.isfMgdlPerU
            : 0
        let recommended = max(0, carbInsulin + correction - inputs.iob)
        return Calc(
            carbInsulin: carbInsulin,
            correctionInsulin: correction,
            iob: inputs.iob,
            recommendedBolus: (recommended * 100).rounded() / 100,
            profile: profile
        )
    }

    // MARK: - KI-Strategie-Prompt

    static func strategyPrompt(inputs: Inputs, calc: Calc) -> String {
        let profile = calc.profile
        let unit = profile.isMmol ? "mmol/L" : "mg/dL"
        let carbRule = UserDefaults.standard.aiHubCarbsComplete
            ? "The user reliably logs meals."
            : "The user does not always log meals precisely."

        let fpu = inputs.fat > 0 || inputs.protein > 0
            ? "Fat: \(fmt(inputs.fat)) g, protein: \(fmt(inputs.protein)) g — a fat/protein-rich " +
            "meal causes a delayed, prolonged glucose rise; consider an extended/split bolus."
            : "No notable fat or protein entered."

        let activityLine: String = switch inputs.activity {
        case .none: "No activity planned after the meal."
        case .light: "Light activity planned after the meal (e.g. a walk) — increases insulin " +
            "sensitivity and hypo risk for a few hours."
        case .intense: "Intense activity planned after the meal (e.g. a run or workout) — strongly " +
            "increases hypo risk; a meaningful bolus reduction and/or extra carbs may be needed."
        }

        return """
        You are the AI assistant inside iAPS, a DIY automated insulin delivery app (OpenAPS-based \
        hybrid closed loop). The user is planning a meal and wants a strategy. Glucose forecasts \
        are qualitative — you do not have a numeric simulator, so never invent exact future values.

        Answer in \(AIHubL10n.aiAnswerLanguageName). Present all glucose values in \(unit) \
        (the data below is in mg/dL; divide by 18 for mmol/L, one decimal).

        === PROFILE AT THE PLANNED TIME (\(timeLabel(inputs.timeOfDay))) ===
        ISF: \(fmt(profile.isfMgdlPerU)) mg/dL per U
        Carb ratio: \(fmt(profile.crGramsPerU)) g per U
        Target glucose: \(Int(profile.targetMgdl.rounded())) mg/dL
        Basal rate: \(fmt(profile.basalUPerH)) U/h
        Insulin duration (DIA): \(fmt(profile.dia)) h

        === CURRENT STATE ===
        Glucose: \(Int(inputs.bgMgdl.rounded())) mg/dL
        Insulin on board (IOB): \(fmt(inputs.iob)) U

        === PLANNED MEAL ===
        Carbs: \(fmt(inputs.carbs)) g
        \(fpu)
        \(activityLine)
        \(carbRule)

        === DETERMINISTIC BOLUS CALCULATION (already done — trust these numbers) ===
        Carb insulin (carbs ÷ CR): \(fmt(calc.carbInsulin)) U
        Correction ((glucose − target) ÷ ISF): \(fmt(calc.correctionInsulin)) U
        Minus IOB: −\(fmt(calc.iob)) U
        Recommended total bolus: \(fmt(calc.recommendedBolus)) U

        Write your answer as:
        - One short forecast sentence: where glucose is likely to head over the next few hours \
        with this meal and the recommended bolus (qualitative direction and rough timing of the peak, \
        no fake exact numbers).
        - Then 2 to 4 bullet points starting with "•": concrete strategy — pre-bolus timing, whether \
        to give it all upfront or split/extend it, any adjustment for the planned activity, and a \
        hypo or hyper warning if the numbers warrant one (e.g. high IOB plus correction).
        Be concise and specific. Remind the user once, briefly, that this is a suggestion and the \
        final dosing decision is theirs. No greeting, no closing line.

        Finally, on a separate very last line, output exactly this machine-readable directive \
        (the user will not see it as prose, so do not reference it in your text):
        [BOLUSPLAN] now=<units>; later=<units>; afterMin=<minutes>
        where "now" is the bolus amount in units to give immediately and, IF you recommend splitting \
        the bolus, "later" is the second portion in units and "afterMin" the minutes after the meal \
        to give it. The two should sum to the recommended total bolus (\(fmt(calc.recommendedBolus)) U). \
        If you do NOT recommend a split, use the full amount as "now" and later=0; afterMin=0.
        """
    }

    // MARK: - Profil-Parser (eigenständig, wie AIHubChatContext)

    private static func isfAt(_ minute: Int) -> (mgdlPerU: Double, isMmol: Bool)? {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.insulinSensitivities),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = object["sensitivities"] as? [[String: Any]]
        else { return nil }
        let isMmol = ((object["units"] as? String) ?? "").lowercased().contains("mmol")
        let entries = list.compactMap { entry -> (Int, Double)? in
            guard let value = (entry["sensitivity"] as? NSNumber)?.doubleValue, value > 0 else { return nil }
            let offset = (entry["offset"] as? NSNumber)?.intValue ?? 0
            return (offset, isMmol ? value * 18.0 : value)
        }.sorted { $0.0 < $1.0 }
        guard let value = valueAt(minute, entries) else { return nil }
        return (value, isMmol)
    }

    private static func crAt(_ minute: Int) -> Double? {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.carbRatios),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = object["schedule"] as? [[String: Any]]
        else { return nil }
        let entries = list.compactMap { entry -> (Int, Double)? in
            guard let ratio = (entry["ratio"] as? NSNumber)?.doubleValue, ratio > 0 else { return nil }
            let offset = (entry["offset"] as? NSNumber)?.intValue ?? 0
            return (offset, ratio)
        }.sorted { $0.0 < $1.0 }
        return valueAt(minute, entries)
    }

    private static func basalAt(_ minute: Int) -> Double? {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.basalProfile),
              let data = raw.data(using: .utf8),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        let parsed = entries.compactMap { entry -> (Int, Double)? in
            guard let rate = (entry["rate"] as? NSNumber)?.doubleValue else { return nil }
            let minutes = (entry["minutes"] as? NSNumber)?.intValue ?? 0
            return (minutes, rate)
        }.sorted { $0.0 < $1.0 }
        return valueAt(minute, parsed)
    }

    /// Ziel-BG (untere Grenze) zur Tageszeit. Werte in bg_targets.json sind in
    /// Anzeigeeinheit gespeichert → ggf. nach mg/dL umrechnen.
    private static func targetAt(_ minute: Int) -> Double? {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.bgTargets),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = object["targets"] as? [[String: Any]]
        else { return nil }
        let isMmol = ((object["units"] as? String) ?? "").lowercased().contains("mmol")
        let entries = list.compactMap { entry -> (Int, Double)? in
            guard let low = (entry["low"] as? NSNumber)?.doubleValue, low > 0 else { return nil }
            let offset = (entry["offset"] as? NSNumber)?.intValue ?? 0
            return (offset, isMmol ? low * 18.0 : low)
        }.sorted { $0.0 < $1.0 }
        return valueAt(minute, entries)
    }

    /// Insulinwirkdauer aus dem berechneten OpenAPS-Profil.
    private static func dia() -> Double? {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.profile),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dia = (object["dia"] as? NSNumber)?.doubleValue, dia > 0
        else { return nil }
        return dia
    }

    private static func valueAt(_ minute: Int, _ entries: [(Int, Double)]) -> Double? {
        guard !entries.isEmpty else { return nil }
        return entries.last(where: { $0.0 <= minute })?.1 ?? entries.first?.1
    }

    // MARK: - Helpers

    private static func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
