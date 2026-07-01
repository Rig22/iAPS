import CoreLocation
import SwiftUI
import UIKit

/// Einstellungen für AutoPresets: Master-Schalter plus pro Bewegungsart
/// (Gehen/Laufen/Radfahren) ein Preset und eine Haltezeit. Werte werden —
/// wie in den übrigen Hub-Settings — sofort persistiert (NavigationLink-
/// Picker poppt zurück → onAppear; ohne Sofort-Speichern ginge die frische
/// Auswahl verloren). Jedes Speichern postet die Config-Notification, der
/// AutoPresetsService startet/stoppt daraufhin sein Monitoring.
struct AIHubAutoPresetsView: View {
    @State private var config = AIHubAutoPresets.loadConfig()
    @State private var presets: [OverridePresets] = []
    /// Diagnose: zuletzt von CoreMotion gemeldete Roh-Bewegung.
    @State private var lastDetection = ""
    /// Erklär-Sheet: Warum braucht nur Radfahren die Ortung?
    @State private var showLocationInfo = false
    /// Standort verweigert (denied/restricted) → Radfahren-Erkennung kann nicht
    /// funktionieren, und iOS lässt keinen erneuten Dialog zu → Warnung anzeigen.
    @State private var locationDenied = false
    @Environment(\.scenePhase) private var scenePhase

    private let diagnosticTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var cyclingEnabled: Bool { config.config(for: .cycling).enabled }

    var body: some View {
        Form {
            masterSection
            if config.masterEnabled {
                activitiesSection
                diagnosticSection
            }
        }
        .navigationTitle("AutoPresets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLocationInfo, onDismiss: refreshLocationStatus) {
            AutoPresetsLocationInfoView()
        }
        .onChange(of: cyclingEnabled) { enabled in
            refreshLocationStatus()
            // Beim Einschalten mit verweigerter Ortung kann iOS keinen Dialog
            // mehr zeigen → Erklär-Sheet (mit Einstellungen-Button) öffnen.
            if enabled, locationDenied { showLocationInfo = true }
        }
        .onAppear {
            config = AIHubAutoPresets.loadConfig()
            presets = OverrideStorage().fetchProfiles()
            lastDetection = UserDefaults.standard.string(forKey: BaseAutoPresetsService.lastDetectionKey) ?? ""
            refreshLocationStatus()
        }
        .onReceive(diagnosticTimer) { _ in
            lastDetection = UserDefaults.standard.string(forKey: BaseAutoPresetsService.lastDetectionKey) ?? ""
        }
        .onChange(of: scenePhase) { phase in
            // Rückkehr aus den iOS-Einstellungen → Berechtigungsstatus neu lesen,
            // damit eine inzwischen erteilte Ortung die Warnung sofort löscht.
            if phase == .active { refreshLocationStatus() }
        }
    }

    /// Aktuellen Standort-Berechtigungsstatus lesen (denied/restricted = aus).
    private func refreshLocationStatus() {
        let status = CLLocationManager().authorizationStatus
        locationDenied = (status == .denied || status == .restricted)
    }

    // MARK: - Diagnose

    private var diagnosticSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text(hubT("ap.diag.detected"))
                Spacer()
                Text(lastDetection.isEmpty ? "—" : lastDetection)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text(hubT("ap.diag.title"))
        } footer: {
            Text(hubT("ap.diag.footer"))
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

        // Nur Radfahren braucht die Ortung (Rad↔Auto per GPS-Tempo). Ein
        // antippbarer Hinweis erklärt, dass Gehen/Laufen ganz ohne Ortung
        // laufen — damit Wenig-Radler die Berechtigung bewusst wählen können.
        // Ist Radfahren an, aber die Ortung verweigert, wird daraus eine
        // orange Warnung (iOS lässt keinen erneuten Dialog zu → Einstellungen).
        if activity == .cycling {
            let warn = cyclingEnabled && locationDenied
            Button {
                showLocationInfo = true
            } label: {
                Label {
                    Text(hubT(warn ? "ap.location.denied" : "ap.location.hint"))
                        .font(.footnote)
                        .foregroundColor(warn ? .orange : .secondary)
                } icon: {
                    Image(systemName: warn ? "exclamationmark.triangle.fill" : "location.circle")
                        .foregroundColor(warn ? .orange : .blue)
                }
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

/// Erklär-Sheet: macht transparent, dass die Ortung ausschließlich der
/// Radfahr-Erkennung dient (Gehen/Laufen kommen ohne aus) und bietet einen
/// Direktlink in die iOS-Standort-Einstellungen — damit Nutzer, die selten
/// Rad fahren, die Berechtigung bewusst deaktiviert lassen können.
private struct AutoPresetsLocationInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                    Text(hubT("ap.location.info.body"))
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(hubT("ap.location.open.settings"), systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle(hubT("ap.location.info.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(hubT("ap.location.done")) { dismiss() }
                }
            }
        }
    }
}
