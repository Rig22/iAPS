import Foundation

/// Top-level container for the iAPS settings backup file.
/// Written as `iaps-backup-YYYYMMDD-HHmm.json` either via the share-sheet
/// (manual export) or into a user-picked external folder (automatic backup).
/// The file lives outside the app sandbox so it survives a full reinstall.
struct BackupBundle: Codable, Sendable {
    static let currentSchemaVersion: Int = 1

    var schemaVersion: Int
    var createdAt: Date
    var appVersion: String
    var appBuild: String
    var bundleIdentifier: String
    var includesNightscoutCredentials: Bool

    /// Maps the canonical relative file path (as defined in OpenAPS.Settings /
    /// OpenAPS.FreeAPS constants) to the parsed JSON content of that file.
    /// Unknown keys are preserved on roundtrip so the format scales when iAPS
    /// introduces new settings files.
    var files: [String: JSONValue]

    /// Nightscout URL/secret read from the Keychain. Only populated when the
    /// user opted in at backup time. Omitted from JSON when nil.
    var nightscout: NightscoutCredentials?

    /// User-created override profile presets, captured from Core Data.
    /// Optional so older bundles (without this section) still decode cleanly.
    var overridePresets: [BackupOverridePreset]?

    /// User-created meal presets, captured from Core Data. Optional for the
    /// same reason as overridePresets.
    var mealPresets: [BackupMealPreset]?

    struct NightscoutCredentials: Codable, Sendable {
        var url: String?
        var secret: String?
    }
}

extension BackupBundle {
    /// Canonical list of files captured by the BackupService.
    /// Restore writes back in this order so dependent files stay consistent
    /// (preferences first, then per-profile values, then UI/presets).
    static let canonicalFiles: [String] = [
        OpenAPS.Settings.preferences,
        OpenAPS.FreeAPS.settings,
        OpenAPS.Settings.settings,
        OpenAPS.Settings.basalProfile,
        OpenAPS.Settings.carbRatios,
        OpenAPS.Settings.insulinSensitivities,
        OpenAPS.Settings.bgTargets,
        OpenAPS.Settings.tempTargets,
        OpenAPS.Settings.autotune,
        OpenAPS.Settings.autosense,
        OpenAPS.Settings.profile,
        OpenAPS.Settings.pumpProfile,
        OpenAPS.Settings.model,
        OpenAPS.Settings.contactTrick,
        OpenAPS.Settings.autoisf,
        OpenAPS.FreeAPS.tempTargetsPresets,
        OpenAPS.FreeAPS.calibrations
    ]

    /// Suggested filename for a backup taken at the given moment.
    /// Format: `iaps-backup-YYYYMMDD-HHmm.json` — sortable, no spaces.
    static func filename(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "iaps-backup-\(formatter.string(from: date)).json"
    }
}
