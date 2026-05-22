import Foundation

/// Two-phase backup restore that runs BEFORE any service is initialized.
///
/// Why this exists:
/// Running the restore at runtime while SettingsManager, NightscoutManager,
/// DeviceDataManager, FetchTreatmentsManager etc. are already alive is racy.
/// Any one of them might cache default settings in memory and flush them back
/// to disk between our `storage.save()` calls and `exit(0)`, overwriting the
/// freshly restored files non-deterministically.
///
/// To make the restore deterministic we split it in two phases:
///
/// 1. **Mark phase** — at user interaction time, the UI calls
///    `EarlyBackupRestore.markPending(bundleData:)`. We just copy the bundle
///    file into a reserved location (`pending_restore.json` in Documents
///    root) and set a UserDefaults flag, then `exit(0)`. No settings are
///    touched yet.
///
/// 2. **Apply phase** — at the next app launch, `applyIfPending()` is called
///    from `FreeAPSApp.init()` *before* the Swinject assembler has been
///    triggered. We read the pending bundle, write all the settings files
///    directly through the `Disk` API, then delete the pending file and
///    clear the flag. Only after this returns does the rest of iAPS spin up,
///    and every service reads our restored values from disk on first access.
enum EarlyBackupRestore {
    private static let pendingFilename = "pending_restore.json"
    private static let pendingFlagKey = "iAPS.pendingRestore"

    // MARK: - Mark phase

    /// Stage the bundle to be applied on the next app launch.
    /// `bundleData` is the raw JSON of the BackupBundle (same format the user
    /// picks via the file importer).
    static func markPending(bundleData: Data) throws {
        // Sanity-check: must decode as a BackupBundle. If decoding fails we
        // never get a chance to surface that on next launch (no UI yet), so
        // we validate here and let the caller show the error.
        let bundle = try JSONCoding.decoder.decode(BackupBundle.self, from: bundleData)
        guard bundle.schemaVersion <= BackupBundle.currentSchemaVersion else {
            throw BackupError.unsupportedSchemaVersion(bundle.schemaVersion)
        }

        try Disk.save(bundleData, to: .documents, as: pendingFilename)
        UserDefaults.standard.set(true, forKey: pendingFlagKey)
        NSLog("[Backup] pending restore staged (\(bundleData.count) bytes, \(bundle.files.count) files)")
    }

    /// Whether a restore is currently staged. Useful for UI hints.
    static var hasPending: Bool {
        UserDefaults.standard.bool(forKey: pendingFlagKey)
    }

    // MARK: - Apply phase

    /// Called from FreeAPSApp.init() before any Swinject assembly runs.
    /// If a pending restore exists, write all settings files to disk and
    /// clear the flag. Safe to call unconditionally — does nothing if no
    /// restore is pending.
    static func applyIfPending() {
        guard UserDefaults.standard.bool(forKey: pendingFlagKey) else { return }

        NSLog("[Backup] === early restore phase running ===")
        defer {
            UserDefaults.standard.removeObject(forKey: pendingFlagKey)
            try? Disk.remove(pendingFilename, from: .documents)
        }

        let data: Data
        do {
            data = try Disk.retrieve(pendingFilename, from: .documents, as: Data.self)
        } catch {
            NSLog("[Backup] early restore aborted: cannot read pending file: \(error)")
            return
        }

        let bundle: BackupBundle
        do {
            bundle = try JSONCoding.decoder.decode(BackupBundle.self, from: data)
        } catch {
            NSLog("[Backup] early restore aborted: cannot decode bundle: \(error)")
            return
        }

        var restoredCount = 0
        var skippedCount = 0

        for path in BackupBundle.canonicalFiles {
            guard let value = bundle.files[path] else {
                skippedCount += 1
                continue
            }
            if writeValue(value, to: path, hint: "canonical") {
                restoredCount += 1
            } else {
                skippedCount += 1
            }
        }

        for (path, value) in bundle.files where !BackupBundle.canonicalFiles.contains(path) {
            if writeValue(value, to: path, hint: "extra") {
                restoredCount += 1
            }
        }

        if bundle.includesNightscoutCredentials, let credentials = bundle.nightscout {
            // BaseKeychain is a thin SecItem wrapper with no Swinject deps —
            // safe to instantiate directly during early restore.
            let keychain = BaseKeychain()
            if let url = credentials.url {
                keychain.setValue(url, forKey: NightscoutConfig.Config.urlKey)
            }
            if let secret = credentials.secret {
                keychain.setValue(secret, forKey: NightscoutConfig.Config.secretKey)
            }
            NSLog("[Backup] early restore: nightscout credentials restored")
        }

        if let overridePresets = bundle.overridePresets {
            PresetsBackup.restoreOverridePresets(overridePresets)
            NSLog("[Backup] early restore: \(overridePresets.count) override presets restored")
        }

        if let mealPresets = bundle.mealPresets {
            PresetsBackup.restoreMealPresets(mealPresets)
            NSLog("[Backup] early restore: \(mealPresets.count) meal presets restored")
        }

        if let mealImages = bundle.mealImages {
            PresetsBackup.restoreMealImages(mealImages)
            NSLog("[Backup] early restore: \(mealImages.count) meal images restored")
        }

        NSLog("[Backup] === early restore done — \(restoredCount) restored, \(skippedCount) skipped ===")
    }

