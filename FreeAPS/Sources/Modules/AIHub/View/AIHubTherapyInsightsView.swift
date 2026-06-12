import SwiftUI

/// Therapy Insights: Settings Score + deterministische Basal-Vorschläge.
/// Score wird beim Öffnen und bei Intervallwechsel gerechnet, die
/// Vorschlags-Analyse läuft auf Knopfdruck.
struct AIHubTherapyInsightsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var intervalDays = 7
    @State private var result: AIHubTherapyAnalysis.Result?
    @State private var showSuggestions = false
    @State private var isAnalyzing = false

    // Direkte Übernahme (Opt-in über Hub-Settings)
    @State private var applyAllowed = UserDefaults.standard.aiHubAllowApply
    @State private var pendingApply: AIHubTherapyAnalysis.Suggestion?
    @State private var applyingID: UUID?
    @State private var appliedIDs: Set<UUID> = []
    @State private var applyErrorText: String?

    // Rückgängig (letzte Übernahme, Snapshot-basiert)
    @State private var undoRecord: AIHubTherapyApply.UndoRecord?
    @State private var showUndoConfirm = false
    @State private var isUndoing = false

    private var intervals: [(label: String, days: Int)] {
        [3, 7, 14, 30].map { (hubT("ti.days.format", $0), $0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intervalPicker
                scoreCard
                analyzeButton
                if showSuggestions {
                    suggestionsSection
                }
                if applyAllowed, undoRecord != nil {
                    undoCard
                }
                disclaimer
            }
            .padding(16)
        }
        .background(
            Color(colorScheme == .dark ? .systemBackground : .secondarySystemBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("Therapy Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyAllowed = UserDefaults.standard.aiHubAllowApply
            undoRecord = AIHubTherapyApply.lastUndoRecord
            reload()
        }
        .onChange(of: intervalDays) { _ in reload() }
        // Disclaimer-Bestätigung vor jeder Übernahme — bewusst als Alert
        // mit destruktivem Button: Das ändert die aktive Therapie.
        .alert(
            hubT("ti.apply.title"),
            isPresented: Binding(
                get: { pendingApply != nil },
                set: { if !$0 { pendingApply = nil } }
            ),
            presenting: pendingApply
        ) { suggestion in
            Button(hubT("ti.apply"), role: .destructive) { runApply(suggestion) }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: { suggestion in
            Text(applyMessage(for: suggestion))
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
            Text(undoMessage)
        }
    }

    // MARK: - Übernahme

    private func applyMessage(for suggestion: AIHubTherapyAnalysis.Suggestion) -> String {
        var message = hubT("ti.apply.message", suggestion.currentText, suggestion.proposedText)
        // Bei Basal betrifft die Übernahme den GANZEN Block — alle
        // Segmente einzeln auflisten, damit das unmissverständlich ist.
        if case let .basal(startMinute, endMinute, factor) = suggestion.apply {
            let lines = AIHubTherapyApply.basalPreviewLines(
                startMinute: startMinute,
                endMinute: endMinute,
                factor: factor
            )
            if !lines.isEmpty {
                message += "\n\n" + hubT("ti.apply.block.note") + "\n" + lines.joined(separator: "\n")
            }
            message += "\n\n" + hubT("ti.apply.message.basal")
        }
        return message
    }

    /// Kurzbeschreibung für die Undo-Zeile, z. B.
    /// „Basalrate 18:00 – 21:00: 0.60 U/h → 0.55 U/h".
    private func summary(for suggestion: AIHubTherapyAnalysis.Suggestion) -> String {
        let title = meta(for: suggestion.kind).title
        let time = suggestion.timeText.map { " \($0)" } ?? ""
        return "\(title)\(time): \(suggestion.currentText) → \(suggestion.proposedText)"
    }

    private func runApply(_ suggestion: AIHubTherapyAnalysis.Suggestion) {
        applyingID = suggestion.id
        AIHubTherapyApply.apply(suggestion, summary: summary(for: suggestion)) { error in
            applyingID = nil
            if let error = error {
                applyErrorText = error.localizedDescription
            } else {
                _ = appliedIDs.insert(suggestion.id)
                undoRecord = AIHubTherapyApply.lastUndoRecord
            }
        }
    }

    // MARK: - Rückgängig

    private var undoMessage: String {
        hubT("ti.undo.message", undoRecord?.summary ?? "")
            + (undoRecord?.target == .basal ? "\n\n" + hubT("ti.apply.message.basal") : "")
    }

    private func runUndo() {
        isUndoing = true
        AIHubTherapyApply.undoLast { error in
            isUndoing = false
            if let error = error {
                applyErrorText = error.localizedDescription
            } else {
                undoRecord = AIHubTherapyApply.lastUndoRecord
                // Profil hat sich geändert → Analyse neu rechnen
                reload()
            }
        }
    }

    private var undoCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(.orange)
                    Text(hubT("ti.undo.row"))
                        .font(.headline)
                    Spacer()
                    if let date = undoRecord?.date {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(undoRecord?.summary ?? "")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showUndoConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        if isUndoing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.subheadline)
                        }
                        Text(hubT("ti.undo"))
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(isUndoing || applyingID != nil)
            }
        }
    }

    // MARK: - Laden

    private func reload() {
        showSuggestions = false
        appliedIDs = []
        let days = intervalDays
        Task { @MainActor in
            result = await Task.detached(priority: .userInitiated) {
                AIHubTherapyAnalysis.analyze(days: days)
            }.value
        }
    }

    private func runAnalysis() {
        // Analyse liegt bereits im Result — der Button steuert nur die
        // Sichtbarkeit, mit kurzer Verzögerung als Feedback.
        isAnalyzing = true
        appliedIDs = []
        Task { @MainActor in
            let days = intervalDays
            result = await Task.detached(priority: .userInitiated) {
                AIHubTherapyAnalysis.analyze(days: days)
            }.value
            isAnalyzing = false
            withAnimation { showSuggestions = true }
        }
    }

    // MARK: - Intervall

    private var intervalPicker: some View {
        Picker("Zeitraum", selection: $intervalDays) {
            ForEach(intervals, id: \.days) { interval in
                Text(interval.label).tag(interval.days)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Score-Card

    @ViewBuilder private var scoreCard: some View {
        if let stats = result?.stats {
            let score = AIHubTherapyAnalysis.score(for: stats)
            card {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hubT("ti.score.title"))
                            .font(.headline)
                        Text(score.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    scoreRing(value: score.value)
                }
                Divider().padding(.vertical, 10)
                HStack {
                    statCell(String(format: "%.0f%%", stats.tir * 100), "TIR")
                    statCell(String(format: "%.1f%%", stats.gmi), "GMI")
                    statCell(String(format: "%.1f%%", stats.below * 100), hubT("ti.below70"))
                    statCell(String(format: "%.0f%%", stats.cv * 100), "CV")
                }
            }
        } else if result != nil {
            card {
                Text(hubT("ti.toolittle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            card {
                HStack {
                    ProgressView()
                    Text(hubT("ti.computing")).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func scoreRing(value: Int) -> some View {
        let color: Color = value >= 80 ? .green : (value >= 60 ? .yellow : .orange)
        return ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(value) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)")
                .font(.title.bold())
        }
        .frame(width: 74, height: 74)
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Analyse-Button

    private var analyzeButton: some View {
        Button {
            runAnalysis()
        } label: {
            HStack {
                if isAnalyzing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(hubT("ti.analyze"))
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzing || result?.stats == nil)
        .opacity(result?.stats == nil ? 0.5 : 1)
    }

    // MARK: - Vorschläge

    @ViewBuilder private var suggestionsSection: some View {
        let suggestions = result?.suggestions ?? []
        let suppressedCount = result?.suppressedCount ?? 0
        VStack(alignment: .leading, spacing: 12) {
            Text(hubT("ti.suggestions"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            if suggestions.isEmpty, suppressedCount == 0 {
                card {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text(hubT("ti.none"))
                            .font(.subheadline)
                    }
                }
            } else {
                ForEach(suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
                if suppressedCount > 0 {
                    card {
                        HStack(spacing: 12) {
                            Image(systemName: "hourglass")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            Text(hubT(
                                "ti.cooldown.info",
                                suppressedCount,
                                AIHubTherapyApply.cooldownDays
                            ))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if !applyAllowed, !suggestions.isEmpty {
                    Text(hubT("ti.apply.hint"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private func meta(for kind: AIHubTherapyAnalysis.Suggestion.Kind) -> (title: String, icon: String) {
        switch kind {
        case .basalDecrease,
             .basalIncrease: return (hubT("ti.basal"), "chart.xyaxis.line")
        case .isfLower,
             .isfRaise: return (hubT("ti.isf"), "drop.fill")
        case .crLower,
             .crRaise: return (hubT("ti.cr"), "fork.knife")
        }
    }

    private func suggestionCard(_ suggestion: AIHubTherapyAnalysis.Suggestion) -> some View {
        let meta = meta(for: suggestion.kind)
        return card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: meta.icon)
                        .foregroundStyle(.blue)
                    Text(meta.title)
                        .font(.headline)
                    Spacer()
                    Text("\(suggestion.confidence)%")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .foregroundStyle(.green)
                }
                if let timeText = suggestion.timeText {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hubT("ti.current")).font(.caption2).foregroundStyle(.secondary)
                        Text(suggestion.currentText)
                            .font(.subheadline.bold())
                    }
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hubT("ti.proposed")).font(.caption2).foregroundStyle(.secondary)
                        Text(suggestion.proposedText)
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                }
                Text(suggestion.rationale)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if applyAllowed {
                    applyControl(for: suggestion)
                }
            }
        }
    }

    /// Übernehmen-Button bzw. Übernommen-Status unter der Begründung.
    /// Nur sichtbar, wenn der Opt-in-Toggle in den Hub-Settings aktiv ist.
    @ViewBuilder private func applyControl(for suggestion: AIHubTherapyAnalysis.Suggestion) -> some View {
        if appliedIDs.contains(suggestion.id) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text(hubT("ti.applied"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }
        } else {
            Button {
                pendingApply = suggestion
            } label: {
                HStack(spacing: 6) {
                    if applyingID == suggestion.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.subheadline)
                    }
                    Text(hubT("ti.apply"))
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.blue.opacity(0.15)))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .disabled(applyingID != nil)
        }
    }

    // MARK: - Bausteine

    private var disclaimer: some View {
        Text(
            hubT("ti.disclaimer")
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
        )
    }
}
