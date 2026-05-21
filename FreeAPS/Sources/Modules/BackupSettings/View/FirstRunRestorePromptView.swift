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

                Text("Welcome to iAPS")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)

                Text("Do you have a backup of your settings from a previous install?")
                    .multilineTextAlignment(.center)
                    .font(.body)

                Text(
                    "Restoring brings back all your preferences including Auto ISF, pump settings, basal profile, ISF, carb ratios, targets and UI."
                )
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
                    Label("Restore from Backup File", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onDone) {
                    Text("Start Fresh")
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
            "Restore Backup?",
            isPresented: Binding(
                get: { pendingURL != nil },
                set: { if !$0 { pendingURL = nil } }
            ),
            presenting: pendingURL
        ) { _ in
            Button("Restore", role: .destructive, action: performRestore)
            Button("Cancel", role: .cancel) { pendingURL = nil }
        } message: { url in
            Text("This will write the settings from \(url.lastPathComponent) into iAPS. Continue?")
        }
        .alert(
            "Restore Complete",
            isPresented: Binding(
                get: { summary != nil },
                set: { _ in /* swallowed — user must use the Close button */ }
            ),
            presenting: summary
        ) { _ in
            Button("Close iAPS", role: .destructive) {
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
            "Restore Failed",
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
        parts.append("\(summary.filesRestored.count) settings files will be restored on next launch.")
        if summary.nightscoutRestored {
            parts.append("Nightscout credentials will be restored.")
        }
        parts.append("")
        parts
            .append(
                "iAPS will now close. Reopen it from the home screen — your settings load cleanly before anything else runs."
            )
        return parts.joined(separator: "\n")
    }
}