    // MARK: - Internals

    /// Write a single JSONValue to its target path. Tries typed roundtrip
    /// first (so the on-disk format matches what iAPS itself produces) and
    /// falls back to raw JSON if the typed init fails.
    private static func writeValue(_ value: JSONValue, to path: String, hint: String) -> Bool {
        guard let raw = value.rawJSON, let data = raw.data(using: .utf8) else {
            NSLog("[Backup] early restore SKIP \(path) (\(hint)) — cannot encode")
            return false
        }

        if let typeName = writeTyped(raw: raw, to: path) {
            NSLog("[Backup] early restore TYPED \(path) as \(typeName)")
            return true
        }

        do {
            try Disk.save(data, to: .documents, as: path)
            NSLog("[Backup] early restore RAW \(path) (\(data.count) bytes)")
            return true
        } catch {
            NSLog("[Backup] early restore FAIL \(path): \(error)")
            return false
        }
    }

    /// Try to decode + re-encode through the matching iAPS struct so the
    /// file on disk matches iAPS's native format byte-for-byte.
    private static func writeTyped(raw: RawJSON, to path: String) -> String? {
        switch path {
        case OpenAPS.FreeAPS.settings:
            if let typed = FreeAPSSettings(from: raw), saveTyped(typed, as: path) {
                return "FreeAPSSettings"
            }
        case OpenAPS.Settings.preferences:
            if let typed = Preferences(from: raw), saveTyped(typed, as: path) {
                return "Preferences"
            }
        case OpenAPS.Settings.settings:
            if let typed = PumpSettings(from: raw), saveTyped(typed, as: path) {
                return "PumpSettings"
            }
        case OpenAPS.Settings.bgTargets:
            if let typed = BGTargets(from: raw), saveTyped(typed, as: path) {
                return "BGTargets"
            }
        case OpenAPS.Settings.insulinSensitivities:
            if let typed = InsulinSensitivities(from: raw), saveTyped(typed, as: path) {
                return "InsulinSensitivities"
            }
        case OpenAPS.Settings.carbRatios:
            if let typed = CarbRatios(from: raw), saveTyped(typed, as: path) {
                return "CarbRatios"
            }
        case OpenAPS.Settings.basalProfile:
            if let typed = [BasalProfileEntry](from: raw), saveTyped(typed, as: path) {
                return "[BasalProfileEntry]"
            }
        case OpenAPS.FreeAPS.tempTargetsPresets,
             OpenAPS.Settings.tempTargets:
            if let typed = [TempTarget](from: raw), saveTyped(typed, as: path) {
                return "[TempTarget]"
            }
        default:
            break
        }
        return nil
    }

    /// Encode a JSON-conforming value with iAPS's standard encoder and write
    /// it to disk via Disk. Returns whether the write succeeded.
    private static func saveTyped<T: JSON>(_ value: T, as path: String) -> Bool {
        do {
            let data = try JSONCoding.encoder.encode(value)
            try Disk.save(data, to: .documents, as: path)
            return true
        } catch {
            NSLog("[Backup] early restore typed-save failed for \(path): \(error)")
            return false
        }
    }
}
