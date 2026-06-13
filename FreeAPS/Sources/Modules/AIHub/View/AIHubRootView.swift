import SwiftUI
import Swinject

extension AIHub {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel

        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.dismiss) private var dismiss

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    VStack(spacing: 12) {
                        ForEach(Feature.allCases) { feature in
                            NavigationLink(destination: destination(for: feature)) {
                                FeatureCard(feature: feature)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    medicalDisclaimer
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(
                Color(colorScheme == .dark ? .systemBackground : .secondarySystemBackground)
                    .ignoresSafeArea()
            )
            .navigationTitle("AI Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AIHubSettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }

        @ViewBuilder private func destination(for feature: Feature) -> some View {
            switch feature {
            case .chat:
                AIHubChatView()
            case .therapyInsights:
                AIHubTherapyInsightsView()
            case .recap:
                AIHubRecapView()
            case .presetDesigner:
                AIHubPresetDesignerView()
            case .autoPresets:
                AIHubAutoPresetsView()
            case .foodSearch:
                // Weiche: Texteingabe oben (KI-Suche), Kamera darunter —
                // beide Wege springen ins bestehende AddCarbs-Modal.
                AIHubFoodSearchView(
                    onSearch: { query in
                        state.showModal(for: .addCarbs(editMode: false, override: false, mode: .aiSearch(query: query)))
                    },
                    onCamera: {
                        state.showModal(for: .addCarbs(editMode: false, override: false, mode: .image))
                    }
                )
            }
        }

        private var medicalDisclaimer: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "cross.case")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Text(hubT("root.disclaimer.title"))
                        .font(.footnote.bold())
                }
                Text(hubT("root.disclaimer.text"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red.opacity(colorScheme == .dark ? 0.12 : 0.06))
            )
        }

        private var header: some View {
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("AI Hub")
                    .font(.largeTitle.bold())
                Text(hubT("root.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
    }

    // MARK: - Feature card

    private struct FeatureCard: View {
        let feature: Feature

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(feature.tint.gradient)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(feature.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        // Kennzeichnet Features, die ein KI-Modell aufrufen
                        // (Therapy Insights rechnet rein deterministisch).
                        if feature.usesAI {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                    Text(feature.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
            )
        }
    }
}

private extension AIHub.Feature {
    var title: String {
        switch self {
        case .chat: return "AI Chat"
        case .therapyInsights: return "Therapy Insights"
        case .recap: return "Recap"
        case .presetDesigner: return "Preset Designer"
        case .autoPresets: return "AutoPresets"
        case .foodSearch: return "FoodSearch"
        }
    }

    var subtitle: String {
        switch self {
        case .chat: return hubT("root.card.chat.sub")
        case .therapyInsights: return hubT("root.card.insights.sub")
        case .recap: return hubT("root.card.recap.sub")
        case .presetDesigner: return hubT("root.card.preset.sub")
        case .autoPresets: return hubT("root.card.auto.sub")
        case .foodSearch: return hubT("root.card.food.sub")
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .therapyInsights: return "chart.line.uptrend.xyaxis"
        case .recap: return "calendar.badge.clock"
        case .presetDesigner: return "slider.horizontal.3"
        case .autoPresets: return "figure.walk.motion"
        case .foodSearch: return "fork.knife"
        }
    }

    var tint: Color {
        switch self {
        case .chat: return .purple
        case .therapyInsights: return .blue
        case .recap: return .indigo
        case .presetDesigner: return .orange
        case .autoPresets: return .teal
        case .foodSearch: return .green
        }
    }

    /// Features, die tatsächlich ein KI-Modell aufrufen — Therapy Insights
    /// und AutoPresets bleiben bewusst ohne Sparkles (deterministisch bzw.
    /// rein sensorgesteuert).
    var usesAI: Bool {
        switch self {
        case .chat,
             .foodSearch,
             .presetDesigner,
             .recap: return true
        case .autoPresets,
             .therapyInsights: return false
        }
    }
}
