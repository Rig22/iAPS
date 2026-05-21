import Combine
import Foundation
import SwiftUI

extension BackupSettings {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() private var backup: BackupService!

        @Published var autoBackupEnabled = false
        @Published var includeNightscoutCredentials = true
        @Published var selectedFolderDisplayPath: String?
        @Published var lastBackupAt: Date?

        // File ready to be passed to the share sheet (manual export).
        @Published var exportURL: URL?

        // Restore-flow state surfaced to the view.
        @Published var pendingRestoreURL: URL?
        @Published var restoreSummary: RestoreSummary?
        @Published var restoreErrorMessage: String?

        let rollingBackupCount = Config.rollingBackupCount

        override func subscribe() {
            subscribeSetting(\.autoBackupEnabled, on: $autoBackupEnabled) { autoBackupEnabled = $0 }
            subscribeSetting(\.backupIncludeNightscoutCredentials, on: $includeNightscoutCredentials) {
                includeNightscoutCredentials = $0
            }
            reloadStatus()
        }

        // MARK: - Actions

        /// Build a snapshot, write it to a temp file, and surface the URL for the share sheet.
        func exportNow() {
            let bundle = backup.collect(includingNightscoutCredentials: includeNightscoutCredentials)
            guard let data = try? backup.encode(bundle) else { return }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(BackupBundle.filename(for: bundle.createdAt))
            do {
                try data.write(to: url, options: .atomic)
                exportURL = url
                recordBackupTimestamp(bundle.createdAt)
            } catch {
                exportURL = nil
            }
        }

        /// Persist the user's chosen folder as a security-scoped bookmark so the
        /// auto-backup scheduler (Task #5) can write into it on later launches.
        func storeBackupFolder(_ url: URL) {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            if let bookmark = try? url.bookmarkData(
                options: [.minimalBookmark],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmark, forKey: Config.folderBookmarkKey)
            }
            UserDefaults.standard.set(url.path, forKey: Config.folderDisplayPathKey)
            selectedFolderDisplayPath = displayPath(for: url.path)
        }

        /// User picked a backup file via the file importer — stage it for confirmation.
        func stageRestore(from url: URL) {
            pendingRestoreURL = url
        }

        /// Stage the backup for the next app launch. The actual settings
        /// files are written by `EarlyBackupRestore.applyIfPending()` BEFORE
        /// any service is initialized — this eliminates the race where a
        /// runtime restore could be overwritten by in-memory caches.
        func confirmRestore() {
            guard let url = pendingRestoreURL else { return }
            pendingRestoreURL = nil

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)
                // Validate by decoding through the backup service. This
                // catches schema-version and malformed-bundle errors before
                // we tell the user the restore is queued.
                let bundle = try backup.decode(from: data)
                try EarlyBackupRestore.markPending(bundleData: data)
                // Surface a summary so the existing success-alert flow fires.
                // Counts are derived from the staged bundle so the user sees
                // how many files will be written on next launch.
                restoreSummary = RestoreSummary(
                    filesRestored: Array(bundle.files.keys),
                    filesSkipped: BackupBundle.canonicalFiles.filter { bundle.files[$0] == nil },
                    nightscoutRestored: bundle.includesNightscoutCredentials
                )
            } catch let error as BackupError {
                restoreErrorMessage = error.errorDescription
            } catch {
                restoreErrorMessage = error.localizedDescription
            }
        }

        func cancelRestore() {
            pendingRestoreURL = nil
        }

        func dismissRestoreSummary() {
            restoreSummary = nil
        }

        func dismissRestoreError() {
            restoreErrorMessage = nil
        }

        func clearExportURL() {
            exportURL = nil
        }

        // MARK: - Helpers

        private func recordBackupTimestamp(_ date: Date) {
            UserDefaults.standard.set(date, forKey: Config.lastBackupAtKey)
            lastBackupAt = date
        }

        private func reloadStatus() {
            lastBackupAt = UserDefaults.standard.object(forKey: Config.lastBackupAtKey) as? Date
            let stored = UserDefaults.standard.string(forKey: Config.folderDisplayPathKey)
            selectedFolderDisplayPath = stored.map { displayPath(for: $0) }
        }

        /// Convert an absolute folder path into something readable for the status line,
        /// e.g. "iCloud Drive › iAPS-Backups".
        private func displayPath(for path: String) -> String {
            let url = URL(fileURLWithPath: path)
            let components = url.pathComponents.filter { $0 != "/" }
            // Trim leading sandbox-y prefixes that aren't useful to the user.
            let trimmed = components.drop(while: { ["var", "mobile", "Containers", "Mobile Documents", "private"].contains($0) })
            let suffix = trimmed.suffix(3)
            return suffix.isEmpty ? url.lastPathComponent : suffix.joined(separator: " › ")
        }
    }
}
