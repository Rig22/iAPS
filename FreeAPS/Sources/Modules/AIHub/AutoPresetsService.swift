import Combine
import CoreLocation
import CoreMotion
import Foundation
import Swinject

/// GPS-Geschwindigkeits-Gate: trennt Radfahren von echtem Autofahren, wenn
/// CoreMotion eine Radfahrt fälschlich als `automotive` meldet (auf dem iPhone
/// ohne Apple Watch häufig). Liefert ausschließlich ein Geschwindigkeits-Verdikt
/// — die Bewegungsklassifikation bleibt bei CoreMotion.
///
/// Datenschutz/Akku: läuft NUR, solange AutoPresets aktiv ist UND ein
/// Rad-Kandidat (`automotive` bei live geschaltetem Radfahren) plausibel ist.
/// Es wird keine Position gespeichert oder hochgeladen — nur die momentane
/// Geschwindigkeit ausgewertet.
final class AutoPresetsSpeedGate: NSObject, CLLocationManagerDelegate {
    enum Verdict {
        /// Noch kein eindeutiges Signal (zu wenig Bewegung / kein Fix / keine
        /// Berechtigung) — vorsichtshalber NICHT als Radfahren aktivieren.
        case undetermined
        /// Radtypische Geschwindigkeit gesehen, keine eindeutige Kfz-Geschwindigkeit.
        case cycling
        /// Eindeutig motorisiert.
        case vehicle
    }

    private let manager = CLLocationManager()
    private var running = false
    /// Anzahl Messwerte im radtypischen Band — bewusst *anhaltend* gefordert,
    /// damit ein einzelner GPS-Ausreißer (z. B. beim Gehen) nicht reicht.
    private var cyclingSamples = 0
    private var vehicleSamples = 0
    private var latestSpeedKmh: Double?
    /// Verhindert mehrfaches Auslösen von `onVehicleDetected` pro Messung.
    private var vehicleNotified = false

