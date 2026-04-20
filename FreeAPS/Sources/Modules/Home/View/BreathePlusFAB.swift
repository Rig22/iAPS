import SwiftUI

extension Home {
    // MARK: - Floating Action Button

    /// Single floating "+" button — the only direct action surface in the
    /// Breathe skin's home view. Tapping it opens `BreatheActionSheet`.
    struct BreathePlusFAB: View {
        let action: () -> Void
        @State private var pressed = false

        var body: some View {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeOut(duration: 0.12)) { pressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeOut(duration: 0.25)) { pressed = false }
                }
                action()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [BreathePalette.salbei, BreathePalette.daemmer],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                            .shadow(
                                color: BreathePalette.daemmer.opacity(0.35),
                                radius: pressed ? 4 : 14, x: 0, y: pressed ? 2 : 8
                            )
                    )
                    .scaleEffect(pressed ? 0.94 : 1.0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Aktionen"))
        }
    }

    // MARK: - Action Sheet

    /// Modal sheet of primary actions — replaces the old ButtonPanel.
    /// All callbacks are responsible for dismissing the sheet themselves
    /// (so they can decide e.g. to show a cancel confirmation first).
    struct BreatheActionSheet: View {
        @Binding var isPresented: Bool
        let isOverride: Bool
        let isTarget: Bool

        let onBolus: () -> Void
        let onCarbs: () -> Void
        let onProfile: () -> Void
        let onTempTarget: () -> Void
        let onStatistics: () -> Void
        let onSettings: () -> Void

        private struct ActionItem: Identifiable {
            let id = UUID()
            let title: String
            let icon: String
            let color: Color
            let active: Bool
            let perform: () -> Void
        }

        private var actions: [ActionItem] {
            [
                ActionItem(
                    title: NSLocalizedString("Bolus", comment: ""),
                    icon: "syringe",
                    color: BreathePalette.daemmer,
                    active: false,
                    perform: onBolus
                ),
                ActionItem(
                    title: NSLocalizedString("Mahlzeit", comment: ""),
                    icon: "fork.knife",
                    color: BreathePalette.kamille,
                    active: false,
                    perform: onCarbs
                ),
                ActionItem(
                    title: NSLocalizedString("Profil", comment: ""),
                    icon: isOverride ? "person.fill" : "person",
                    color: BreathePalette.salbei,
                    active: isOverride,
                    perform: onProfile
                ),
                ActionItem(
                    title: NSLocalizedString("Temp Target", comment: ""),
                    icon: "target",
                    color: BreathePalette.flieder,
                    active: isTarget,
                    perform: onTempTarget
                ),
                ActionItem(
                    title: NSLocalizedString("Statistik", comment: ""),
                    icon: "chart.bar.xaxis",
                    color: BreathePalette.salbei,
                    active: false,
                    perform: onStatistics
                ),
                ActionItem(
                    title: NSLocalizedString("Einstellungen", comment: ""),
                    icon: "gearshape",
                    color: BreathePalette.flieder,
                    active: false,
                    perform: onSettings
                )
            ]
        }

        private let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]

        var body: some View {
            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                Text("Was möchtest du tun?")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(actions) { a in
                        Button {
                            a.perform()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: a.icon)
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundStyle(Color.white.opacity(0.95))
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle().fill(
                                            LinearGradient(
                                                colors: [a.color.opacity(0.95), a.color.opacity(0.75)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: a.color.opacity(0.30), radius: 6, y: 3)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(a.active ? Color.white : Color.clear, lineWidth: 2)
                                    )
                                Text(a.title)
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .foregroundStyle(.primary.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 8)

                Button("Abbrechen") { isPresented = false }
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity)
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
    }
}
