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
                Text(hubT("settings.model.section"))
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
    }

    /// Sprachname in der aktuellen UI-Sprache, z. B. "Niederländisch".
    private func languageDisplayName(_ code: String) -> String {
        (Locale.current.localizedString(forIdentifier: code) ?? code).capitalized
    }

    private func readPersistedValues() {
        chatProvider = UserDefaults.standard.aiHubChatProvider
        aiLanguage = UserDefaults.standard.userPreferredLanguageForAI ?? ""
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
