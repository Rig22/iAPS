import CoreData
import SwiftUI

extension Home {
    // MARK: - Single Swatch

    struct BreatheStatusSwatch: View {
        let value: String
        let subvalue: String?
        let label: String
        let color: Color
        var onTap: (() -> Void)? = nil
        var onLongPress: (() -> Void)? = nil
        /// When true, shows a small circular activity indicator in the
        /// top-right corner of the swatch — e.g. while a Loop is computing.
        var busy: Bool = false
        /// When true, the subvalue text gently pulses (e.g. "Wechseln" on expired pod).
        var pulseSubvalue: Bool = false

        @State private var pressed = false
        @State private var longPressConsumed = false
        @Environment(\.colorScheme) private var colorScheme

        private var effectiveColor: Color {
            colorScheme == .dark ? color.opacity(0.55) : color
        }

        var body: some View {
            Button {
                // Wenn zuvor ein Long-Press ausgelöst wurde, den nachfolgenden
                // Button-Tap schlucken — sonst würden beide Handler feuern.
                if longPressConsumed {
                    longPressConsumed = false
                    return
                }
                guard let onTap = onTap else { return }
                withAnimation(.easeOut(duration: 0.12)) { pressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeOut(duration: 0.25)) { pressed = false }
                }
                onTap()
            } label: {
                VStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(Color.white)

                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let sub = subvalue, !sub.isEmpty {
                        if pulseSubvalue {
                            PulsingText(text: sub)
                        } else {
                            Text(sub)
                                .font(.system(size: 10, weight: .regular, design: .serif))
                                .foregroundStyle(
                                    Color.white
                                )
                                .lineLimit(1)
                        }
                    }
                    Text(label)
                        .font(.system(size: 10, weight: .regular, design: .serif))
                        .foregroundStyle(Color.white)
                        .padding(.top, 2)
                        .lineLimit(1)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .frame(height: 78)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(effectiveColor)
                        .shadow(color: effectiveColor.opacity(0.35), radius: pressed ? 2 : 6, x: 0, y: pressed ? 1 : 3)
                )
                .overlay(alignment: .topTrailing) {
                    if busy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.mini)
                            .tint(Color.white)
                            .padding(.top, 7)
                            .padding(.trailing, 8)
                    }
                }
                .scaleEffect(pressed ? 0.97 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                    guard let onLongPress = onLongPress else { return }
                    // Markiere diesen Long-Press als "konsumiert", damit der
                    // gleichzeitig feuernde Button-Tap (simultaneousGesture)
                    // im Button-Handler übersprungen wird.
                    longPressConsumed = true
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onLongPress()
                }
            )
        }
    }

    // MARK: - Basal Info text helper

    /// Computes the temp-basal string used by the badge below the watches.
    static func breatheTempBasalText(state: Home.StateModel) -> String {
        guard let tempRate = state.tempRate else { return "— U/h" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 2
        let rateStr = fmt.string(from: tempRate as NSNumber) ?? "0"
        let manual = state.manualTempBasal
            ? " " + NSLocalizedString("Manuell", comment: "Manual temp basal")
            : ""
        return rateStr + " U/h" + manual
    }

    // MARK: - Basal Info Badge

    /// Small floating badge showing the current temp basal rate.
    /// Rendered in the badge row directly below the watches (centered under the IOB tile).
    struct BasalInfoBadge: View {
        let text: String

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 9, weight: .medium))
                Text(text)
                    .font(.system(size: 11, weight: .regular, design: .serif))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.thinMaterial)
                    .overlay(Capsule().stroke(BreathePalette.daemmer.opacity(0.2), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            )
        }
    }

    // MARK: - Non-standard Insulin Concentration Badge

    /// Small red capsule badge that flags non-U100 insulin (U-200, U-300, …).
    /// Appears on the Insulin watch when the active concentration is not 1.0
    /// and the user has not hidden it via `hideInsulinBadge` in Settings.
    struct ConcentrationBadge: View {
        let concentration: Double

        private var label: String {
            "U" + String(Int((concentration * 100).rounded()))
        }

        var body: some View {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.9))
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                )
        }
    }

    // MARK: - Active-state Badge (Profil / Temporäres Ziel)

    /// Small capsule badge with a colored status dot and a label.
    /// Used in the badge row below the watches to show active profile
    /// overrides or active temporary targets. Tapping runs `onTap`
    /// (typically: present the cancel-confirmation dialog).
    struct ActiveBadge: View {
        let dotColor: Color
        let text: String
        /// Optional SF Symbol name — when set, replaces the status dot.
        var systemImage: String? = nil
        var onTap: (() -> Void)? = nil

        var body: some View {
            HStack(spacing: 5) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(dotColor)
                } else {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                }
                Text(text)
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.thinMaterial)
                    .overlay(Capsule().stroke(dotColor.opacity(0.25), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            )
            .contentShape(Capsule())
            .onTapGesture {
                onTap?()
            }
        }
    }

    // MARK: - Pulsing Text (self-contained, no leaked state)

    private struct PulsingText: View {
        let text: String
        var body: some View {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                let cycle: Double = 2.8 // full cycle in seconds
                let t = context.date.timeIntervalSince1970.truncatingRemainder(dividingBy: cycle)
                let phase = (1 - cos(t / cycle * 2 * .pi)) / 2 // 0→1→0 smooth
                let opacity = 0.45 + phase * 0.55 // range 0.45 … 1.0

                Text(text)
                    .font(.system(size: 10, weight: .regular, design: .serif))
                    .foregroundStyle(Color.white.opacity(opacity))
                    .lineLimit(1)
            }
        }
    }

    struct BreatheStatusRow: View {
        @ObservedObject var state: Home.StateModel
        @Binding var showBasalInfo: Bool

        @FetchRequest(
            entity: InsulinConcentration.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: true)]
        ) var concentration: FetchedResults<InsulinConcentration>

        // MARK: Derived values

        private var iobString: String {
            let v = Double(truncating: (state.data.iob ?? 0) as NSNumber)
            return String(format: "%.1f E", v).replacingOccurrences(of: ".", with: ",")
        }

        private var cobString: String {
            let v = Int(state.data.suggestion?.cob ?? 0)
            return "\(v) g"
        }

        private var concentrationValue: Double {
            Double(truncating: (concentration.last?.concentration ?? 1) as NSNumber)
        }

        private var rawReservoir: Decimal { state.reservoir ?? 0 }
        private var isDeadBeef: Bool { rawReservoir == 3_735_928_559 }
        private var physicalReservoir: Double {
            isDeadBeef ? 50.0 : Double(truncating: rawReservoir as NSNumber)
        }

        private var reservoirString: String {
            if isDeadBeef { return "50+ E" }
            let adjusted = physicalReservoir * concentrationValue
            return "\(Int(adjusted)) E"
        }

        private var pumpTimeString: String? {
            guard let expiresAt = state.pumpExpiresAtDate else { return nil }
            let remaining = expiresAt.timeIntervalSince(Date())
            if remaining <= 0 { return NSLocalizedString("Wechseln", comment: "Pod expired") }
            let totalMinutes = Int(remaining / 60)
            let days = totalMinutes / (24 * 60)
            let hours = (totalMinutes % (24 * 60)) / 60
            if days >= 1 { return "\(days) T \(hours) h" }
            return "\(hours) h"
        }

        private var pumpExpired: Bool {
            guard let expiresAt = state.pumpExpiresAtDate else { return false }
            return expiresAt.timeIntervalSince(Date()) <= 0
        }

        private var reservoirIsCritical: Bool {
            if isDeadBeef { return false }
            let adjusted = physicalReservoir * concentrationValue
            return adjusted < 20
        }

        private var reservoirColor: Color {
            reservoirIsCritical ? BreathePalette.daemmer : BreathePalette.salbei
        }

        private var minutesSinceLoop: Int {
            guard state.lastLoopDate != .distantPast else { return -1 }
            let secs = -1 * state.lastLoopDate.timeIntervalSinceNow
            return max(0, Int(secs / 60))
        }

        private var loopValueString: String {
            let m = minutesSinceLoop
            if m < 0 { return "—" }
            if m < 1 { return "jetzt" }
            return "\(m) min"
        }

        private var loopSubString: String? {
            minutesSinceLoop >= 1 ? "seit" : nil
        }

        // MARK: Body

        var body: some View {
            HStack(spacing: 10) {
                BreatheStatusSwatch(
                    value: iobString,
                    subvalue: nil,
                    label: NSLocalizedString("Insulin aktiv", comment: "IOB swatch label"),
                    color: BreathePalette.daemmer,
                    onTap: {
                        if state.bolusProgress != nil {
                            // Bolus läuft bereits — Aufruf über StateModel-Flag
                            // wie beim FAB-Plus-Button.
                            return
                        }
                        state.showModal(for: .bolus(
                            waitForSuggestion: state.useCalc ? true : false,
                            fetch: false
                        ))
                    },
                    onLongPress: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showBasalInfo.toggle()
                        }
                    }
                )
                .overlay(alignment: .topTrailing) {
                    if concentrationValue != 1.0,
                       !state.settingsManager.settings.hideInsulinBadge
                    {
                        Home.ConcentrationBadge(concentration: concentrationValue)
                            .offset(x: 4, y: -6)
                    }
                }
                BreatheStatusSwatch(
                    value: cobString,
                    subvalue: nil,
                    label: NSLocalizedString("Kohlenhydrate", comment: "COB swatch label"),
                    color: BreathePalette.kamille,
                    onTap: {
                        state.showModal(for: .addCarbs(editMode: false, override: false, mode: .meal))
                    }
                )
                BreatheStatusSwatch(
                    value: reservoirString,
                    subvalue: pumpTimeString,
                    label: NSLocalizedString("Pumpe", comment: "Reservoir swatch label"),
                    color: reservoirColor,
                    onTap: state.pumpDisplayState != nil ? { state.setupPump = true } : nil,
                    pulseSubvalue: pumpExpired
                )
                BreatheStatusSwatch(
                    value: loopValueString,
                    subvalue: loopSubString,
                    label: NSLocalizedString("Loop", comment: "Loop swatch label"),
                    color: BreathePalette.flieder,
                    onTap: { state.isStatusPopupPresented = true },
                    onLongPress: { state.runLoop() },
                    busy: state.isLooping
                )
            }
            .padding(.horizontal, 10)
        }
    }
}
