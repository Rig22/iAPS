import SwiftUI

/// Einstellungen für AutoPresets: Master-Schalter plus pro Bewegungsart
/// (Gehen/Laufen/Radfahren) ein Preset und eine Haltezeit. Werte werden —
/// wie in den übrigen Hub-Settings — sofort persistiert (NavigationLink-
/// Picker poppt zurück → onAppear; ohne Sofort-Speichern ginge die frische
/// Auswahl verloren). Jedes Speichern postet die Config-Notification, der
/// AutoPresetsService startet/stoppt daraufhin sein Monitoring.
struct AIHubAutoPresetsView: View {
    @State private var config = AIHubAutoPresets.loadConfig()
    @State private var presets: [OverridePresets] = []

    var body: some View {
        Form {
            masterSection
            if config.masterEnabled {
                activitiesSection
                healthKitSection
            }
        }
        .navigationTitle("AutoPresets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            config = AIHubAutoPresets.loadConfig()
            presets = OverrideStorage().fetchProfiles()
        }
    }

    // MARK: - Master

    private var masterSection: some View {
        Section {
            Toggle(hubT("ap.enable"), isOn: Binding(
                get: { config.masterEnabled },
                set: { config.masterEnabled = $0
                    persist() }
            ))
        } header: {
            Text(hubT("ap.section.main"))
        } footer: {
            Text(hubT("ap.enable.footer"))
        }
    }

    // MARK: - Aktivitäten

    private var activitiesSection: some View {
        Section {
            ForEach(AIHubAutoPresets.Activity.allCases) { activity in
                activityRows(activity)
            }
        } header: {
            Text(hubT("ap.section.activities"))
        } footer: {
            Text(hubT("ap.activities.footer"))
        }
    }

    @ViewBuilder private func activityRows(_ activity: AIHubAutoPresets.Activity) -> some View {
        let binding = activityBinding(activity)

        Toggle(isOn: binding.enabled) {
            Label {
                Text(hubT(activity.titleKey))
            } icon: {
                Image(systemName: activity.icon)
                    .foregroundStyle(.blue)
            }
        }

        if binding.enabled.wrappedValue {
            Picker(hubT("ap.preset.for", hubT(activity.titleKey)), selection: binding.presetID) {
                Text(hubT("ap.preset.none")).tag(String?.none)
                ForEach(presets, id: \.id) { preset in
                    Text(presetLabel(preset)).tag(Optional(preset.id ?? ""))
                }
            }
            .pickerStyle(.navigationLink)

            Picker(hubT("ap.sustained.for", hubT(activity.titleKey)), selection: binding.sustained) {
                ForEach(AIHubAutoPresets.sustainedOptions, id: \.self) { seconds in
                    Text(sustainedLabel(seconds)).tag(seconds)
                }
            }
        }
    }

    // MARK: - HealthKit (Folge-Schritt)

    private var healthKitSection: some View {
        Section {
            Toggle(hubT("ap.healthkit"), isOn: .constant(false))
                .disabled(true)
        } header: {
            Text(hubT("ap.section.healthkit"))
        } footer: {
            Text(hubT("ap.healthkit.soon"))
        }
    }

    // MARK: - Bindings & Persistenz

    private struct ActivityBinding {
        let enabled: Binding<Bool>
        let presetID: Binding<String?>
        let sustained: Binding<Int>
    }

    private func activityBinding(_ activity: AIHubAutoPresets.Activity) -> ActivityBinding {
        ActivityBinding(
            enabled: Binding(
                get: { config.config(for: activity).enabled },
                set: { updateActivity(activity) { $0.enabled = $1 }($0) }
            ),
            presetID: Binding(
                get: { config.config(for: activity).presetID },
                set: { newValue in updateActivity(activity) { $0.presetID = $1 }(newValue) }
            ),
            sustained: Binding(
                get: { config.config(for: activity).sustainedSeconds },
                set: { newValue in updateActivity(activity) { $0.sustainedSeconds = $1 }(newValue) }
            )
        )
    }

    /// Liefert eine Setter-Closure, die das Teilfeld der Aktivität ändert,
    /// in die Config zurückschreibt und sofort persistiert.
    private func updateActivity<V>(
        _ activity: AIHubAutoPresets.Activity,
        _ apply: @escaping (inout AIHubAutoPresets.ActivityConfig, V) -> Void
    ) -> (V) -> Void {
        { value in
            var entry = config.config(for: activity)
            apply(&entry, value)
            config.activities[activity.rawValue] = entry
            persist()
        }
    }

    private func persist() {
        AIHubAutoPresets.saveConfig(config)
    }

    // MARK: - Labels

    private func presetLabel(_ preset: OverridePresets) -> String {
        let emoji = preset.emoji ?? ""
        let name = preset.name ?? ""
        return emoji.isEmpty ? name : "\(emoji) \(name)"
    }

    private func sustainedLabel(_ seconds: Int) -> String {
        switch seconds {
        case 0: return hubT("ap.sustained.instant")
        case ..<60: return "\(seconds) s"
        default:
            let minutes = seconds / 60
            return hubT("ap.sustained.minutes", minutes)
        }
    }
}
