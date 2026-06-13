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

    // Preset-Review (deterministisch, braucht keinen API-Key — deshalb
    // auch im Kein-Key-Zweig sichtbar)
    @State private var reviewResult: AIHubPresetReview.Result?
    @State private var applyAllowed = UserDefaults.standard.aiHubAllowApply
    @State private var pendingApply: PendingPresetApply?
    @State private var appliedRecIDs: Set<UUID> = []
    @State private var applyErrorText: String?
    @State private var undoRecord: AIHubTherapyApply.UndoRecord?
    @State private var showUndoConfirm = false

    private struct PendingPresetApply: Identifiable {
        let id = UUID()
        let presetID: String
        let presetName: String
        let recommendation: AIHubPresetReview.Recommendation
    }

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
                } else {
                    missingKeyNotice
                }
                reviewSection
                if isConfigured { disclaimer }
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
            applyAllowed = UserDefaults.standard.aiHubAllowApply
            undoRecord = AIHubTherapyApply.lastUndoRecord
            reloadReview()
        }
        // Gleiche Disclaimer-Bestätigung wie bei Therapy Insights
        .alert(
            hubT("ti.apply.title"),
            isPresented: Binding(
                get: { pendingApply != nil },
                set: { if !$0 { pendingApply = nil } }
            ),
            presenting: pendingApply
        ) { pending in
            Button(hubT("ti.apply"), role: .destructive) { runApply(pending) }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: { pending in
            Text(hubT(
                "ti.apply.message",
                pending.recommendation.currentText,
                pending.recommendation.proposedText
            ))
        }
        .alert(
            hubT("ti.apply.failed"),
            isPresented: Binding(
                get: { applyErrorText != nil },
                set: { if !$0 { applyErrorText = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(applyErrorText ?? "")
        }
        .alert(hubT("ti.undo.title"), isPresented: $showUndoConfirm) {
            Button(hubT("ti.undo"), role: .destructive) { runUndo() }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(hubT("ti.undo.message", undoRecord?.summary ?? ""))
        }
    }

    // MARK: - Preset-Review

    private func reloadReview() {
        Task { @MainActor in
            reviewResult = await Task.detached(priority: .userInitiated) {
                AIHubPresetReview.analyze()
            }.value
        }
    }

    private func runApply(_ pending: PendingPresetApply) {
        let recommendation = pending.recommendation
        var newPercentage: Double?
        var newDuration: Int?
        switch recommendation.adjustment {
        case let .percentage(value): newPercentage = Double(value)
        case let .durationMinutes(minutes): newDuration = minutes
        }
        let summary = "\(pending.presetName): \(recommendation.currentText) → \(recommendation.proposedText)"
        if let error = AIHubTherapyApply.applyPresetAdjustment(
            presetID: pending.presetID,
            newPercentage: newPercentage,
            newDurationMinutes: newDuration,
            summary: summary
        ) {
            applyErrorText = error.localizedDescription
        } else {
            _ = appliedRecIDs.insert(recommendation.id)
            undoRecord = AIHubTherapyApply.lastUndoRecord
        }
    }

    private func runUndo() {
        AIHubTherapyApply.undoLast { error in
            if let error = error {
                applyErrorText = error.localizedDescription
            } else {
                undoRecord = AIHubTherapyApply.lastUndoRecord
                reloadReview()
            }
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hubT("pr.section"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            if let result = reviewResult {
                if result.qualifyingCount == 0 {
                    reviewInfoCard(
                        icon: "tray",
                        color: .secondary,
                        text: hubT("pr.toofew", AIHubPresetReview.minActivations)
                    )
                } else {
                    if result.reviews.isEmpty, result.suppressedCount == 0 {
                        reviewInfoCard(icon: "checkmark.seal.fill", color: .green, text: hubT("pr.none"))
                    }
                    ForEach(result.reviews) { review in
                        reviewCard(review)
                    }
                    if result.suppressedCount > 0 {
                        reviewInfoCard(
                            icon: "hourglass",
                            color: .orange,
                            text: hubT(
                                "ti.cooldown.info",
                                result.suppressedCount,
                                AIHubTherapyApply.cooldownDays
                            )
                        )
                    }
                    if !applyAllowed, !result.reviews.isEmpty {
                        Text(hubT("ti.apply.hint"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(hubT("ti.computing"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            if applyAllowed, let record = undoRecord, record.target == .preset {
                undoRow(record)
            }
            Text(hubT("pr.minnote", AIHubPresetReview.analysisDays, AIHubPresetReview.minActivations))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private func reviewInfoCard(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
        )
    }

    private func reviewCard(_ review: AIHubPresetReview.Review) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if !review.emoji.isEmpty {
                    Text(review.emoji).font(.title3)
                }
                Text(review.name)
                    .font(.headline)
                Spacer()
                Text(hubT("pr.activations.format", review.activationCount, AIHubPresetReview.analysisDays))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                statLine("TIR: \(Int((review.tirDuring * 100).rounded())) %")
                statLine(hubT("pr.hypos.during", review.hypoDuring, review.activationCount))
                statLine(hubT("pr.hypos.after", review.hypoAfter, review.activationCount))
                statLine(hubT("pr.early", review.earlyEndCount, review.activationCount))
            }
            ForEach(review.recommendations) { recommendation in
                recommendationView(recommendation, review: review)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
        )
    }

    private func statLine(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func recommendationView(
        _ recommendation: AIHubPresetReview.Recommendation,
        review: AIHubPresetReview.Review
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(recommendation.currentText) → \(recommendation.proposedText)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                Spacer()
                Text("\(recommendation.confidence)%")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
                    .foregroundStyle(.green)
            }
            Text(recommendation.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if applyAllowed {
                if appliedRecIDs.contains(recommendation.id) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text(hubT("ti.applied"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                } else {
                    Button {
                        pendingApply = PendingPresetApply(
                            presetID: review.id,
                            presetName: review.name,
                            recommendation: recommendation
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.subheadline)
                            Text(hubT("ti.apply"))
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.10 : 0.05))
        )
    }

    private func undoRow(_ record: AIHubTherapyApply.UndoRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward.circle")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(hubT("ti.undo.row"))
                    .font(.caption.bold())
                Text(record.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showUndoConfirm = true
            } label: {
                Text(hubT("ti.undo"))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
        )
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
