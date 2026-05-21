import SwiftUI
import Swinject
import UniformTypeIdentifiers

extension BackupSettings {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel

        @State private var showFolderPicker = false
        @State private var showRestorePicker = false

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var body: some View {
            Form {
                statusSection
                manualSection
                automaticSection
                credentialsSection
                infoSection
            }
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $state.exportURL) { url in
                ShareSheet(activityItems: [url])
            }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder]
            ) { result in
                if case let .success(url) = result {
                    state.storeBackupFolder(url)
                }
            }
            .fileImporter(
                isPresented: $showRestorePicker,
                allowedContentTypes: [.json]
            ) { result in
                if case let .success(url) = result {
                    state.stageRestore(from: url)
                }
            }
            .alert(
                "Restore Backup?",
                isPresented: Binding(
                    get: { state.pendingRestoreURL != nil },
                    set: { if !$0 { state.cancelRestore() } }
                ),
                presenting: state.pendingRestoreURL
            ) { _ in
                Button("Restore", role: .destructive, action: state.confirmRestore)
                Button("Cancel", role: .cancel, action: state.cancelRestore)
            } message: { url in
                Text(
                    "This will overwrite all current settings with the contents of \(url.lastPathComponent). The app may need to be restarted."
                )
            }
            .alert(
                "Restore Complete",
                isPresented: Binding(
                    get: { state.restoreSummary != nil },
                    set: { _ in /* swallowed — the user must use the Close button */ }
                ),
                presenting: state.restoreSummary
            ) { _ in
                Button("Close iAPS", role: .destructive) {
                    // Quit immediately so the in-memory caches in the various
                    // state models don't overwrite the freshly restored files
                    // with their default values. The user reopens iAPS and all
                    // settings load cleanly from disk.
                    exit(0)
                }
            } message: { summary in
                Text(restoreSummaryMessage(summary))
            }
            .alert(
                "Restore Failed",
                isPresented: Binding(
                    get: { state.restoreErrorMessage != nil },
                    set: { if !$0 { state.dismissRestoreError() } }
                ),
                presenting: state.restoreErrorMessage
            ) { _ in
                Button("OK", action: state.dismissRestoreError)
            } message: { message in
                Text(message)
            }
        }

        // MARK: - Sections

        private var statusSection: some View {
            Section {
                HStack {
                    Text("Last backup")
                    Spacer()
                    Text(lastBackupText).foregroundColor(.secondary)
                }
                if let path = state.selectedFolderDisplayPath {
                    HStack {
                        Text("Folder")
                        Spacer()
                        Text(path).foregroundColor(.secondary).multilineTextAlignment(.trailing)
                    }
                }
            } header: { Text("Status") }
        }

        private var manualSection: some View {
            Section {
                Button {
                    state.exportNow()
                } label: {
                    Label("Export Backup Now", systemImage: "square.and.arrow.up")
                }
                Button {
                    showRestorePicker = true
                } label: {
                    Label("Restore from Backup", systemImage: "square.and.arrow.down")
                }
            } header: { Text("Manual") } footer: {
                Text(
                    "Export creates a JSON file you can share to iCloud Drive, Files, AirDrop or email. Restore replaces your current settings with the contents of a backup file."
                )
            }
        }

        private var automaticSection: some View {
            Section {
                Toggle("Automatic Backup", isOn: $state.autoBackupEnabled)
                if state.autoBackupEnabled {
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label(
                            state.selectedFolderDisplayPath == nil ? "Choose Backup Folder" : "Change Backup Folder",
                            systemImage: "folder.badge.plus"
                        )
                    }
                }
            } header: { Text("Automatic") } footer: {
                Text(
                    "When enabled, iAPS writes a backup daily and after settings changes into the folder you choose. Pick a folder in iCloud Drive so backups survive a reinstall. Keeps the most recent \(state.rollingBackupCount) backups."
                )
            }
        }

        private var credentialsSection: some View {
            Section {
                Toggle("Include Nightscout Credentials", isOn: $state.includeNightscoutCredentials)
            } header: { Text("Security") } footer: {
                Text(
                    "When on, your Nightscout URL and API secret are stored inside the backup file. Turn off if you plan to share the backup with someone else."
                )
            }
        }

        private var infoSection: some View {
            Section {} footer: {
                Text(
                    "Backup files contain all settings including Auto ISF, pump, basal, ISF, carb ratios, targets and UI preferences. Glucose history and pump events are not included."
                )
                .font(.footnote)
            }
        }

        // MARK: - Formatting helpers

        private var lastBackupText: String {
            guard let date = state.lastBackupAt else { return "never" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: Date())
        }

        private func restoreSummaryMessage(_ summary: RestoreSummary) -> String {
            var parts: [String] = []
            parts.append("\(summary.filesRestored.count) settings files will be restored on next launch.")
            if !summary.filesSkipped.isEmpty {
                parts.append("\(summary.filesSkipped.count) files were not present in the backup.")
            }
            if summary.nightscoutRestored {
                parts.append("Nightscout credentials will be restored.")
            }
            parts.append("")
            parts
                .append(
                    "iAPS will now close so the restored settings can load cleanly on the next launch. Reopen iAPS from the home screen."
                )
            return parts.joined(separator: "\n")
        }
    }
}

// Allow URL to drive `.sheet(item:)` so the export share sheet can be presented from a published URL.
extension URL: Identifiable {
    public var id: String { absoluteString }
}
