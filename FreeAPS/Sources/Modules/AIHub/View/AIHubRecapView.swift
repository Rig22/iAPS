import SwiftUI

/// Recap: Wochen-/Monatsrückblick. Zahlen-Vergleich rechnet lokal und sofort;
/// die KI-Beobachtungen laufen auf Knopfdruck und werden pro Tag gecacht.
struct AIHubRecapView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var days = 7
    @State private var summary: AIHubRecap.Summary?
    @State private var narrative: String?
    @State private var isGenerating = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("", selection: $days) {
                    Text(hubT("recap.week")).tag(7)
                    Text(hubT("recap.month")).tag(30)
                }
                .pickerStyle(.segmented)

                comparisonCard
                highlightsCard
                narrativeCard
                disclaimer
            }
            .padding(16)
        }
        .background(
            Color(colorScheme == .dark ? .systemBackground : .secondarySystemBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("Recap")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onChange(of: days) { _ in reload() }
    }

    // MARK: - Laden

    private func reload() {
        summary = nil
        narrative = AIHubRecap.cachedNarrative(days: days)
        errorText = nil
        let period = days
        Task { @MainActor in
            summary = await Task.detached(priority: .userInitiated) {
                AIHubRecap.compute(days: period)
            }.value
        }
    }

    private func generateNarrative() {
        guard let summary = summary, !isGenerating else { return }
        isGenerating = true
        errorText = nil
        let period = days
        Task { @MainActor in
            do {
                let prompt = AIHubRecap.narrativePrompt(for: summary)
                let text = try await AIHubChatService.executePrompt(prompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                narrative = text
                AIHubRecap.storeNarrative(text, days: period)
            } catch {
                errorText = error.localizedDescription
            }
            isGenerating = false
        }
    }

    // MARK: - Zahlen-Vergleich

    @ViewBuilder private var comparisonCard: some View {
        if let summary = summary, let current = summary.current {
            card {
                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hubT("recap.tir"))
                                .font(.headline)
                            Text(days == 7 ? hubT("recap.vs.week") : hubT("recap.vs.month"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.0f%%", current.tir * 100))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        deltaBadge(
                            current: current.tir * 100,
                            previous: summary.previous.map { $0.tir * 100 },
                            higherIsBetter: true,
                            unit: hubT("recap.points")
                        )
                    }
                    Divider()
                    HStack {
                        metricCell(
                            title: hubT("recap.mean"),
                            value: AIHubTherapyAnalysis.formatGlucose(current.meanMgdl, isMmol: summary.isMmol),
                            current: current.meanMgdl,
                            previous: summary.previous?.meanMgdl,
                            higherIsBetter: false
                        )
                        metricCell(
                            title: "CV",
                            value: String(format: "%.0f%%", current.cv * 100),
                            current: current.cv * 100,
                            previous: summary.previous.map { $0.cv * 100 },
                            higherIsBetter: false
                        )
                        metricCell(
                            title: hubT("recap.hypos"),
                            value: "\(current.hypoEpisodes)",
                            current: Double(current.hypoEpisodes),
                            previous: summary.previous.map { Double($0.hypoEpisodes) },
                            higherIsBetter: false
                        )
                        metricCell(
                            title: "TDD",
                            value: current.tddMean > 0 ? String(format: "%.1f U", current.tddMean) : "—",
                            current: current.tddMean,
                            previous: summary.previous?.tddMean,
                            higherIsBetter: false
                        )
                    }
                }
            }
        } else if summary != nil {
            card {
                Text(hubT("recap.toolittle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            card {
                HStack {
                    ProgressView()
                    Text(hubT("recap.computing")).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metricCell(
        title: String,
        value: String,
        current: Double,
        previous: Double?,
        higherIsBetter: Bool
    ) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
            trendArrow(current: current, previous: previous, higherIsBetter: higherIsBetter)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func trendArrow(current: Double, previous: Double?, higherIsBetter: Bool) -> some View {
        if let previous = previous, previous != 0 || current != 0 {
            let delta = current - previous
            let improved = higherIsBetter ? delta > 0 : delta < 0
            let neutral = abs(delta) < 0.005 || abs(delta) / max(abs(previous), 1) < 0.02
            Image(systemName: neutral ? "arrow.right" : (delta > 0 ? "arrow.up" : "arrow.down"))
                .font(.caption2.bold())
                .foregroundStyle(neutral ? Color.secondary : (improved ? .green : .orange))
        } else {
            Image(systemName: "minus")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func deltaBadge(
        current: Double,
        previous: Double?,
        higherIsBetter: Bool,
        unit: String
    ) -> some View {
        if let previous = previous {
            let delta = current - previous
            let improved = higherIsBetter ? delta >= 0 : delta <= 0
            Text(String(format: "%+.0f%@", delta, unit))
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill((improved ? Color.green : Color.orange).opacity(0.15)))
                .foregroundStyle(improved ? Color.green : Color.orange)
        }
    }

    // MARK: - Höhepunkte (deterministisch)

    @ViewBuilder private var highlightsCard: some View {
        if let summary = summary, summary.bestBlockText != nil || summary.worstBlockText != nil {
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(hubT("recap.dayflow"))
                        .font(.headline)
                    if let best = summary.bestBlockText {
                        highlightRow(best, icon: "checkmark.circle.fill", tint: .green)
                    }
                    if let worst = summary.worstBlockText {
                        highlightRow(worst, icon: "exclamationmark.circle.fill", tint: .orange)
                    }
                }
            }
        }
    }

    private func highlightRow(_ text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
        }
        .font(.subheadline)
    }

    // MARK: - KI-Beobachtungen

    private var narrativeCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text(hubT("recap.ai.title"))
                        .font(.headline)
                    Spacer()
                    if narrative != nil, !isGenerating {
                        Button {
                            generateNarrative()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let narrative = narrative {
                    Text(narrative)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isGenerating {
                    HStack {
                        ProgressView()
                        Text(hubT("recap.ai.generating"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if !AIHubChatService.isConfigured {
                    Text(
                        hubT("recap.nokey")
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        generateNarrative()
                    } label: {
                        Text(hubT("recap.ai.generate"))
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .disabled(summary?.current == nil)
                }

                if let error = errorText {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Bausteine

    private var disclaimer: some View {
        Text(hubT(
            UserDefaults.standard.aiHubCarbsComplete
                ? "recap.disclaimer.complete"
                : "recap.disclaimer"
        ))
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
