import SwiftUI

// MARK: - View model

final class AIHubPresetDesignerViewModel: ObservableObject {
    @Published var input = ""
    @Published var isGenerating = false
    @Published var requestStartedAt: Date?
    @Published var errorText: String?
    @Published var resultText: String?
    @Published var proposal: AIHubPresetDesigner.Proposal?
    @Published var saved = false

    var canGenerate: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    func generate() {
        let situation = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !situation.isEmpty, !isGenerating else { return }
        errorText = nil
        resultText = nil
        proposal = nil
        saved = false
        isGenerating = true
        requestStartedAt = Date()

        Task { @MainActor in
            do {
                let prompt = await Task.detached(priority: .userInitiated) {
                    AIHubPresetDesigner.buildPrompt(situation: situation)
                }.value
                let reply = try await AIHubChatService.executePrompt(prompt)
                let parsed = AIHubPresetDesigner.parseReply(reply)
                resultText = parsed.text.isEmpty ? nil : parsed.text
                proposal = parsed.proposal
                if parsed.proposal == nil {
                    errorText = hubT("pd.error.parse")
                }
            } catch {
                errorText = error.localizedDescription
            }
            isGenerating = false
            requestStartedAt = nil
        }
    }

    func save() {
        guard let proposal, !saved else { return }
        AIHubPresetDesigner.save(proposal) { [weak self] in
            self?.saved = true
        }
    }
}

// MARK: - View

struct AIHubPresetDesignerView: View {
    @StateObject private var model = AIHubPresetDesignerViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var inputFocused: Bool

    // In .onAppear aktualisiert — eager NavigationLink-Destination,
    // siehe AIHubChatView.
    @State private var isConfigured = AIHubChatService.isConfigured
    @State private var isMmol = false

    private let chipKeys = ["pd.chip.sport", "pd.chip.illness", "pd.chip.travel", "pd.chip.stress"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isConfigured {
                    intro
                    chips
                    inputArea
                    if model.isGenerating { generatingRow }
                    if let error = model.errorText { errorRow(error) }
                    if let text = model.resultText, !model.isGenerating { explanationCard(text) }
                    if let proposal = model.proposal, !model.isGenerating { proposalCard(proposal) }
                    disclaimer
                } else {
                    missingKeyNotice
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            Color(colorScheme == .dark ? .systemBackground : .secondarySystemBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("Preset Designer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isConfigured = AIHubChatService.isConfigured
            isMmol = AIHubPresetDesigner.isMmol
        }
    }

    // MARK: - Bausteine

    private var intro: some View {
        Text(hubT("pd.intro"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chipKeys, id: \.self) { key in
                    Button {
                        model.input = hubT(key) + ": "
                        inputFocused = true
                    } label: {
                        Text(hubT(key))
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.orange.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(hubT("pd.placeholder"), text: $model.input, axis: .vertical)
                .lineLimit(2 ... 5)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
                )
            Button {
                inputFocused = false
                model.generate()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(model.isGenerating ? hubT("pd.generating") : hubT("pd.generate"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(model.canGenerate ? Color.orange.opacity(0.85) : Color.secondary.opacity(0.2))
                )
                .foregroundStyle(model.canGenerate ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!model.canGenerate)
        }
    }

    private var generatingRow: some View {
        HStack(spacing: 8) {
            PulsingDot(color: .green)
            Text(hubT("pd.generating"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let started = model.requestStartedAt {
                TimelineView(.periodic(from: started, by: 1)) { timeline in
                    Text("\(max(0, Int(timeline.date.timeIntervalSince(started)))) s")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func errorRow(_ error: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 4)
    }

    private func explanationCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
            )
    }

    private func proposalCard(_ proposal: AIHubPresetDesigner.Proposal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(proposal.emoji)
                    .font(.title2)
                Text(proposal.name)
                    .font(.headline)
                Spacer()
            }
            VStack(spacing: 8) {
                valueRow(label: hubT("pd.percent"), value: "\(Int(proposal.percentage)) %")
                valueRow(
                    label: hubT("pd.target"),
                    value: proposal.targetMgdl.map {
                        AIHubPresetDesigner.formatTarget($0, isMmol: isMmol)
                    } ?? hubT("pd.target.profile")
                )
                valueRow(
                    label: hubT("pd.duration"),
                    value: proposal.indefinite
                        ? hubT("pd.duration.indefinite")
                        : AIHubPresetDesigner.formatDuration(minutes: proposal.durationMinutes)
                )
                valueRow(label: "SMB", value: proposal.smbOff ? hubT("pd.off") : hubT("pd.on"))
            }

            if model.saved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hubT("pd.saved"))
                            .font(.subheadline.bold())
                        Text(hubT("pd.saved.hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            } else {
                Button {
                    model.save()
                } label: {
                    Text(hubT("pd.save"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.green.opacity(0.85))
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.15 : 0.08))
        )
    }

    private func valueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var disclaimer: some View {
        Text(hubT("pd.disclaimer"))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var missingKeyNotice: some View {
        VStack(spacing: 14) {
            Image(systemName: "key.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(hubT("chat.nokey.title"))
                .font(.title3.bold())
            Text(hubT("chat.nokey.text"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            NavigationLink(destination: AIHubSettingsView()) {
                Text(hubT("chat.nokey.button"))
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.purple.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
