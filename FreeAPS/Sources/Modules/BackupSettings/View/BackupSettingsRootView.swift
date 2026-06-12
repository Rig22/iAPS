import SwiftUI
import Swinject
import UniformTypeIdentifiers

extension BackupSettings {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel

        // Single picker state — SwiftUI breaks when more than one `.fileImporter`
        // is attached to the same view, so we drive a single importer via a
        // mode enum and present it for either folder or file picking.
        private enum PickerMode {
            case folder
            case restore
        }

        @State private var pickerMode: PickerMode = .folder
        @State private var showPicker = false

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
            .navigationTitle(BackupL10n.t("title"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $state.exportURL) { url in
                ShareSheet(activityItems: [url])
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: pickerMode == .folder ? [.folder] : [.json]
            ) { result in
                let mode = pickerMode
                switch result {
                case let .success(url):
                    NSLog("[Backup] picker SUCCESS mode=\(mode) url=\(url.path)")
                    switch mode {
                    case .folder:
                        state.storeBackupFolder(url)
                    case .restore:
                        state.stageRestore(from: url)
                    }
                case let .failure(error):
                    NSLog("[Backup] picker FAILED mode=\(mode): \(error)")
                }
            }
            .alert(
                BackupL10n.t("alert.restore.title"),
                isPresented: Binding(
                    get: { state.pendingRestoreURL != nil },
                    set: { if !$0 { state.cancelRestore() } }
                ),
                presenting: state.pendingRestoreURL
            ) { _ in
                Button(BackupL10n.t("alert.restore.action"), role: .destructive, action: state.confirmRestore)
                Button("Cancel", role: .cancel, action: state.cancelRestore)
            } message: { url in
                Text(BackupL10n.t("alert.restore.message", url.lastPathComponent))
            }
            .alert(
                BackupL10n.t("alert.complete.title"),
                isPresented: Binding(
                    get: { state.restoreSummary != nil },
                    set: { _ in /* swallowed — the user must use the Close button */ }
                ),
                presenting: state.restoreSummary
            ) { _ in
                Button(BackupL10n.t("alert.close"), role: .destructive) {
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
                BackupL10n.t("alert.failed.title"),
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
            .alert(
                BackupL10n.t("alert.folder.title"),
                isPresented: Binding(
                    get: { state.folderPickError != nil },
                    set: { if !$0 { state.dismissFolderPickError() } }
                ),
                presenting: state.folderPickError
            ) { _ in
                Button("OK", action: state.dismissFolderPickError)
            } message: { message in
                Text(BackupL10n.t("alert.folder.message", message))
            }
        }

        // MARK: - Sections

        private var statusSection: some View {
            Section {
                HStack {
                    Text(BackupL10n.t("status.last"))
                    Spacer()
                    Text(lastBackupText).foregroundColor(.secondary)
                }
                if let path = state.selectedFolderDisplayPath {
                    HStack {
                        Text(BackupL10n.t("status.folder"))
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
                    Label(BackupL10n.t("manual.export"), systemImage: "square.and.arrow.up")
                }
                Button {
                    pickerMode = .restore
                    showPicker = true
                } label: {
                    Label(BackupL10n.t("manual.restore"), systemImage: "square.and.arrow.down")
                }
            } header: { Text("Manual") } footer: {
                Text(BackupL10n.t("manual.footer"))
            }
        }

        private var automaticSection: some View {
            Section {
                Toggle(BackupL10n.t("auto.toggle"), isOn: $state.autoBackupEnabled)
                if state.autoBackupEnabled {
                    Button {
                        pickerMode = .folder
                        showPicker = true
                    } label: {
                        Label(
                            state.selectedFolderDisplayPath == nil ? BackupL10n.t("auto.choose") : BackupL10n
                                .t("auto.change"),
                            systemImage: "folder.badge.plus"
                        )
                    }
                }
            } header: { Text("Automatic") } footer: {
                Text(BackupL10n.t("auto.footer", state.rollingBackupCount))
            }
        }

        private var credentialsSection: some View {
            Section {
                Toggle(BackupL10n.t("security.toggle"), isOn: $state.includeNightscoutCredentials)
            } header: { Text(BackupL10n.t("security.header")) } footer: {
                Text(BackupL10n.t("security.footer"))
            }
        }

        private var infoSection: some View {
            Section {} footer: {
                Text(BackupL10n.t("info.footer"))
                    .font(.footnote)
            }
        }

        // MARK: - Formatting helpers

        private var lastBackupText: String {
            guard let date = state.lastBackupAt else { return BackupL10n.t("status.never") }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: Date())
        }

        private func restoreSummaryMessage(_ summary: RestoreSummary) -> String {
            var parts: [String] = []
            parts.append(BackupL10n.t("summary.restored", summary.filesRestored.count))
            if !summary.filesSkipped.isEmpty {
                parts.append(BackupL10n.t("summary.skipped", summary.filesSkipped.count))
            }
            if summary.nightscoutRestored {
                parts.append(BackupL10n.t("summary.nightscout"))
            }
            parts.append("")
            parts.append(BackupL10n.t("summary.relaunch"))
            return parts.joined(separator: "\n")
        }
    }
}

// Allow URL to drive `.sheet(item:)` so the export share sheet can be presented from a published URL.
extension URL: Identifiable {
    public var id: String { absoluteString }
}
