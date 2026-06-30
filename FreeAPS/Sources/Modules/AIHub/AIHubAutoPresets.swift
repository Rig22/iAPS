import Foundation

/// Konfiguration für AutoPresets: bewegungsabhängiges Aktivieren von
/// Override-Presets. Rein in UserDefaults gehalten — kein Core-Data-Touch,
/// damit der dev-Merge der `.xcdatamodeld` unberührt bleibt.
enum AIHubAutoPresets {
    /// Bewegungsarten, die CoreMotion zuverlässig unterscheidet.
    enum Activity: String, Codable, CaseIterable, Identifiable {
        case walking
        case running
        case cycling

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .walking: return "ap.activity.walking"
            case .running: return "ap.activity.running"
            case .cycling: return "ap.activity.cycling"
            }
        }

        var icon: String {
            switch self {
            case .walking: return "figure.walk"
            case .running: return "figure.run"
            case .cycling: return "figure.outdoor.cycle"
            }
        }

        /// Voreingestellte Haltezeit. Radfahren etwas höher als Gehen/Laufen,
        /// um kurze Pendel-/Ampelphasen herauszufiltern — aber nicht zu hoch,
        /// da CoreMotion das Rad-Signal ohnehin schwächer/flackeriger liefert.
        var defaultSustainedSeconds: Int {
            switch self {
            case .running,
                 .walking: return 120
            case .cycling: return 60
            }
        }

        /// Alter Default (vor der Sensitivitäts-Anpassung) — für die einmalige
        /// Migration, die noch unveränderte Werte auf den neuen Default hebt.
        var legacyDefaultSustainedSeconds: Int {
            switch self {
            case .running,
                 .walking: return 30
            case .cycling: return 120
            }
        }
    }

    /// Konfiguration einer einzelnen Aktivität.
    struct ActivityConfig: Codable {
        var enabled: Bool
        /// OverridePresets.id; nil = noch keins gewählt → Aktivität inaktiv.
        var presetID: String?
        var sustainedSeconds: Int
    }

    /// Gesamtkonfiguration (eine JSON-Blob in UserDefaults).
    struct Config: Codable {
        var masterEnabled: Bool
        var activities: [String: ActivityConfig]

        static var defaultConfig: Config {
            var activities: [String: ActivityConfig] = [:]
            for activity in Activity.allCases {
                activities[activity.rawValue] = ActivityConfig(
                    enabled: activity != .cycling, // Walking/Running default an
                    presetID: nil,
                    sustainedSeconds: activity.defaultSustainedSeconds
                )
            }
            return Config(masterEnabled: false, activities: activities)
        }

        func config(for activity: Activity) -> ActivityConfig {
            activities[activity.rawValue]
                ?? ActivityConfig(enabled: false, presetID: nil, sustainedSeconds: activity.defaultSustainedSeconds)
        }

        /// Eine Aktivität ist wirksam, wenn Master + Aktivität an sind und
        /// ein Preset zugeordnet ist.
        func isLive(_ activity: Activity) -> Bool {
            guard masterEnabled else { return false }
            let config = config(for: activity)
            return config.enabled && !(config.presetID ?? "").isEmpty
        }
    }

    /// Wählbare Haltezeiten (Sekunden) für den Picker.
    static let sustainedOptions = [0, 15, 30, 60, 120, 300]

    /// Grace-Period nach Aktivitätsende, bevor das Auto-Override beendet wird —
    /// filtert kurze Pausen (Ampel, Verschnaufen). Auf 2 min gesenkt: überbrückt
    /// normale Ampelstopps, beendet aber ein (z. B. fälschlich gestartetes)
    /// Preset deutlich schneller als die früheren 5 min.
    static let autoEndGraceSeconds: TimeInterval = 120

    /// Flacker-Toleranz: Ein einzelnes Ereignis OHNE Ziel-Aktivität (kurze
    /// Fehlklassifikation während der Fahrt, z. B. „automotive"/„stationary")
    /// setzt den laufenden Countdown nicht sofort zurück — erst wenn so lange
    /// keine Ziel-Aktivität mehr gemeldet wird, gilt sie als beendet.
    static let dropGraceSeconds: TimeInterval = 30

    // MARK: - GPS-Speed-Gate (Rad vs. Auto)

    /// CoreMotions Rad-Erkennung ist auf dem iPhone (ohne Apple Watch) in beide
    /// Richtungen unzuverlässig: Echtes Radfahren wird oft als `automotive`
    /// gemeldet, und das `cycling`-Flag feuert gelegentlich fälschlich (z. B. bei
    /// langsamem, ungleichmäßigem Gehen). Deshalb gilt JEDES Rad-/Kfz-Signal nur
    /// als Kandidat — ob wirklich Radfahren, entscheidet allein die GPS-
    /// Geschwindigkeit. Die Schwellen sind bewusst konservativ und hier zentral
    /// änderbar.

    /// Untergrenze, ab der eine Geschwindigkeit als „radtypisch" zählt (km/h).
    /// Bewusst klar über Geh-/Lauf-Tempo (auch zügiges Gehen ~7 km/h), damit
    /// Gehen niemals als Radfahren durchgeht. Darunter: Stehen, Gehen, Ampel.
    static let cyclingSpeedMinKmh: Double = 12

    /// So viele Messwerte im radtypischen Band (≥ `cyclingSpeedMinKmh`,
    /// < `vehicleSpeedKmh`) müssen *anhaltend* zusammenkommen, bevor Radfahren
    /// als bestätigt gilt — ein einzelner GPS-Ausreißer (etwa beim Gehen) reicht
    /// damit nicht.
    static let cyclingSpeedSampleCount = 6

    /// Ab dieser Geschwindigkeit gilt die Fahrt als eindeutig motorisiert
    /// (km/h). Über Renn-Rad-Abfahrten (~kurzzeitig) liegend, damit eine kurze
    /// Abfahrt nicht sofort als Auto zählt — siehe Sample-Count.
    static let vehicleSpeedKmh: Double = 50

    /// So viele Messwerte ≥ `vehicleSpeedKmh` (in Folge der Messung gesammelt)
    /// werten die Fahrt endgültig als Kfz → Radfahren wird nicht aktiviert
    /// bzw. ein laufendes Rad-Override sofort beendet. ≈8 s anhaltend >50 km/h:
    /// ein Auto schafft das mühelos, eine kurze Rad-Abfahrt selten — schützt
    /// laufende Radfahrten vor Fehl-Abbruch.
    static let vehicleSpeedSampleCount = 8

    /// Wurde eine Fahrt als Kfz erkannt, bleibt das GPS-Gate so lange gesperrt
    /// (kein erneutes Anwerfen bei weiter gemeldetem `automotive`) — schont den
    /// Akku während echter Autofahrten.
    static let vehicleLockoutSeconds: TimeInterval = 600

    /// Kann das GPS-Verdikt beim Ablauf des Sustained-Countdowns noch nicht
    /// entscheiden (GPS kalt / zu wenig Bewegung), wird nach dieser Zeit erneut
    /// geprüft, statt die Fahrt zu verpassen.
    static let cyclingVerdictRetrySeconds: TimeInterval = 45

    /// Obergrenze für die GPS-Beobachtung eines Rad-Kandidaten ohne Ergebnis:
    /// Wird in dieser Zeit nie radtypisches Tempo erreicht (z. B. zäher Stau,
    /// „unknown" ohne Bewegung), gilt es nicht als Radfahren und das GPS wird
    /// abgeschaltet — schützt den Akku bei der bewusst breiten Kandidaten-Logik.
    static let cyclingObserveMaxSeconds: TimeInterval = 300

    private static let configKey = "iAPS.aiHubAutoPresets"

    /// Geändert-Notification: Settings-View postet nach jedem Schreiben,
    /// der Service re-evaluiert (Monitoring starten/stoppen).
    static let configChangedNotification = Notification.Name("iAPS.aiHubAutoPresetsConfigChanged")

    static func loadConfig() -> Config {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return .defaultConfig }
        return config
    }

    static func saveConfig(_ config: Config) {
        UserDefaults.standard.set(try? JSONEncoder().encode(config), forKey: configKey)
        Foundation.NotificationCenter.default.post(name: configChangedNotification, object: nil)
    }

    private static let sustainMigrationKey = "iAPS.aiHubAutoPresetsSustainMigratedV2"

    /// Einmalige Migration: Aktivitäten, die noch auf dem ALTEN Default stehen,
    /// werden auf den neuen Default gehoben (Gehen/Laufen 30→120, Rad 120→60).
    /// Bewusst abweichend gewählte Haltezeiten bleiben unangetastet. Läuft nur
    /// einmal und nur, wenn überhaupt schon eine Konfiguration gespeichert ist.
    static func migrateSustainDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: sustainMigrationKey) else { return }
        UserDefaults.standard.set(true, forKey: sustainMigrationKey)

        guard let data = UserDefaults.standard.data(forKey: configKey),
              var config = try? JSONDecoder().decode(Config.self, from: data)
        else { return }

        var changed = false
        for activity in Activity.allCases {
            guard var activityConfig = config.activities[activity.rawValue],
                  activityConfig.sustainedSeconds == activity.legacyDefaultSustainedSeconds
            else { continue }
            activityConfig.sustainedSeconds = activity.defaultSustainedSeconds
            config.activities[activity.rawValue] = activityConfig
            changed = true
        }
        if changed { saveConfig(config) }
    }
}
