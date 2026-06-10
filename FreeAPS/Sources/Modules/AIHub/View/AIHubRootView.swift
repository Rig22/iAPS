import SwiftUI
import Swinject

extension AIHub {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel

        @Environment(\.colorScheme) private var colorScheme

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
                            if feature == .foodSearch {
                                // Springt ins bestehende AddCarbs-KI-Feature —
                                // ersetzt das Hub-Modal durch das AddCarbs-Modal.
                                Button {
                                    state.showModal(for: .addCarbs(editMode: false, override: false, mode: .image))
                                } label: {
                                    FeatureCard(feature: feature)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(destination: destination(for: feature)) {
                                    FeatureCard(feature: feature)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
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
            case .foodSearch:
                // Nie erreicht — foodSearch ist ein Button (showModal), kein NavigationLink.
                EmptyView()
            }
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
                Text("Wie kann ich dir heute helfen?")
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
                    Text(feature.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
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
        case .foodSearch: return "FoodSearch"
        }
    }

    var subtitle: String {
        switch self {
        case .chat: return "Fragen zu deinen Daten und Einstellungen stellen."
        case .therapyInsights: return "Automatische Analyse von Basal, ISF und CR."
        case .recap: return "Wöchentliche und monatliche Muster im Überblick."
        case .foodSearch: return "Mahlzeiten per KI erkennen und Kohlenhydrate schätzen."
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .therapyInsights: return "chart.line.uptrend.xyaxis"
        case .recap: return "calendar.badge.clock"
        case .foodSearch: return "fork.knife"
        }
    }

    var tint: Color {
        switch self {
        case .chat: return .purple
        case .therapyInsights: return .blue
        case .recap: return .indigo
        case .foodSearch: return .green
        }
    }
}
