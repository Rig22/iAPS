import Combine
import CoreMotion
import Foundation
import Swinject

/// Langlebiger Service, der per CoreMotion erkannte Bewegung (Gehen, Laufen,
/// Radfahren) auf Override-Presets abbildet: Hält eine Aktivität lange genug
/// an, wird das zugeordnete Preset aktiviert; endet die Aktivität, wird das
/// selbst aktivierte Override nach einer Grace-Period wieder beendet.
///
/// Sicherheitsleitplanken:
/// - **Opt-in:** Ohne Master-Toggle läuft kein Monitoring (CMMotionActivityManager
///   wird gestoppt) — kein Akku-/Berechtigungs-Bedarf.
/// - **Manuell hat Vorrang:** Ein vom Nutzer gesetztes Override wird nie
///   überschrieben oder beendet. AutoPresets greift nur, wenn nichts
///   Manuelles aktiv ist, und beendet nur Overrides, die es selbst erzeugt hat.
/// - **Kein Core-Data-Schema-Touch:** Aktivierung schreibt eine normale
///   `Override`-Row (wie die Shortcuts/UI). Die Herkunft wird in UserDefaults
///   vermerkt (Preset-ID + Erstell-Datum der Row).
protocol AutoPresetsService: AnyObject {
    /// Konfiguration neu lesen und Monitoring entsprechend starten/stoppen.
    func reload()
}

final class BaseAutoPresetsService: AutoPresetsService, Injectable {
    @Injected() private var nightscoutManager: NightscoutManager!

    private let motionManager = CMMotionActivityManager()
    private let overrideStorage = OverrideStorage()
    private let motionQueue = OperationQueue()

    private var isMonitoring = false
    private var config = AIHubAutoPresets.Config.defaultConfig

    /// Aktuell erkannte Ziel-Aktivität (nil = keine relevante Bewegung).
    private var detectedActivity: AIHubAutoPresets.Activity?
    private var startWorkItem: DispatchWorkItem?
    private var endWorkItem: DispatchWorkItem?
    private var dropWorkItem: DispatchWorkItem?

    // Herkunfts-Markierung des zuletzt selbst aktivierten Overrides
    private static let activeAutoIDKey = "iAPS.aiHubAutoPresetsActiveID"
    private static let activeAutoDateKey = "iAPS.aiHubAutoPresetsActiveDate"

    /// Diagnose: zuletzt von CoreMotion gemeldete Roh-Bewegung (Flags +
    /// Konfidenz + Uhrzeit). Wird bei JEDEM Ereignis geschrieben, damit die
    /// Settings-Zeile zeigt, was das iPhone beim Radfahren wirklich erkennt.
    static let lastDetectionKey = "iAPS.aiHubAutoPresetsLastDetection"

    init(resolver: Resolver) {
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .utility
        injectServices(resolver)
        Foundation.NotificationCenter.default.addObserver(
            self,
            selector: #selector(configChanged),
            name: AIHubAutoPresets.configChangedNotification,
            object: nil
        )
        reload()
    }

    deinit {
        Foundation.NotificationCenter.default.removeObserver(self)
    }

    @objc private func configChanged() { reload() }

    // MARK: - Monitoring-Steuerung

    func reload() {
        AIHubAutoPresets.migrateSustainDefaultsIfNeeded()
        config = AIHubAutoPresets.loadConfig()
        let shouldMonitor = config.masterEnabled
            && AIHubAutoPresets.Activity.allCases.contains { config.isLive($0) }

        if shouldMonitor {
            startMonitoring()
        } else {
            stopMonitoring()
            // Master aus / keine Aktivität live → eigenes Override beenden
            DispatchQueue.main.async { [weak self] in self?.endAutoOverrideIfOurs() }
        }
    }

    private func startMonitoring() {
        guard !isMonitoring, CMMotionActivityManager.isActivityAvailable() else { return }
        isMonitoring = true
        motionManager.startActivityUpdates(to: motionQueue) { [weak self] activity in
            guard let activity = activity else { return }
            // Auf Main auswerten: Timer-/Status-Mutationen passieren sonst aus
            // zwei Queues (Motion-Callback + Timer-Callbacks) → Data Race.
            DispatchQueue.main.async { self?.handle(activity) }
        }
    }

