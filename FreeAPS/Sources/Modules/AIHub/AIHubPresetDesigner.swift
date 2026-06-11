import CoreData
import Foundation

/// KI-Preset-Designer: entwirft aus einer Situationsbeschreibung (Sport,
/// Krankheit, Reise …) einen Override-Preset-Vorschlag auf Basis der echten
/// Therapie-Daten. Der Vorschlag wird nur ERSTELLT, nie aktiviert — die
/// Übernahme ist immer eine bewusste Entscheidung des Nutzers, und alle
/// Werte werden engine-seitig auf sichere Bereiche geklemmt.
enum AIHubPresetDesigner {
    // MARK: - Vorschlag

    struct Proposal: Equatable {
        var name: String
        var emoji: String
        /// Skaliert Basal, ISF und CR gemeinsam (isfAndCr=true, wie der
        /// einfache Modus im Override-Editor).
        var percentage: Double
        /// mg/dl; nil = Profil-Target behalten.
        var targetMgdl: Double?
        var durationMinutes: Int
        var indefinite: Bool
        var smbOff: Bool
    }

    // Sicherheits-Klemmen — unabhängig davon, was das Modell liefert.
    private static let percentageRange = 50.0 ... 150.0
    private static let targetRange = 80.0 ... 200.0
    private static let durationRange = 15 ... 1440

    // MARK: - Prompt

    /// Synchron (CoreData- und FileStorage-Zugriffe) — Caller dispatcht off-main.
    static func buildPrompt(situation: String) -> String {
        // Gleiche Sprachregel wie der Chat: explizite Wahl gewinnt immer.
        let languageRule = UserDefaults.standard.userPreferredLanguageForAI != nil
            ? "- Always answer in \(AIHubL10n.aiAnswerLanguageName), regardless of the " +
            "language the situation is written in."
            : "- Answer in \(AIHubL10n.aiAnswerLanguageName) unless the situation is " +
            "clearly written in a different language — then follow the user."

        var lines: [String] = []
        lines.append(
            """
            You are the AI assistant inside iAPS (DIY closed-loop insulin app). Design ONE \
            override preset for the situation the user describes, grounded in the user's \
            own therapy data below.

            How presets work in iAPS:
            - "percentage" scales basal rate, ISF and carb ratio together (100 = no change; \
            below 100 = less insulin overall, above 100 = more).
            - "target" optionally overrides the glucose target in mg/dL while the preset is active.
            - "duration" is how long the preset runs after the user activates it, in minutes; \
            "indefinite" runs until cancelled.
            - "smbOff" disables SMB micro-boluses while active (often sensible during exercise).

            Rules:
            \(languageRule)
            - 2 to 4 sentences explaining the proposal, citing the user's data where relevant \
            (hypo pattern, time of day, TDD). No greeting, no markdown headings.
            - Be conservative: prefer the smallest change that plausibly works. Exercise \
            usually means percentage 60-85, a raised target (130-160 mg/dL) and smbOff=true. \
            Illness/fever usually means percentage 110-130, profile target kept, smbOff=false. \
            When unsure, stay closer to 100.
            - percentage must be an integer between 50 and 150. target must be an integer \
            between 80 and 200 mg/dL, or "none" to keep the profile target. duration must be \
            an integer between 15 and 1440 minutes, or "indefinite".
            - If the user already has a similar preset (list below), align with what \
            apparently works for them and say so.
            - This is a starting point the user will observe and refine — say that briefly.
            - End your reply with exactly one line in this format (plain text, no markdown):
            [PRESET] name=<short name, max 20 chars>; emoji=<one emoji>; percentage=<int>; \
            target=<int or none>; duration=<int or indefinite>; smbOff=<true or false>
            """
        )
        lines.append("=== USER DATA ===")
        lines.append(AIHubChatContext.build())
        lines.append("=== EXISTING PRESETS ===")
        lines.append(existingPresetsSection())
        lines.append("=== SITUATION ===")
        lines.append(situation)
        return lines.joined(separator: "\n\n")
    }

