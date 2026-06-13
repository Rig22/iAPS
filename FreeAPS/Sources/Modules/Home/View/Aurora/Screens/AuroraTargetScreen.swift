import SwiftUI

enum AuroraTempTarget: Hashable {
    case off
    case sport // 140 mg/dL · 60 min
    case eating // 80 mg/dL · 30 min
    case low // 120 mg/dL · 45 min

    var title: String {
        switch self {
        case .off: return "Aus"
        case .sport: return "Sport"
        case .eating: return "Essen bald"
        case .low: return "Niedrig"
        }
    }

    var subtitle: String {
        switch self {
        case .off: return "Standard 100 mg/dL"
        case .sport: return "140 mg/dL · 60 min"
        case .eating: return "80 mg/dL · 30 min"
        case .low: return "120 mg/dL · 45 min"
        }
    }
}

struct AuroraTargetScreen: View {
    @Binding var selected: AuroraTempTarget
    let onSelect: (AuroraTempTarget) -> Void

    @Environment(\.colorScheme) private var scheme

    private let options: [AuroraTempTarget] = [.off, .sport, .eating, .low]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(NSLocalizedString("Target", comment: ""))
                    .font(.system(size: 32, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    .padding(.leading, 6)

                AuroraListSection(title: hubT("aur.tt")) {
                    ForEach(Array(options.enumerated()), id: \.element) { index, opt in
                        row(opt)
                        if index < options.count - 1 {
                            Divider().overlay(AuroraPalette.hairline(scheme))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 74)
            .padding(.bottom, 110)
        }
    }

    private func row(_ opt: AuroraTempTarget) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selected = opt
            onSelect(opt)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(opt.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    Text(opt.subtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AuroraPalette.textMuted(scheme))
                }
                Spacer()
                Image(systemName: selected == opt ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected == opt ? AuroraPalette.Status.inMain : AuroraPalette.textFaint(scheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
