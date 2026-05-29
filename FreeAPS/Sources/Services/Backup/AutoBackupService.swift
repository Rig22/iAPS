import Combine
import Foundation
import Swinject

/// Long-lived service that writes a backup file into the user's chosen
/// external folder on two triggers:
///
/// - **Daily** — at app launch (and `checkDailyTrigger()`) if the last
///   recorded backup is older than 24 hours.
/// - **Settings change** — debounced; multiple toggles within a 10s window
///   collapse into a single write at the end of the burst.
///
/// Keeps at most `BackupSettings.Config.rollingBackupCount` backup files in
/// the target folder, pruning the oldest by modification date.
///
/// The folder is referenced by a security-scoped bookmark stored in
/// UserDefaults under `BackupSettings.Config.folderBookmarkKey`, which the
/// UI populates via `BackupSettings.StateModel.storeBackupFolder(_:)`.
protocol AutoBackupService: AnyObject {
    /// Re-evaluate the daily trigger. Safe to call repeatedly — does nothing
    /// if the last backup is younger than 24 hours.
    func checkDailyTrigger()

    /// Write a backup right now, bypassing the daily-throttle. Useful right
    /// after the user picks the folder so they get instant confirmation that
    /// the auto-backup loop actually works.
    func triggerNow()
}

final class BaseAutoBackupService: AutoBackupService, Injectable {
    @Injected() private var backup: BackupService!
    @Injected() private var broadcaster: Broadcaster!
    @Injected() private var settingsManager: SettingsManager!

    private let writeQueue = DispatchQueue(label: "AutoBackup.write", qos: .utility)
    private let settingsChangeSubject = PassthroughSubject<Void, Never>()
    private var settingsChangeDebouncer: AnyCancellable?

    private enum Trigger: String {
        case daily
        case settingsChange = "settings-change"
        case manual
    }

    init(resolver: Resolver) {
        injectServices(resolver)

        broadcaster.register(SettingsObserver.self, observer: self)

        // Debounce settings-change events: a flurry of toggles inside the
        // window collapses into a single write at the end.
        settingsChangeDebouncer = settingsChangeSubject
            .debounce(for: .seconds(10), scheduler: writeQueue)
            .sink { [weak self] in
                self?.performBackup(trigger: .settingsChange)
            }

        // Daily check on launch. Async so init returns immediately and we
        // never block app start on a (possibly slow) iCloud-Drive write.
        writeQueue.async { [weak self] in
            self?.performBackup(trigger: .daily)
        }
    }

    func checkDailyTrigger() {
        writeQueue.async { [weak self] in
            self?.performBackup(trigger: .daily)
        }
    }

    func triggerNow() {
        writeQueue.async { [weak self] in
            self?.performBackup(trigger: .manual)
        }
    }

    // MARK: - Core

    private func performBackup(trigger: Trigger) {
        guard settingsManager.settings.autoBackupEnabled else { return }
        if trigger == .daily, !shouldRunDaily { return }

        guard let folderURL = resolveBackupFolder() else {
            NSLog("[AutoBackup] skip \(trigger.rawValue): no folder configured or bookmark unresolvable")
            return
        }

        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if didAccess { folderURL.stopAccessingSecurityScopedResource() } }

        let includeNS = settingsManager.settings.backupIncludeNightscoutCredentials
        let bundle = backup.collect(includingNightscoutCredentials: includeNS)

        let data: Data
        do {
            data = try backup.encode(bundle)
        } catch {
            NSLog("[AutoBackup] skip \(trigger.rawValue): encode failed: \(error)")
            return
        }

        let filename = BackupBundle.filename(for: bundle.createdAt)
        let fileURL = folderURL.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL, options: .atomic)
            NSLog("[AutoBackup] wrote \(filename) (\(data.count) bytes) trigger=\(trigger.rawValue)")
        } catch {
            NSLog("[AutoBackup] write failed: \(error)")
            return
        }

        UserDefaults.standard.set(bundle.createdAt, forKey: BackupSettings.Config.lastBackupAtKey)
        pruneOldBackups(in: folderURL)
    }

    private var shouldRunDaily: Bool {
        let last = UserDefaults.standard.object(forKey: BackupSettings.Config.lastBackupAtKey) as? Date
        guard let last else { return true }
        return Date().timeIntervalSince(last) > 24 * 3600
    }

    private func resolveBackupFolder() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: BackupSettings.Config.folderBookmarkKey) else {
            return nil
        }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                NSLog("[AutoBackup] bookmark is stale — user should re-pick the backup folder")
            }
            return url
        } catch {
            NSLog("[AutoBackup] cannot resolve bookmark: \(error)")
            return nil
        }
    }

    private func pruneOldBackups(in folderURL: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let backups = contents
            .filter { $0.lastPathComponent.hasPrefix("iaps-backup-") && $0.pathExtension == "json" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                    ?? Date.distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                    ?? Date.distantPast
                return a > b // newest first
            }

        let keep = BackupSettings.Config.rollingBackupCount
        guard backups.count > keep else { return }
        for url in backups.dropFirst(keep) {
            try? fm.removeItem(at: url)
            NSLog("[AutoBackup] pruned \(url.lastPathComponent)")
        }
    }
}

extension BaseAutoBackupService: SettingsObserver {
    func settingsDidChange(_ settings: FreeAPSSettings) {
        guard settings.autoBackupEnabled else { return }
        settingsChangeSubject.send(())
    }
}
