import SwiftUI
import Swinject
import UniformTypeIdentifiers

/// Full-screen prompt shown the first time iAPS launches after install.
/// Lets the user restore from a backup file (created by the BackupSettings
/// export flow) or proceed with a fresh setup.
///
/// The caller (HomeRootView) is responsible for clearing the firstRun flag
/// in Core Data once `onDone` fires.
struct FirstRunRestorePromptView: View {
    let resolver: Resolver
    let onDone: () -> Void

    @State private var showFilePicker = false
    @State private var pendingURL: URL?
    @State private var summary: RestoreSummary?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                Text(BackupL10n.t("firstrun.welcome"))
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)

                Text(BackupL10n.t("firstrun.question"))
                    .multilineTextAlignment(.center)
                    .font(.body)

                Text(BackupL10n.t("firstrun.detail"))
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showFilePicker = true
                } label: {
                    Label(BackupL10n.t("firstrun.restore"), systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onDone) {
                    Text(BackupL10n.t("firstrun.fresh"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json]
        ) { result in
            if case let .success(url) = result {
                pendingURL = url
            }
        }
        .alert(
            BackupL10n.t("alert.restore.title"),
            isPresented: Binding(
                get: { pendingURL != nil },
                set: { if !$0 { pendingURL = nil } }
            ),
            presenting: pendingURL
        ) { _ in
            Button(BackupL10n.t("alert.restore.action"), role: .destructive, action: performRestore)
            Button("Cancel", role: .cancel) { pendingURL = nil }
        } message: { url in
            Text(BackupL10n.t("firstrun.confirm", url.lastPathComponent))
        }
        .alert(
            BackupL10n.t("alert.complete.title"),
            isPresented: Binding(
                get: { summary != nil },
                set: { _ in /* swallowed — user must use the Close button */ }
            ),
            presenting: summary
        ) { _ in
            Button(BackupL10n.t("alert.close"), role: .destructive) {
                // Mark onboarding done first so the prompt doesn't reappear
                // after the relaunch, then quit so the in-memory state models
                // can't overwrite the restored files with their defaults.
                CoreDataStorage().saveOnbarding()
                exit(0)
            }
        } message: { result in
            Text(summaryMessage(result))
        }
        .alert(
            BackupL10n.t("alert.failed.title"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - Actions

    private var backupService: BackupService {
        resolver.resolve(BackupService.self)!
    }

    private func performRestore() {
        guard let url = pendingURL else { return }
        pendingURL = nil

        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            // Validate by decoding through the backup service first.
            let bundle = try backupService.decode(from: data)
            // Stage the bundle for the next launch — actual file writes happen
            // in FreeAPSApp.init() via EarlyBackupRestore.applyIfPending(),
            // before any service is initialized.
            try EarlyBackupRestore.markPending(bundleData: data)
            summary = RestoreSummary(
                filesRestored: Array(bundle.files.keys),
                filesSkipped: BackupBundle.canonicalFiles.filter { bundle.files[$0] == nil },
                nightscoutRestored: bundle.includesNightscoutCredentials
            )
        } catch let error as BackupError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dismissSummary() {
        summary = nil
        onDone()
    }

    private func summaryMessage(_ summary: RestoreSummary) -> String {
        var parts: [String] = []
        parts.append(BackupL10n.t("summary.restored", summary.filesRestored.count))
        if summary.nightscoutRestored {
            parts.append(BackupL10n.t("summary.nightscout"))
        }
        parts.append("")
        parts.append(BackupL10n.t("firstrun.relaunch"))
        return parts.joined(separator: "\n")
    }
}
