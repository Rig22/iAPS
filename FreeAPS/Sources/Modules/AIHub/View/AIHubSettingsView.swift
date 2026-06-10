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
    @State private var claudeKey = ""
    @State private var openAIKey = ""
    @State private var geminiKey = ""

    var body: some View {
        Form {
            Section {
                Picker("Modell für den Chat", selection: $chatProvider) {
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
                                Text("Schnell")
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
                Text("Modell")
            } footer: {
                Text("Wird sofort übernommen. Unabhängig von der Modellwahl der KI-Essenserkennung.")
            }

            Section {
                keyRow(
                    title: "Claude API Key",
                    hint: "Key unter console.anthropic.com erstellen.",
                    text: $claudeKey
                )
                keyRow(
                    title: "Google Gemini API Key",
                    hint: "Kostenlosen Key unter ai.google.dev erstellen.",
                    text: $geminiKey
                )
                keyRow(
                    title: "ChatGPT (OpenAI) API Key",
                    hint: "Key unter platform.openai.com erstellen.",
                    text: $openAIKey
                )
            } header: {
                Text("API Keys")
            } footer: {
                Text(
                    "Dieselben Keys wie bei der KI-Essenserkennung — dort eingetragene Keys gelten auch hier. Es wird nur der Key des gewählten Anbieters verwendet."
                )
            }

            Section {
                Text(
                    "KI-Antworten sind Schätzungen und können Fehler enthalten. Therapieänderungen immer selbst prüfen und im Zweifel mit dem Behandlungsteam besprechen."
                )
                .font(.footnote)
                .foregroundStyle(.red)
            } header: {
                Text("Hinweis")
            }
        }
        .navigationTitle("AI-Hub-Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    saveSettings()
                }
            }
        }
        .onAppear {
            readPersistedValues()
        }
    }

    private func readPersistedValues() {
        chatProvider = UserDefaults.standard.aiHubChatProvider
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
