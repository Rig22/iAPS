import Foundation
import Swinject

protocol BackupService: AnyObject {
    /// Build a snapshot of the user's current settings.
    func collect(includingNightscoutCredentials: Bool) -> BackupBundle

    /// Serialize a bundle to JSON data ready to write to disk.
    func encode(_ bundle: BackupBundle) throws -> Data

    /// Parse a bundle from JSON data. Throws BackupError on schema mismatch or malformed input.
    func decode(from data: Data) throws -> BackupBundle

    /// Write the bundle back into FileStorage and (when opted in) the Keychain.
    /// Returns a summary describing which files were restored or skipped.
    @discardableResult func apply(_ bundle: BackupBundle, restoreNightscoutCredentials: Bool) -> RestoreSummary
}

/// Result of a restore operation. Useful for surfacing details to the user.
struct RestoreSummary {
    var filesRestored: [String] = []
    var filesSkipped: [String] = []
    var nightscoutRestored: Bool = false
}

enum BackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case malformedBackup(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return "Backup format version \(version) is not supported by this iAPS build."
        case .malformedBackup:
            return "The selected file is not a valid iAPS backup."
        }
    }
}

final class BaseBackupService: BackupService, Injectable {
    @Injected() private var storage: FileStorage!
    @Injected() private var keychain: Keychain!

    init(resolver: Resolver) {
        injectServices(resolver)
    }

    // MARK: - Collect

    func collect(includingNightscoutCredentials: Bool) -> BackupBundle {
        var files: [String: JSONValue] = [:]
        for path in BackupBundle.canonicalFiles {
            guard let raw = storage.retrieveRaw(path), !raw.isEmpty else { continue }
            guard let value = JSONValue.from(rawJSON: raw) else { continue }
            files[path] = value
        }

        let nightscout: BackupBundle.NightscoutCredentials? = includingNightscoutCredentials
            ? readNightscoutCredentials()
            : nil

        let overridePresets = PresetsBackup.collectOverridePresets()
        let mealPresets = PresetsBackup.collectMealPresets()
        let mealImages = PresetsBackup.collectMealImages()

        return BackupBundle(
            schemaVersion: BackupBundle.currentSchemaVersion,
            createdAt: Date(),
            appVersion: appVersion,
            appBuild: appBuild,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
            includesNightscoutCredentials: includingNightscoutCredentials && nightscout != nil,
            files: files,
            nightscout: nightscout,
            overridePresets: overridePresets.isEmpty ? nil : overridePresets,
            mealPresets: mealPresets.isEmpty ? nil : mealPresets,
            mealImages: mealImages.isEmpty ? nil : mealImages
        )
    }

    // MARK: - Encode / Decode

    func encode(_ bundle: BackupBundle) throws -> Data {
        try JSONCoding.encoder.encode(bundle)
    }

    func decode(from data: Data) throws -> BackupBundle {
        let bundle: BackupBundle
        do {
            bundle = try JSONCoding.decoder.decode(BackupBundle.self, from: data)
        } catch {
            throw BackupError.malformedBackup(underlying: error)
        }
        guard bundle.schemaVersion <= BackupBundle.currentSchemaVersion else {
            throw BackupError.unsupportedSchemaVersion(bundle.schemaVersion)
        }
        return bundle
    }

    // MARK: - Apply (Restore)

    @discardableResult func apply(_ bundle: BackupBundle, restoreNightscoutCredentials: Bool) -> RestoreSummary {
        NSLog("[Backup] === restore starting — bundle has \(bundle.files.count) files ===")
        var summary = RestoreSummary()

        for path in BackupBundle.canonicalFiles {
            restoreFile(path: path, value: bundle.files[path], summary: &summary)
        }

        // Restore any extra files in the bundle that aren't in our canonical list
        // (e.g. files added by a newer iAPS version). Keeps the bundle future-tolerant.
        for (path, value) in bundle.files where !BackupBundle.canonicalFiles.contains(path) {
            restoreFile(path: path, value: value, summary: &summary)
        }

        if restoreNightscoutCredentials, let credentials = bundle.nightscout {
            writeNightscoutCredentials(credentials)
            NSLog("[Backup] NIGHTSCOUT credentials restored")
            summary.nightscoutRestored = true
        }

        if let overridePresets = bundle.overridePresets {
            PresetsBackup.restoreOverridePresets(overridePresets)
            NSLog("[Backup] restored \(overridePresets.count) override presets")
        }

        if let mealPresets = bundle.mealPresets {
            PresetsBackup.restoreMealPresets(mealPresets)
            NSLog("[Backup] restored \(mealPresets.count) meal presets")
        }

        if let mealImages = bundle.mealImages {
            PresetsBackup.restoreMealImages(mealImages)
            NSLog("[Backup] restored \(mealImages.count) meal images")
        }

        NSLog(
            "[Backup] === restore finished — \(summary.filesRestored.count) restored, \(summary.filesSkipped.count) skipped ==="
        )

        // No SettingsManager.reloadFromDisk() — the caller is expected to
        // call exit(0) so the next launch reads everything from disk cleanly.
        return summary
    }