    /// Wird einmalig aufgerufen, sobald eindeutige Kfz-Geschwindigkeit erreicht
    /// ist — für die Live-Demotion einer laufenden Rad-Erkennung. Aufruf erfolgt
    /// aus dem LocationManager-Callback; der Empfänger dispatcht selbst auf Main.
    var onVehicleDetected: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
    }

    var isRunning: Bool { running }

    /// Aktuelle Geschwindigkeit (km/h) für die Diagnose-Zeile, falls bekannt.
    var diagnosticSpeedKmh: Double? { running ? latestSpeedKmh : nil }

    var verdict: Verdict {
        if vehicleSamples >= AIHubAutoPresets.vehicleSpeedSampleCount { return .vehicle }
        if cyclingSamples >= AIHubAutoPresets.cyclingSpeedSampleCount { return .cycling }
        return .undetermined
    }

    /// Berechtigung anfordern (z. B. sobald Radfahren live wird), damit der
    /// System-Dialog erscheint, während der Nutzer in der App ist — nicht erst
    /// mitten auf dem Rad.
    func requestAuthorizationIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func start() {
        guard !running else { return }
        running = true
        cyclingSamples = 0
        vehicleSamples = 0
        vehicleNotified = false
        latestSpeedKmh = nil
        manager.startUpdatingLocation()
    }

    func stop() {
        guard running else { return }
        running = false
        manager.stopUpdatingLocation()
        cyclingSamples = 0
        vehicleSamples = 0
        vehicleNotified = false
        latestSpeedKmh = nil
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.speed >= 0 else { return }
        let kmh = location.speed * 3.6
        latestSpeedKmh = kmh
        if kmh >= AIHubAutoPresets.cyclingSpeedMinKmh, kmh < AIHubAutoPresets.vehicleSpeedKmh {
            cyclingSamples += 1
        }
        if kmh >= AIHubAutoPresets.vehicleSpeedKmh {
            vehicleSamples += 1
            // Eindeutig Kfz → einmalig melden, damit eine bereits laufende oder
            // im Countdown befindliche Rad-Erkennung sofort gestoppt wird.
            if !vehicleNotified, vehicleSamples >= AIHubAutoPresets.vehicleSpeedSampleCount {
                vehicleNotified = true
                onVehicleDetected?()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Berechtigung entzogen/verweigert → Messung sauber beenden.
        switch manager.authorizationStatus {
        case .denied,
             .restricted:
            stop()
        default:
            break
        }
    }
}

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

    /// GPS-Gate, das Radfahren von Autofahren trennt, wenn CoreMotion eine
    /// Radfahrt als `automotive` fehlklassifiziert. Nur auf Main zugreifen.
    private let speedGate = AutoPresetsSpeedGate()

    private var isMonitoring = false
    private var config = AIHubAutoPresets.Config.defaultConfig

    /// Aktuell erkannte Ziel-Aktivität (nil = keine relevante Bewegung).
    private var detectedActivity: AIHubAutoPresets.Activity?
    /// True, solange eine Rad-Erkennung läuft, die das GPS-Gate bestätigen muss
    /// (auf dem iPhone gilt das für jedes Rad-Signal — Flag wie automotive).
    private var cyclingViaSpeedGate = false
    /// Bis dahin gilt eine als Kfz erkannte Fahrt als gesperrt (kein neuer
    /// Rad-Kandidat, GPS bleibt aus) — siehe vehicleLockoutSeconds.
    private var speedGateVehicleUntil: Date?
    /// Spätestens dann wird ein ergebnisloser Rad-Kandidat abgebrochen (nie
    /// radtypisches Tempo erreicht) — siehe cyclingObserveMaxSeconds.
    private var cyclingObserveDeadline: Date?
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
        // Live-Demotion: meldet das GPS-Gate eindeutige Kfz-Geschwindigkeit,
        // wird eine laufende/anstehende Rad-Erkennung sofort verworfen.
        speedGate.onVehicleDetected = { [weak self] in self?.handleVehicleDetected() }
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

        // Standort-Berechtigung anfragen, sobald Radfahren live ist (auch wenn
        // Monitoring schon läuft) — der System-Dialog soll erscheinen, während
        // der Nutzer in der App ist, nicht erst mitten auf dem Rad.
        if config.isLive(.cycling) {
            DispatchQueue.main.async { [weak self] in self?.speedGate.requestAuthorizationIfNeeded() }
        }

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
        cyclingViaSpeedGate = false
        cyclingObserveDeadline = nil
        speedGateVehicleUntil = nil
        DispatchQueue.main.async { [weak self] in self?.speedGate.stop() }
    }

    // MARK: - Bewegungs-Auswertung

    /// CMMotionActivity ist ereignisbasiert (feuert bei Zustandswechsel).
    /// Wir bilden auf eine *live* Ziel-Aktivität ab; alles andere
    /// (stationary/automotive/unknown oder nicht konfiguriert) zählt als
    /// „keine Aktivität". Läuft auf Main (siehe startMonitoring).
    private func handle(_ activity: CMMotionActivity) {
        // GPS-Gate nur laufen lassen, solange ein Rad-Kandidat (automotive bei
        // live geschaltetem Radfahren) plausibel ist. Idempotent — start/stop
        // prüfen selbst, ob sich der Zustand ändert.
        if isCyclingCandidate(activity) {
            speedGate.start()
        }

        recordDiagnostic(activity)
        if let mapped = acceptedActivity(activity) {
            // Zuverlässige Nicht-Rad-Aktivität (Gehen/Laufen) → GPS-Gate hier
            // irrelevant; zugleich Kfz-Sperre lösen (Auto wurde verlassen).
            if mapped != .cycling {
                speedGate.stop()
                speedGateVehicleUntil = nil
            }
            // Ziel-Aktivität mit ausreichender Konfidenz erkannt → ein evtl.
            // laufendes Drop-Fenster war nur ein kurzer Aussetzer.
            dropWorkItem?.cancel()
            dropWorkItem = nil

            guard mapped != detectedActivity else { return }
            detectedActivity = mapped
            // Radfahren wird IMMER per GPS-Gate bestätigt (CoreMotions Rad-Signal
            // ist auf dem iPhone unzuverlässig) — Gehen/Laufen brauchen kein GPS.
            cyclingViaSpeedGate = (mapped == .cycling)
            cyclingObserveDeadline = (mapped == .cycling)
                ? Date().addingTimeInterval(AIHubAutoPresets.cyclingObserveMaxSeconds)
                : nil
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
        cyclingViaSpeedGate = false
        cyclingObserveDeadline = nil
        speedGateVehicleUntil = nil
        speedGate.stop()
        startWorkItem?.cancel()
        startWorkItem = nil
        endWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.endAutoOverrideIfOurs() }
        endWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AIHubAutoPresets.autoEndGraceSeconds, execute: work)
    }

    /// Das GPS-Gate hat eindeutige Kfz-Geschwindigkeit erkannt → eine laufende
    /// oder im Countdown befindliche Rad-Erkennung sofort verwerfen: anstehende
    /// Aktivierung abbrechen, ein bereits gesetztes eigenes Rad-Override sofort
    /// (ohne Grace) beenden und das Gate kurz sperren (Akku während der Fahrt).
    private func handleVehicleDetected() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.detectedActivity == .cycling else { return }
            self.cancelTimers()
            self.detectedActivity = nil
            self.cyclingViaSpeedGate = false
            self.cyclingObserveDeadline = nil
            self.speedGate.stop()
            self.speedGateVehicleUntil = Date().addingTimeInterval(AIHubAutoPresets.vehicleLockoutSeconds)
            self.endAutoOverrideIfOurs()
        }
    }

    /// Diagnose: rohe CoreMotion-Flags + Konfidenz (+ GPS-Tempo, falls das Gate
    /// misst) + Uhrzeit persistieren — zeigt in den Settings, was das iPhone
    /// beim Radfahren wirklich erkennt und wie das Speed-Gate entscheidet.
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
        var parts = [flags.isEmpty ? "—" : flags.joined(separator: ", "), confidence]
        // GPS-Geschwindigkeit nur zeigen, wenn das Gate gerade misst (Rad-
        // Kandidat) — macht beim Radfahren sichtbar, wie das Gate entscheidet.
        if let kmh = speedGate.diagnosticSpeedKmh {
            parts.append(String(format: "%.0f km/h", kmh))
        }
        parts.append(formatter.string(from: Date()))
        let text = parts.joined(separator: " · ")
        UserDefaults.standard.set(text, forKey: Self.lastDetectionKey)
    }

    /// Bildet ein CoreMotion-Ereignis auf eine *live* Ziel-Aktivität ab.
    ///
    /// Gehen/Laufen sind auf dem iPhone zuverlässig → direkt akzeptiert (ab
    /// Konfidenz medium) und haben Vorrang. Radfahren dagegen gilt grundsätzlich
    /// nur als KANDIDAT (siehe `isCyclingCandidate`): Weder das `cycling`-Flag
    /// noch `automotive` aktivieren Radfahren für sich — das tut allein das
    /// GPS-Speed-Gate beim Auslösen (siehe `activate`). So kann langsames Gehen
    /// nicht versehentlich Radfahren auslösen.
    private func acceptedActivity(_ activity: CMMotionActivity) -> AIHubAutoPresets.Activity? {
        if activity.running, config.isLive(.running), activity.confidence != .low { return .running }
        if activity.walking, config.isLive(.walking), activity.confidence != .low { return .walking }
        if isCyclingCandidate(activity) { return .cycling }
        return nil
    }

    /// Ein Rad-Kandidat liegt vor, wenn Radfahren live ist und CoreMotion eine
    /// Bewegung meldet, die NICHT zuverlässig Gehen/Laufen oder Stillstand ist.
    ///
    /// Bewusst breit: CoreMotions Rad-Erkennung ist auf dem iPhone unbrauchbar —
    /// mal meldet es `automotive`, mal `unknown`, mal GAR KEIN Flag (`—`) während
    /// einer realen Radfahrt. Deshalb darf CoreMotion hier nicht der Auslöser
    /// sein. Alles außer Gehen/Laufen/Stillstand (also automotive, cycling,
    /// unknown oder leer) gilt als Kandidat; ob wirklich Radfahren, Auto oder
    /// nichts, entscheidet allein das GPS-Speed-Gate (12–50 km/h → Rad).
    private func isCyclingCandidate(_ activity: CMMotionActivity) -> Bool {
        guard config.isLive(.cycling) else { return false }
        // Gehen/Laufen/Stillstand sind zuverlässig und schließen Radfahren aus.
        guard !activity.walking, !activity.running, !activity.stationary else { return false }
        // Kürzlich als Kfz erkannt → gesperrt (GPS aus, kein neuer Kandidat).
        if let until = speedGateVehicleUntil, until > Date() { return false }
        return true
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
            // GPS-Gate: Radfahren muss IMMER per Geschwindigkeit bestätigt werden
            // (CoreMotions Rad-Signal ist auf dem iPhone unzuverlässig). Gehen/
            // Laufen (cyclingViaSpeedGate == false) brauchen kein GPS.
            if activity == .cycling, self.cyclingViaSpeedGate {
                // Ohne laufendes GPS (Berechtigung fehlt / nicht verfügbar) lässt
                // sich Rad nicht von Auto trennen → sicherheitshalber NICHT aktivieren.
                guard self.speedGate.isRunning else { return }
                switch self.speedGate.verdict {
                case .cycling:
                    self.cyclingObserveDeadline = nil // bestätigt → aktivieren
                case .vehicle:
                    // Eindeutig Auto → verwerfen und für eine Weile sperren,
                    // damit das GPS während der Fahrt nicht dauernd neu startet.
                    self.speedGate.stop()
                    self.detectedActivity = nil
                    self.cyclingViaSpeedGate = false
                    self.cyclingObserveDeadline = nil
                    self.speedGateVehicleUntil = Date().addingTimeInterval(AIHubAutoPresets.vehicleLockoutSeconds)
                    return
                case .undetermined:
                    // GPS noch nicht warm / zu wenig Bewegung → später erneut
                    // prüfen, statt die Fahrt zu verpassen.
                    guard self.detectedActivity == .cycling else { return }
                    // … aber nicht endlos: nie radtypisches Tempo erreicht →
                    // abbrechen und GPS abschalten (Akku).
                    if let deadline = self.cyclingObserveDeadline, Date() >= deadline {
                        self.activityDidStop()
                        return
                    }
                    let retry = DispatchWorkItem { [weak self] in self?.activate(.cycling) }
                    self.startWorkItem = retry
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + AIHubAutoPresets.cyclingVerdictRetrySeconds,
                        execute: retry
                    )
                    return
                }
            }
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
