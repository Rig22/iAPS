import SwiftUI

/// Floating bottom action bar — two glass pills with a centered FAB.
///
/// Pure action bar (no tab state). Each button triggers a callback the caller
/// wires to `state.showModal(for:)` or similar.
///
/// - Left pill:  always Carbs + Bolus.
/// - FAB:        Settings.
/// - Right pill: Profil (override) and/or Ziel (temp target), each individually
///   hideable via the `showOverride` / `showTempTarget` flags (driven from
///   `UIUXStateModel.profileButton` / `.useTargetButton`).
struct AuroraTabBar: View {
    let glucose: Double // drives FAB color
    var showOverride: Bool = true
    var showTempTarget: Bool = true
    let onCarbs: () -> Void
    let onBolus: () -> Void
    let onDataTable: () -> Void
    let onStatistics: () -> Void
    let onProfile: () -> Void
    let onTarget: () -> Void
    let onSettings: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var status: AuroraGlucoseStatus { AuroraGlucoseStatus(mgdl: glucose) }

    var body: some View {
        HStack(spacing: 10) {
            leftPill
            fab
            rightPill
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 30)
    }

    // MARK: - Left pill (Carbs + Bolus)

    private var moveDataTableRight: Bool { !showOverride && !showTempTarget }

    private var leftPill: some View {
        HStack(spacing: 0) {
            actionButton(icon: "fork.knife", accessibility: "Kohlenhydrate") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCarbs()
            }
            actionButton(icon: "syringe.fill", accessibility: "Bolus") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onBolus()
            }
            if !moveDataTableRight {
                actionButton(icon: "list.bullet.rectangle", accessibility: "Behandlungen") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDataTable()
                }
            }
        }
        .frame(height: 58)
        .frame(maxWidth: .infinity)
        .auroraGlass(radius: 30)
    }

    // MARK: - Right pill (Statistik fix + Profil/Ziel beide optional)

    private var rightPill: some View {
        HStack(spacing: 0) {
            if moveDataTableRight {
                actionButton(icon: "list.bullet.rectangle", accessibility: "Behandlungen") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDataTable()
                }
            }
            actionButton(icon: "chart.bar.xaxis", accessibility: "Statistik") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onStatistics()
            }
            if showOverride {
                actionButton(icon: "person.fill", accessibility: "Profil") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onProfile()
                }
            }
            if showTempTarget {
                actionButton(icon: "target", accessibility: "Temporäres Ziel") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTarget()
                }
            }
        }
        .frame(height: 58)
        .frame(maxWidth: .infinity)
        .auroraGlass(radius: 30)
    }

    // MARK: - FAB (Settings)

    private var fab: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSettings()
        }, label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 62, height: 62)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(status.main)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
                )
        })
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Einstellungen"))
    }

    // MARK: - Helpers

    private func actionButton(
        icon: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action, label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(AuroraPalette.textMuted(scheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        })
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibility))
    }
}
