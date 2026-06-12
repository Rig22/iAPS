import Foundation

// MARK: - Provider selection (shared API keys, own model choice)

extension UserDefaults {
    private static let aiHubChatProviderKey = "iAPS.aiHubChatProvider"
    private static let aiHubCarbsCompleteKey = "iAPS.aiHubCarbsComplete"
    private static let aiHubAllowApplyKey = "iAPS.aiHubAllowApply"

    /// Model used by the AI Hub chat. Independent from the FoodSearch
    /// provider choices, but reads the same per-provider API keys.
    var aiHubChatProvider: AITextProvider {
        get {
            if let str = string(forKey: Self.aiHubChatProviderKey),
               let provider = AITextProvider(rawValue: str)
            {
                return provider
            }
            return .defaultProvider
        }
        set {
            set(newValue.rawValue, forKey: Self.aiHubChatProviderKey)
        }
    }

    /// Self-assessment by the user: "I log all meals". When true, chat,
    /// recap and therapy analysis may treat carb entries as complete —
    /// carb-free windows are real, meal patterns may be interpreted.
    /// Default false: carb entries are assumed incomplete.
    var aiHubCarbsComplete: Bool {
        get { bool(forKey: Self.aiHubCarbsCompleteKey) }
        set { set(newValue, forKey: Self.aiHubCarbsCompleteKey) }
    }

    /// Opt-in: Therapy-Insights-Vorschläge dürfen nach Bestätigung direkt
    /// ins aktive Profil übernommen werden. Default false — ohne den
    /// Toggle zeigt die View keine Übernehmen-Buttons.
    var aiHubAllowApply: Bool {
        get { bool(forKey: Self.aiHubAllowApplyKey) }
        set { set(newValue, forKey: Self.aiHubAllowApplyKey) }
    }
}

// MARK: - Chat model

enum AIHubChat {
    struct Message: Identifiable, Equatable {
        enum Role {
            case user
            case assistant
        }

        let id = UUID()
        let role: Role
        let text: String
        let date = Date()
    }
}

// MARK: - Service

/// Thin chat layer over the generic FoodSearch AI transport
/// (`AIProviderClient` + provider protocols). Multi-turn is realized as
/// transcript-in-prompt — the provider protocols build single-message
/// requests, which is sufficient for this use case.
struct AIHubChatService: Sendable {
    static func apiKey(for provider: AITextProvider) -> String {
        guard case let .aiModel(model) = provider else { return "" }
        switch model.provider {
        case .claude: return UserDefaults.standard.claudeAPIKey
        case .gemini: return UserDefaults.standard.googleGeminiAPIKey
        case .openAI: return UserDefaults.standard.openAIAPIKey
        }
    }

    static var isConfigured: Bool {
        !apiKey(for: UserDefaults.standard.aiHubChatProvider)
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sends the conversation and returns the assistant's reply.
    /// `dataContext` is the compact therapy-data block from `AIHubChatContext`.
    func send(messages: [AIHubChat.Message], dataContext: String) async throws -> String {
        let prompt = Self.buildPrompt(messages: messages, dataContext: dataContext)
        return try await Self.executePrompt(prompt)
    }

    /// Einzelner Prompt ohne Chat-Transkript — gemeinsamer Unterbau für
    /// Chat und Recap. Nutzt Provider/Modell aus den AI-Hub-Einstellungen.
    static func executePrompt(_ prompt: String) async throws -> String {
        let provider = UserDefaults.standard.aiHubChatProvider
        guard case let .aiModel(model) = provider else {
            throw AIFoodAnalysisError.customError("Invalid AI provider selection.")
        }
        let key = apiKey(for: provider).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw AIFoodAnalysisError.customError(hubT("chat.nokey.title"))
        }

        let proto: AIProviderProtocol = switch model {
        case let .openAI(m): OpenAIProtocol(model: m, apiKey: key)
        case let .gemini(m): GeminiProtocol(model: m, apiKey: key)
        case let .claude(m): ClaudeProtocol(model: m, apiKey: key)
        }

        let client = AIProviderClient(proto: proto)
        return try await client.executeQuery(prompt: prompt, images: [], telemetryCallback: nil)
    }

    static func buildPrompt(messages: [AIHubChat.Message], dataContext: String) -> String {
        // Explizit gewählte Sprache gewinnt immer — sonst würde die
        // Folge-dem-Nutzer-Heuristik sie überstimmen, sobald die Frage
        // (z. B. über die lokalisierten Starter-Chips) in einer anderen
        // Sprache gestellt wird. Nur bei "Systemsprache" bleibt es flexibel.
        let languageRule = UserDefaults.standard.userPreferredLanguageForAI != nil
            ? "- Always answer in \(AIHubL10n.aiAnswerLanguageName), regardless of the " +
            "language the user writes in."
            : "- Answer in \(AIHubL10n.aiAnswerLanguageName) unless the user's last message " +
            "is clearly written in a different language — then follow the user."

        var lines: [String] = []
        lines.append(
            """
            You are the AI assistant inside iAPS, a DIY automated insulin delivery app \
            (OpenAPS-based hybrid closed loop). The user asks questions about their own \
            diabetes data and loop settings.

            Rules:
            \(languageRule)
            - Be concise and specific. Reference concrete numbers and times of day from the data.
            - When the data suggests a settings change (basal, ISF, CR, targets), describe the \
            observation and a cautious proposal (small steps, max ~10% at once), and remind the \
            user that settings changes are their own decision and worth discussing with their \
            care team.
            - Glucose values in the data are in mg/dL. Present values in the user's display \
            unit (stated in the data block); convert mg/dL to mmol/L by dividing by 18.
            - If the data is insufficient to answer, say so instead of guessing.
            - End your reply with one final line in exactly this format: \
            [FOLLOWUP] first question | second question | third question — three short \
            follow-up questions the user might plausibly ask next, written in the user's \
            language and phrased from the user's perspective. Do not refer to this line \
            in your answer.
            """
        )
        lines.append("=== USER DATA ===")
        lines.append(dataContext)
        lines.append("=== CONVERSATION ===")
        for message in messages {
            switch message.role {
            case .user: lines.append("User: \(message.text)")
            case .assistant: lines.append("Assistant: \(message.text)")
            }
        }
        lines.append("Assistant:")
        return lines.joined(separator: "\n\n")
    }

    /// Trennt die `[FOLLOWUP]`-Zeile von der eigentlichen Antwort.
    /// Fehlt sie (oder hält sich das Modell nicht ans Format), kommt der
    /// gesamte Text unverändert zurück — Follow-ups sind nice-to-have.
    static func parseReply(_ raw: String) -> (text: String, followUps: [String]) {
        let marker = "[FOLLOWUP]"
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: marker, options: .backwards) else {
            return (trimmed, [])
        }
        let text = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return (trimmed, []) }
        let followUps = trimmed[range.upperBound...]
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count < 120 }
        return (text, Array(followUps.prefix(3)))
    }
}