    private func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        motionManager.stopActivityUpdates()
        cancelTimers()
        detectedActivity = nil
    }

    // MARK: - Bewegungs-Auswertung

    /// CMMotionActivity ist ereignisbasiert (feuert bei Zustandswechsel).
    /// Wir bilden auf eine *live* Ziel-Aktivität ab; alles andere
    /// (stationary/automotive/unknown oder nicht konfiguriert) zählt als
    /// „keine Aktivität". Läuft auf Main (siehe startMonitoring).
    private func handle(_ activity: CMMotionActivity) {
        recordDiagnostic(activity)
        if let mapped = acceptedActivity(activity) {
            // Ziel-Aktivität mit ausreichender Konfidenz erkannt → ein evtl.
            // laufendes Drop-Fenster war nur ein kurzer Aussetzer.
            dropWorkItem?.cancel()
            dropWorkItem = nil

            guard mapped != detectedActivity else { return }
            detectedActivity = mapped
            startWorkItem?.cancel()
            startWorkItem = nil
            endWorkItem?.cancel()
            endWorkItem = nil

            let delay = TimeInterval(config.config(for: mapped).sustainedSeconds)
            let work = DispatchWorkItem { [weak self] in self?.activate(mapped) }
            startWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
        } else {
            guard let current = detectedActivity else { return }
            if current == .cycling {
                // Radfahren: schwaches/flackeriges Signal → kurze
                // Fehlklassifikationen nicht sofort als Ende werten.
                guard dropWorkItem == nil else { return }
                let drop = DispatchWorkItem { [weak self] in self?.activityDidStop() }
                dropWorkItem = drop
                DispatchQueue.main.asyncAfter(deadline: .now() + AIHubAutoPresets.dropGraceSeconds, execute: drop)
            } else {
                // Gehen/Laufen: zuverlässige Erkennung → sofort als beendet
                // werten (bricht einen noch nicht ausgelösten Start ab, sonst
                // würde ein kurzer Gang nachträglich noch aktivieren).
                activityDidStop()
            }
        }
    }

    /// Drop-Grace abgelaufen, ohne dass die Ziel-Aktivität zurückkam → wirklich
    /// beendet: Start-Countdown abbrechen, eigenes Override nach Grace beenden.
    private func activityDidStop() {
        dropWorkItem = nil
        detectedActivity = nil
        startWorkItem?.cancel()
        startWorkItem = nil
        endWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.endAutoOverrideIfOurs() }
        endWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AIHubAutoPresets.autoEndGraceSeconds, execute: work)
    }

    /// Höchste relevante Bewegungsart mit *akzeptabler* Konfidenz, sofern live.
    /// Reihenfolge Cycling > Running > Walking. **Radfahren akzeptiert auch
    /// niedrige Konfidenz**, weil CoreMotion das Rad-Signal auf dem iPhone
    /// (ohne Apple Watch) meist nur mit `.low` meldet; Gehen/Laufen bleiben bei
    /// ≥ medium, damit sie so präzise wie bisher bleiben. Die Haltezeit filtert
    /// das verbleibende Rauschen.
    /// Diagnose: rohe CoreMotion-Flags + Konfidenz + Uhrzeit persistieren —
    /// zeigt in den Settings, was das iPhone beim Radfahren wirklich erkennt.
    private func recordDiagnostic(_ activity: CMMotionActivity) {
        var flags: [String] = []
        if activity.cycling { flags.append("cycling") }
        if activity.automotive { flags.append("automotive") }
        if activity.running { flags.append("running") }
        if activity.walking { flags.append("walking") }
        if activity.stationary { flags.append("stationary") }
        if activity.unknown { flags.append("unknown") }
        let confidence: String
        switch activity.confidence {
        case .low: confidence = "low"
        case .medium: confidence = "medium"
        case .high: confidence = "high"
        @unknown default: confidence = "?"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        let text = "\(flags.isEmpty ? "—" : flags.joined(separator: ", ")) · \(confidence) · \(formatter.string(from: Date()))"
        UserDefaults.standard.set(text, forKey: Self.lastDetectionKey)
    }

    private func acceptedActivity(_ activity: CMMotionActivity) -> AIHubAutoPresets.Activity? {
        guard let mapped = mappedActivity(activity) else { return nil }
        if mapped == .cycling { return .cycling }
        return activity.confidence != .low ? mapped : nil
    }

    /// Höchste relevante Bewegungsart, sofern live konfiguriert (ohne
    /// Konfidenz-Filter — den macht `acceptedActivity`).
    private func mappedActivity(_ activity: CMMotionActivity) -> AIHubAutoPresets.Activity? {
        if activity.cycling, config.isLive(.cycling) { return .cycling }
        if activity.running, config.isLive(.running) { return .running }
        if activity.walking, config.isLive(.walking) { return .walking }
        return nil
    }

    private func cancelTimers() {
        startWorkItem?.cancel()
        startWorkItem = nil
        endWorkItem?.cancel()
        endWorkItem = nil
        dropWorkItem?.cancel()
        dropWorkItem = nil
    }

    // MARK: - Aktivieren / Beenden (auf Main, Core Data = viewContext)

    private func activate(_ activity: AIHubAutoPresets.Activity) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let activityConfig = self.config.config(for: activity)
            guard self.config.isLive(activity), let presetID = activityConfig.presetID else { return }
            guard let preset = self.overrideStorage.fetchProfiles().first(where: { $0.id == presetID })
            else { return }

            let latest = self.overrideStorage.fetchLatestOverride().first
            let active = latest?.enabled ?? false

            if active {
                // Läuft bereits unser eigenes Override für genau dieses Preset?
                if self.isOurOverride(latest), latest?.id == presetID { return }
                // Manuelles (oder fremdes) Override → Vorrang, nicht anfassen
                guard self.isOurOverride(latest) else { return }
                // Eigenes Override für andere Aktivität → beenden, dann neues
                if let duration = self.overrideStorage.cancelProfile(), let last = latest {
                    let name = self.overrideStorage.isPresetName() ?? last.percentage.formatted()
                    self.nightscoutManager.editOverride(name, duration, last.date ?? Date.now)
                }
            }

            self.overrideStorage.overrideFromPreset(preset)
            let created = self.overrideStorage.fetchLatestOverride().first
            self.nightscoutManager.uploadOverride(
                preset.name ?? "",
                Double(truncating: preset.duration ?? 0),
                created?.date ?? Date.now
            )
            self.rememberOurOverride(id: presetID, date: created?.date)
        }
    }

    /// Beendet das aktive Override nur, wenn AutoPresets es selbst erzeugt hat.
    private func endAutoOverrideIfOurs() {
        guard let active = overrideStorage.fetchLatestOverride().first, active.enabled else {
            forgetOurOverride()
            return
        }
        guard isOurOverride(active) else { return } // manuell → Vorrang
        let name = overrideStorage.isPresetName() ?? "📉"
        if let duration = overrideStorage.cancelProfile() {
            nightscoutManager.editOverride(name, duration, active.date ?? Date.now)
        }
        forgetOurOverride()
    }

    // MARK: - Herkunfts-Markierung (UserDefaults statt Core-Data-Feld)

    private func rememberOurOverride(id: String, date: Date?) {
        UserDefaults.standard.set(id, forKey: Self.activeAutoIDKey)
        UserDefaults.standard.set(date?.timeIntervalSince1970 ?? 0, forKey: Self.activeAutoDateKey)
    }

    private func forgetOurOverride() {
        UserDefaults.standard.removeObject(forKey: Self.activeAutoIDKey)
        UserDefaults.standard.removeObject(forKey: Self.activeAutoDateKey)
    }

    /// Stimmt die Row mit der gemerkten Auto-Aktivierung überein (ID + Datum)?
    private func isOurOverride(_ override: Override?) -> Bool {
        guard let override = override,
              let storedID = UserDefaults.standard.string(forKey: Self.activeAutoIDKey),
              override.id == storedID
        else { return false }
        let storedDate = UserDefaults.standard.double(forKey: Self.activeAutoDateKey)
        guard storedDate > 0, let date = override.date else { return false }
        return abs(date.timeIntervalSince1970 - storedDate) < 1.0
    }
}
