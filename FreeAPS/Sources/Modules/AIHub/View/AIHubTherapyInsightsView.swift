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
        .onAppear { reload() }
        .onChange(of: intervalDays) { _ in reload() }
    }

    // MARK: - Laden

    private func reload() {
        showSuggestions = false
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
        VStack(alignment: .leading, spacing: 12) {
            Text(hubT("ti.suggestions"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            if suggestions.isEmpty {
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
            }
        }
    }

    private func suggestionCard(_ suggestion: AIHubTherapyAnalysis.Suggestion) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundStyle(.blue)
                    Text(hubT("ti.basal"))
                        .font(.headline)
                    Spacer()
                    Text("\(suggestion.confidence)%")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .foregroundStyle(.green)
                }
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%02d:00 – %02d:00", suggestion.startHour, suggestion.endHour % 24))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hubT("ti.current")).font(.caption2).foregroundStyle(.secondary)
                        Text(String(format: "%.2f U/h", suggestion.currentRate))
                            .font(.subheadline.bold())
                    }
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hubT("ti.proposed")).font(.caption2).foregroundStyle(.secondary)
                        Text(String(format: "%.2f U/h", suggestion.proposedRate))
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                }
                Text(suggestion.rationale)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