    /// Restore a single file. For known typed paths the JSON is first parsed
    /// into the corresponding iAPS struct and saved through that struct's own
    /// encoder — this guarantees the on-disk format matches exactly what iAPS
    /// produces itself. For unknown paths the raw JSON string is written as-is.
    ///
    /// IMPORTANT: nothing here touches SettingsManager's in-memory cache or
    /// triggers a broadcast. The caller is expected to terminate the app
    /// (exit(0)) after the restore so the next launch can read everything
    /// cleanly from disk without any stale-cache races.
    private func restoreFile(path: String, value: JSONValue?, summary: inout RestoreSummary) {
        guard let value = value, let raw = value.rawJSON else {
            NSLog("[Backup] SKIP \(path) (not in bundle or empty)")
            summary.filesSkipped.append(path)
            return
        }

        if let typedDescription = restoreTypedIfPossible(path: path, raw: raw) {
            NSLog("[Backup] TYPED \(path) as \(typedDescription)")
            summary.filesRestored.append(path)
            return
        }

        // Generic fallback for paths without a known typed model.
        storage.save(raw, as: path)
        NSLog("[Backup] RAW \(path) (\(raw.count) bytes)")
        summary.filesRestored.append(path)
    }

    /// Decode the raw JSON into the matching iAPS struct and write it back
    /// through that struct's encoder. Returns the type name if successful,
    /// nil if the caller should fall back to a raw write.
    private func restoreTypedIfPossible(path: String, raw: RawJSON) -> String? {
        switch path {
        case OpenAPS.FreeAPS.settings:
            if let typed = FreeAPSSettings(from: raw) {
                storage.save(typed, as: path)
                return "FreeAPSSettings"
            }
        case OpenAPS.Settings.preferences:
            if let typed = Preferences(from: raw) {
                storage.save(typed, as: path)
                return "Preferences"
            }
        case OpenAPS.Settings.settings:
            if let typed = PumpSettings(from: raw) {
                storage.save(typed, as: path)
                return "PumpSettings"
            }
        case OpenAPS.Settings.bgTargets:
            if let typed = BGTargets(from: raw) {
                storage.save(typed, as: path)
                return "BGTargets"
            }
        case OpenAPS.Settings.insulinSensitivities:
            if let typed = InsulinSensitivities(from: raw) {
                storage.save(typed, as: path)
                return "InsulinSensitivities"
            }
        case OpenAPS.Settings.carbRatios:
            if let typed = CarbRatios(from: raw) {
                storage.save(typed, as: path)
                return "CarbRatios"
            }
        case OpenAPS.Settings.basalProfile:
            if let typed = [BasalProfileEntry](from: raw) {
                storage.save(typed, as: path)
                return "[BasalProfileEntry]"
            }
        case OpenAPS.Settings.tempTargets:
            if let typed = [TempTarget](from: raw) {
                storage.save(typed, as: path)
                return "[TempTarget]"
            }
        case OpenAPS.FreeAPS.tempTargetsPresets:
            if let typed = [TempTarget](from: raw) {
                storage.save(typed, as: path)
                return "[TempTarget]"
            }
        default:
            break
        }
        return nil
    }

    // MARK: - Nightscout Keychain

    private func readNightscoutCredentials() -> BackupBundle.NightscoutCredentials? {
        let url = keychain.getValue(String.self, forKey: NightscoutConfig.Config.urlKey)
        let secret = keychain.getValue(String.self, forKey: NightscoutConfig.Config.secretKey)
        guard url != nil || secret != nil else { return nil }
        return .init(url: url, secret: secret)
    }

    private func writeNightscoutCredentials(_ credentials: BackupBundle.NightscoutCredentials) {
        keychain.setValue(credentials.url, forKey: NightscoutConfig.Config.urlKey)
        keychain.setValue(credentials.secret, forKey: NightscoutConfig.Config.secretKey)
    }

    // MARK: - App metadata

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
}
