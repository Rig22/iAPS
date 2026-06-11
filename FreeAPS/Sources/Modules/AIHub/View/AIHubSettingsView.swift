import SwiftUI

/// AI-Hub-Einstellungen: Modellwahl für den Chat plus die drei Provider-Keys.
/// Die Keys sind dieselben UserDefaults wie bei der FoodSearch-KI — wer dort
/// schon Keys eingetragen hat, muss hier nichts tun.
///
/// Speichern-Modell wie FoodSearchSettingsView: Werte werden in `.onAppear`
/// frisch aus UserDefaults gelesen (NavigationLink-Destinations werden eager
/// erzeugt — @State-Initialwerte wären beim Wiederöffnen veraltet) und erst
/// beim Tippen auf „Speichern" persistiert.
struct AIHubSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var chatProvider = UserDefaults.standard.aiHubChatProvider
    @State private var aiLanguage = UserDefaults.standard.userPreferredLanguageForAI ?? ""
    @State private var carbsComplete = UserDefaults.standard.aiHubCarbsComplete
    @State private var showModelInfo = false
    @State private var claudeKey = ""
    @State private var openAIKey = ""
    @State private var geminiKey = ""

    /// Sprachen der iAPS-Localizations; "" = Systemsprache.
    private let languageCodes = [
        "ar", "ca", "da", "de", "el", "en", "es", "fi", "fr", "he", "hu", "it", "nb",
        "nl", "pl", "pt", "pt-BR", "ru", "sk", "sv", "tr", "uk", "vi", "zh-Hans"
    ]

    var body: some View {
        Form {
            Section {
                Picker(hubT("settings.model.label"), selection: $chatProvider) {
                    ForEach(AITextProvider.allCases, id: \.self) { provider in
                        HStack(spacing: 12) {
                            Text(provider.providerName)
                                .font(.caption)
                            if let modelName = provider.modelName {
                                Text(modelName)
                                    .font(.subheadline)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            Spacer()
                            if let fast = provider.fast, fast {
                                Text(hubT("settings.fast"))
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.navigationLink)
                // Sofort persistieren: Der navigationLink-Picker poppt zurück
                // und löst damit onAppear → readPersistedValues() aus. Ohne
                // Sofort-Speichern würde das die frische Auswahl wieder mit
                // dem alten Wert überschreiben.
                .onChange(of: chatProvider) { newValue in
                    UserDefaults.standard.aiHubChatProvider = newValue
                }
            } header: {
                HStack(spacing: 6) {
                    Text(hubT("settings.model.section"))
                    // Modell-/Preis-Überblick vor der Wahl
                    Button {
                        showModelInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            } footer: {
                Text(hubT("settings.model.footer"))
            }

            Section {
                Picker(hubT("settings.lang.label"), selection: $aiLanguage) {
                    Text(hubT("settings.lang.system")).tag("")
                    ForEach(languageCodes, id: \.self) { code in
                        Text(languageDisplayName(code)).tag(code)
                    }
                }
                .pickerStyle(.navigationLink)
                // Sofort persistieren — gleicher onAppear-Effekt wie beim
                // Modell-Picker (siehe oben).
                .onChange(of: aiLanguage) { newValue in
                    UserDefaults.standard.userPreferredLanguageForAI = newValue.isEmpty ? nil : newValue
                }
            } header: {
                Text(hubT("settings.lang.section"))
            } footer: {
                Text(hubT("settings.lang.footer"))
            }

            Section {
                Toggle(hubT("settings.carbs.toggle"), isOn: $carbsComplete)
                    // Sofort persistieren — gleicher onAppear-Effekt wie bei
                    // den Pickern (siehe oben).
                    .onChange(of: carbsComplete) { newValue in
                        UserDefaults.standard.aiHubCarbsComplete = newValue
                    }
            } header: {
                Text(hubT("settings.carbs.section"))
            } footer: {
                Text(hubT("settings.carbs.footer"))
            }

            Section {
                keyRow(
                    title: "Claude API Key",
                    hint: hubT("settings.key.claude.hint"),
                    text: $claudeKey
                )
                keyRow(
                    title: "Google Gemini API Key",
                    hint: hubT("settings.key.gemini.hint"),
                    text: $geminiKey
                )
                keyRow(
                    title: "ChatGPT (OpenAI) API Key",
                    hint: hubT("settings.key.openai.hint"),
                    text: $openAIKey
                )
            } header: {
                Text(hubT("settings.keys.section"))
            } footer: {
                Text(hubT("settings.keys.footer"))
            }

            Section {
                Text(hubT("settings.note.text"))
                    .font(.footnote)
                    .foregroundStyle(.red)
            } header: {
                Text(hubT("settings.note.section"))
            }
        }
        .navigationTitle(hubT("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(hubT("settings.save")) {
                    saveSettings()
                }
            }
        }
        .onAppear {
            readPersistedValues()
        }
        .sheet(isPresented: $showModelInfo) {
            AIHubModelInfoView()
        }
    }

    /// Sprachname in der aktuellen UI-Sprache, z. B. "Niederländisch".
    private func languageDisplayName(_ code: String) -> String {
        (Locale.current.localizedString(forIdentifier: code) ?? code).capitalized
    }

    private func readPersistedValues() {
        chatProvider = UserDefaults.standard.aiHubChatProvider
        aiLanguage = UserDefaults.standard.userPreferredLanguageForAI ?? ""
        carbsComplete = UserDefaults.standard.aiHubCarbsComplete
        claudeKey = UserDefaults.standard.claudeAPIKey
        openAIKey = UserDefaults.standard.openAIAPIKey
        geminiKey = UserDefaults.standard.googleGeminiAPIKey
    }

    private func saveSettings() {
        UserDefaults.standard.aiHubChatProvider = chatProvider
        UserDefaults.standard.claudeAPIKey = claudeKey.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.openAIAPIKey = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.googleGeminiAPIKey = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
    }

    private func keyRow(
        title: String,
        hint: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
            AIHubSecureField(placeholder: title, text: text)
        }
        .padding(.vertical, 2)
    }
}

/// SecureField mit Auge-Toggle, analog zur FoodSearch-Settings-Seite
/// (deren `APIKeyRow` ist dort private).
private struct AIHubSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.callout)
            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Modell-Übersicht

/// Kompakte Orientierung vor der Modellwahl: alle Picker-Modelle mit
/// Preis-Richtwerten, Gratis-Kontingent- und Tempo-Kennzeichnung plus
/// die Abo-≠-API-Hinweise pro Anbieter. Preise sind bewusst Richtwerte
/// (Footer) — verbindlich sind die Preisseiten der Anbieter.
struct AIHubModelInfoView: View {
    @Environment(\.dismiss) private var dismiss

    private struct ModelInfo {
        let name: String
        /// „in / out" in USD pro 1 Mio. Tokens; nil = Preis unbekannt/Preview.
        let price: String?
        var free = false
        var fast = false
    }

    private struct ProviderInfo {
        let name: String
        let noteKey: String
        let models: [ModelInfo]
    }

    private let providers: [ProviderInfo] = [
        ProviderInfo(name: "Google Gemini", noteKey: "mi.note.gemini", models: [
            ModelInfo(name: "Gemini 2.5 Flash", price: "0,30 / 2,50", free: true, fast: true),
            ModelInfo(name: "Gemini 2.5 Pro", price: "1,25 / 10"),
            ModelInfo(name: "Gemini 3 Flash Preview", price: nil, fast: true),
            ModelInfo(name: "Gemini 3 Pro Preview", price: nil),
            ModelInfo(name: "Gemini 3.1 Pro Preview", price: nil)
        ]),
        ProviderInfo(name: "Anthropic Claude", noteKey: "mi.note.claude", models: [
            ModelInfo(name: "Haiku 4.5", price: "1 / 5", fast: true),
            ModelInfo(name: "Sonnet 4.5", price: "3 / 15"),
            ModelInfo(name: "Sonnet 4.6", price: "3 / 15"),
            ModelInfo(name: "Opus 4.6", price: "5 / 25")
        ]),
        ProviderInfo(name: "OpenAI", noteKey: "mi.note.openai", models: [
            ModelInfo(name: "GPT-4o mini", price: "0,15 / 0,60", fast: true),
            ModelInfo(name: "GPT-4o", price: "2,50 / 10"),
            ModelInfo(name: "GPT-5 mini", price: "0,25 / 2", fast: true),
            ModelInfo(name: "GPT-5", price: "1,25 / 10"),
            ModelInfo(name: "GPT-5.1", price: nil),
            ModelInfo(name: "GPT-5.2", price: nil),
            ModelInfo(name: "GPT-5.4", price: nil)
        ])
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text(hubT("mi.price.note"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(providers, id: \.name) { provider in
                    Section {
                        ForEach(provider.models, id: \.name) { model in
                            modelRow(model)
                        }
                    } header: {
                        Text(provider.name)
                    } footer: {
                        Text(hubT(provider.noteKey))
                    }
                }
                Section {
                    Text(hubT("mi.footer"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(hubT("mi.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(hubT("mi.done")) { dismiss() }
                }
            }
        }
    }

    private func modelRow(_ model: ModelInfo) -> some View {
        HStack(spacing: 8) {
            Text(model.name)
                .font(.subheadline)
            if model.free {
                badge(hubT("mi.free"), color: .green)
            }
            if model.fast {
                badge(hubT("settings.fast"), color: .blue)
            }
            Spacer()
            Text(model.price ?? "—")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}