    /// Bestehende Presets als kompakte Referenz — das Modell soll sich an
    /// dem orientieren, was beim Nutzer offenbar funktioniert.
    private static func existingPresetsSection() -> String {
        let presets = OverrideStorage().fetchProfiles()
        guard !presets.isEmpty else { return "The user has no presets yet." }
        let lines = presets.compactMap { preset -> String? in
            guard let name = preset.name, !name.isEmpty else { return nil }
            var parts = ["\(name): percentage \(Int(preset.percentage))"]
            let target = (preset.target as Decimal?) ?? 0
            if target > 6 {
                parts.append("target \(target) mg/dL")
            }
            if preset.indefinite {
                parts.append("indefinite")
            } else if let duration = preset.duration as Decimal?, duration > 0 {
                parts.append("duration \(duration) min")
            }
            if preset.smbIsOff { parts.append("SMB off") }
            return "- " + parts.joined(separator: ", ")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Parser

    /// Trennt die `[PRESET]`-Zeile von der Erklärung. Tolerant: fehlende
    /// oder kaputte Felder führen zu nil-Proposal, der Text bleibt nutzbar.
    static func parseReply(_ reply: String) -> (text: String, proposal: Proposal?) {
        let lines = reply.components(separatedBy: .newlines)
        guard let index = lines.lastIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("[PRESET]")
        }) else {
            return (reply.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        let text = lines[..<index].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let presetLine = lines[index].trimmingCharacters(in: .whitespaces)
            .dropFirst("[PRESET]".count)

        var fields: [String: String] = [:]
        for pair in presetLine.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            fields[kv[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                kv[1].trimmingCharacters(in: .whitespaces)
        }

        guard let percentageRaw = fields["percentage"], let percentage = number(from: percentageRaw)
        else { return (text, nil) }

        var name = fields["name"] ?? ""
        if name.isEmpty { name = "AI Preset" }
        if name.count > 25 { name = String(name.prefix(25)) }

        // Erstes Grapheme nehmen; ASCII (z. B. versehentlicher Text) verwerfen.
        var emoji = fields["emoji"].flatMap { $0.first.map(String.init) } ?? ""
        if emoji.isEmpty || emoji.unicodeScalars.allSatisfy(\.isASCII) { emoji = "✨" }

        var targetMgdl: Double?
        if let targetRaw = fields["target"]?.lowercased(), targetRaw != "none", !targetRaw.isEmpty,
           let target = number(from: targetRaw)
        {
            targetMgdl = min(max(target, targetRange.lowerBound), targetRange.upperBound)
        }

        var indefinite = false
        var durationMinutes = 120
        if let durationRaw = fields["duration"]?.lowercased() {
            if durationRaw.hasPrefix("indef") {
                indefinite = true
                durationMinutes = 0
            } else if let duration = number(from: durationRaw) {
                durationMinutes = min(max(Int(duration), durationRange.lowerBound), durationRange.upperBound)
            }
        }

        let smbOff = ["true", "yes", "1"].contains(fields["smboff"]?.lowercased() ?? "false")

        let proposal = Proposal(
            name: name,
            emoji: emoji,
            percentage: min(max(percentage, percentageRange.lowerBound), percentageRange.upperBound).rounded(),
            targetMgdl: targetMgdl,
            durationMinutes: durationMinutes,
            indefinite: indefinite,
            smbOff: smbOff
        )
        return (text, proposal)
    }

    /// Zahl aus String, tolerant gegen Einheiten-Anhängsel ("70%", "140 mg/dl").
    private static func number(from raw: String) -> Double? {
        let cleaned = raw.prefix { "0123456789.".contains($0) }
        return Double(cleaned)
    }

    // MARK: - Speichern

    /// Legt das Preset an — exakt die Semantik von
    /// `OverrideProfilesConfig.StateModel.savePreset()`: Target in mg/dl mit
    /// Sentinel 6 für „kein Target-Override", einfacher Modus ohne
    /// advancedSettings (Prozent wirkt auf Basal+ISF+CR), kein autoISF.
    static func save(_ proposal: Proposal, completion: @escaping () -> Void) {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        context.perform {
            let preset = OverridePresets(context: context)
            preset.id = UUID().uuidString
            preset.date = Date()
            preset.name = proposal.name
            preset.emoji = proposal.emoji
            preset.percentage = proposal.percentage
            preset.duration = NSDecimalNumber(value: proposal.indefinite ? 0 : proposal.durationMinutes)
            preset.indefinite = proposal.indefinite
            preset.smbIsOff = proposal.smbOff
            preset.target = NSDecimalNumber(value: proposal.targetMgdl ?? 6)
            preset.advancedSettings = false
            preset.isfAndCr = true
            preset.isf = true
            preset.cr = true
            preset.basal = true
            preset.overrideAutoISF = false
            preset.overrideMaxIOB = false
            preset.maxIOB = 0
            preset.smbMinutes = NSDecimalNumber(value: preferenceMinutes(key: "maxSMBBasalMinutes"))
            preset.uamMinutes = NSDecimalNumber(value: preferenceMinutes(key: "maxUAMSMBBasalMinutes"))
            preset.endWIthNewCarbs = false
            try? context.save()
            DispatchQueue.main.async(execute: completion)
        }
    }

    /// SMB/UAM-Minuten-Defaults aus preferences.json — dieselben Werte, die
    /// der Override-Editor als Voreinstellung anzeigt.
    private static func preferenceMinutes(key: String) -> Int {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.preferences),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = (object[key] as? NSNumber)?.intValue
        else { return 30 }
        return value
    }

    // MARK: - Anzeige-Helfer

    /// Profil-Einheiten aus insulin_sensitivities.json (wie AIHubTherapyAnalysis).
    static var isMmol: Bool {
        guard let raw = BaseFileStorage().retrieveRaw(OpenAPS.Settings.insulinSensitivities),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return ((object["units"] as? String) ?? "").lowercased().contains("mmol")
    }

    static func formatTarget(_ mgdl: Double, isMmol: Bool) -> String {
        isMmol
            ? String(format: "%.1f mmol/L", mgdl / 18.0)
            : String(format: "%.0f mg/dL", mgdl)
    }

    static func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0, rest > 0 { return "\(hours) h \(rest) min" }
        if hours > 0 { return "\(hours) h" }
        return "\(minutes) min"
    }
}
