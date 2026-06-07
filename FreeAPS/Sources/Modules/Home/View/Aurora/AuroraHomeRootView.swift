import CoreData
import SwiftUI
import Swinject

extension Home {
    /// The Aurora skin's home screen — glassmorphism redesign.
    /// Replaces the previous Breathe layout. Reuses `Home.StateModel`,
    /// `HomeProvider`, and the existing routing.
    struct AuroraHomeRootView: BaseView {
        let resolver: Resolver

        @StateObject var state: StateModel
        @State private var toast: String? = nil
        @State private var showRunLoopConfirm = false
        @State private var showStatusPopup = false
        @State private var displayAutoHistory = false
        @State private var displayDynamicHistory = false
        @State private var showCancelOverrideAlert = false
        @State private var showCancelTempTargetAlert = false

        // Backup first-run prompt is handled centrally in Main.RootView so the
        // home view never instantiates on a fresh install. No Onboarding
        // FetchRequest or fullScreenCover needed here.

        @FetchRequest(
            entity: OverridePresets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            predicate: NSPredicate(format: "name != %@", "" as String)
        ) private var fetchedProfiles: FetchedResults<OverridePresets>

        @FetchRequest(
            entity: Override.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) private var fetchedPercent: FetchedResults<Override>

        @FetchRequest(
            entity: Auto_ISF.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) private var fetchedAISF: FetchedResults<Auto_ISF>

        @FetchRequest(
            entity: InsulinConcentration.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: true)]
        ) private var concentration: FetchedResults<InsulinConcentration>

        @Environment(\.colorScheme) private var scheme
        @Environment(\.scenePhase) private var scenePhase

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        // MARK: - Derived view-model

        private var glucoseValue: Double {
            Double(state.recentGlucose?.glucose ?? 100)
        }

        private var glucoseDelta: Int? { state.glucoseDelta }

        private var loopStatus: AuroraLoopStatus {
            if state.errorMessage != nil { return .error }
            if state.isLooping { return .looping }
            let age = Date().timeIntervalSince(state.lastLoopDate)
            if age > 15 * 60 { return .stale }
            return .ok
        }

        private var loopCaption: String {
            let age = Date().timeIntervalSince(state.lastLoopDate)
            if state.lastLoopDate == .distantPast { return "Loop · —" }
            let mins = Int(age / 60)
            if mins < 1 { return "Loop · jetzt" }
            if mins < 60 { return "Loop · vor \(mins) Min" }
            let hours = mins / 60
            return "Loop · vor \(hours) h"
        }

        private var sensorCaption: String? {
            // Sensor lifespan in days. We surface it as a coarse "X Tg" pill.
            let days = Int(state.sensorDays.rounded())
            return days > 0 ? "\(days) Tg" : nil
        }

        /// Active Insulin (IOB) — comes from the current ChartModel snapshot.
        /// (`state.iobs` is a cumulative loop-stats sum across history and is
        /// NOT what should appear in the badge.)
        private var iobString: String {
            let v = Double(truncating: (state.data.iob ?? 0) as NSNumber)
            return String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
        }

        /// Carbs on board (COB) — from the latest suggestion.
        /// (`state.carbData` is a cumulative sum and would over-count.)
        private var cobString: String {
            let v = Int(state.data.suggestion?.cob ?? 0)
            return "\(v)"
        }

        /// Insulin concentration factor (1.0 = U100, 2.0 = U200, …).
        private var insulinConcentration: Double {
            concentration.last?.concentration ?? 1
        }

        /// Pods can't report an exact reservoir level above 50 U — the pump
        /// layer substitutes this sentinel (see KnownPlugins.pumpReservoir).
        private static let reservoirSentinel = Decimal(0xDEAD_BEEF)

        private var reservoirString: String {
            guard let r = state.reservoir else { return "—" }
            let conc = insulinConcentration
            // Pod sentinel: show a capped "50+" (scaled for concentration),
            // mirroring PumpView, instead of formatting the raw sentinel int.
            if r == Self.reservoirSentinel {
                return String(format: "%.0f+", 50 * conc)
            }
            // Reservoir is stored U100-equivalent; scale to the real delivered
            // units for diluted/concentrated insulin (e.g. U200 → ×2).
            let scaled = r * Decimal(conc)
            return String(format: "%.0f", NSDecimalNumber(decimal: scaled).doubleValue)
        }

        /// Red "U200"-style badge text when a non-standard concentration is set
        /// and the user hasn't hidden it. `nil` for standard U100.
        private var reservoirBadge: String? {
            guard insulinConcentration != 1,
                  !state.settingsManager.settings.hideInsulinBadge
            else { return nil }
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            return "U" + (f.string(from: insulinConcentration * 100 as NSNumber) ?? "")
        }

        private var pumpSub: String? {
            guard let exp = state.pumpExpiresAtDate else { return nil }
            let interval = exp.timeIntervalSinceNow
            guard interval > 0 else { return "abgelaufen" }
            // Under an hour the "0 T 0 h" readout is useless — switch to minutes.
            if interval < 3600 {
                return "\(Int(interval / 60)) min"
            }
            let days = Int(interval / 86400)
            let hours = Int((interval - Double(days) * 86400) / 3600)
            return "\(days) T \(hours) h"
        }

        /// Imminent pump/pod expiry warning for the pump tile's leading shield.
        /// `show` once ≤ 4 h of life remain (or expired), `pulsing` once < 2 h
        /// remain (or expired). Returns nil when no expiry date is reported.
        private var pumpExpiryWarning: (show: Bool, pulsing: Bool) {
            guard let exp = state.pumpExpiresAtDate else { return (false, false) }
            let interval = exp.timeIntervalSinceNow
            guard interval <= 4 * 3600 else { return (false, false) }
            return (true, interval < 2 * 3600)
        }

        // MARK: - Ring-corner pills (gated via UIUX toggles)

        /// Top-left: sensor — age or time-remaining depending on UIUX toggles,
        /// auto-surfaces when expiry is within 24 h regardless of toggles.
        /// Icon-color escalates red / orange / amber as expiry approaches.
        ///
        /// Fallback: if the CGM did not report a `sessionStartDate` (so
        /// `calculateSensorInfo()` returns nil), we still show the configured
        /// sensor lifespan as a coarse "Xd" pill so the corner isn't empty.
        private var sensorInfo: (text: String, color: Color)? {
            if let info = state.calculateSensorInfo() {
                let showPill = state.displaySAGE || state.displayExpiration || info.expiresIn <= 24 * 3600
                guard showPill else { return nil }
                let text = info.text.replacingOccurrences(of: "Sensor: ", with: "")
                let color: Color = {
                    if info.expiresIn <= 0 { return .red }
                    if info.expiresIn < 6 * 3600 { return .orange }
                    // No amber stage: it reads poorly on light backgrounds, and
                    // the exclamation-mark shield already signals the upcoming
                    // change clearly enough. Use the standard icon color.
                    return AuroraPalette.textPrimary(scheme)
                }()
                return (text, color)
            }
            // Fallback when sessionStartDate is missing
            guard state.displaySAGE || state.displayExpiration else { return nil }
            let days = Int(state.sensorDays.rounded())
            guard days > 0 else { return nil }
            return ("\(days)d", AuroraPalette.textPrimary(scheme))
        }

        /// Imminent sensor expiry warning for the sensor pill's shield.
        /// `show` once ≤ 12 h of session remain (or expired) — sensors run for
        /// days, so we warn earlier than the pump. `pulsing` once < 2 h remain.
        private var sensorExpiryWarning: (show: Bool, pulsing: Bool) {
            guard let info = state.calculateSensorInfo() else { return (false, false) }
            let interval = info.expiresIn
            guard interval <= 12 * 3600 else { return (false, false) }
            return (true, interval < 2 * 3600)
        }

        /// Top-right: predicted eventual glucose from the latest suggestion.
        private var eventualBGText: String? {
            guard state.displayeventualBG, let eventual = state.eventualBG else { return nil }
            if state.data.units == .mmolL {
                let v = Double(eventual) * 0.0555
                return String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
            }
            return "\(eventual)"
        }

        /// Bottom-left: current temp basal rate.
        private var tbrText: String? {
            guard state.displayTBR else { return nil }
            let rate = state.tempRate.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0
            let formatted = String(format: "%.2f", rate).replacingOccurrences(of: ".", with: ",")
            return "\(formatted) E/h"
        }

        /// Bottom-right: autosens sensitivity ratio.
        private var isfText: String? {
            guard state.isfView else { return nil }
            let ratio = state.data.suggestion?.sensitivityRatio ?? 1
            let v = NSDecimalNumber(decimal: ratio).doubleValue
            return String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
        }

        // MARK: - Active override / temp-target badges (below the stat row)

        private var profileActive: Bool {
            fetchedPercent.first?.enabled ?? false
        }

        /// Compact label for the active-profile badge (mirrors breath's logic).
        private var profileBadgeText: String {
            guard let override = fetchedPercent.first, override.enabled else {
                return "Profil"
            }
            if override.isPreset {
                if let profile = fetchedProfiles.first(where: { $0.id == override.id }),
                   let name = profile.name, !name.isEmpty, name != "EMPTY", name != "\u{0022}\u{0022}"
                {
                    return name.count > 14 ? String(name.prefix(14)) : name
                }
                return "Profil"
            }
            if override.percentage != 100 {
                return "\(Int(override.percentage)) %"
            }
            if override.smbIsOff {
                return "No SMB"
            }
            return "Override"
        }

        private var tempTargetString: String? {
            state.tempTarget?.displayName
        }

        /// True when the currently active override forces AutoISF on.
        private var aisfEnabledByOverride: Bool {
            guard let or = fetchedPercent.first, or.enabled else { return false }
            guard let aisf = fetchedAISF.first(where: { $0.id == or.id }) else { return false }
            return aisf.autoisf
        }

        /// True when the currently active override forces AutoISF off.
        private var aisfDisabledByOverride: Bool {
            guard let or = fetchedPercent.first, or.enabled else { return false }
            guard let aisf = fetchedAISF.first(where: { $0.id == or.id }) else { return false }
            return !aisf.autoisf
        }

        /// Open the right history sheet on ISF-pill tap — AutoISF if active,
        /// Dynamic ISF otherwise. Same dispatching the breath skin used.
        private func openISFHistory() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if (state.autoisf && !aisfDisabledByOverride) || aisfEnabledByOverride {
                displayAutoHistory = true
            } else {
                displayDynamicHistory = true
            }
        }

        // MARK: - Body

        var body: some View {
            ZStack {
                AuroraBackground()

                VStack(spacing: 0) {
                    ringStage
                        .padding(.top, 8)

                    loopPill
                        .padding(.vertical, 8)

                    AuroraMainChart(
                        data: state.data,
                        displayBasal: state.displayMainChartBasalRate,
                        displayCarbs: state.displayChartCarbs,
                        displayBoluses: state.displayChartBoluses,
                        glucoseNow: glucoseValue
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 4)

                    badgeRow
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    activeBadgeRow
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                    bolusOverlay
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .padding(.bottom, 110) // clears the floating tab bar

                AuroraToast(message: $toast)
            }
            .overlay(alignment: .bottom) { tabBar }
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .confirmationDialog(
                "Loop manuell ausführen?",
                isPresented: $showRunLoopConfirm,
                titleVisibility: .visible
            ) {
                Button("Loop jetzt ausführen") {
                    state.runLoop()
                    toast = "Loop gestartet"
                }
                Button("Abbrechen", role: .cancel) {}
            }
            .confirmationDialog(
                "Profil-Override beenden?",
                isPresented: $showCancelOverrideAlert,
                titleVisibility: .visible
            ) {
                Button("Override beenden", role: .destructive) {
                    state.cancelProfile()
                    toast = "Override beendet"
                }
                Button("Abbrechen", role: .cancel) {}
            }
            .confirmationDialog(
                "Temporäres Ziel beenden?",
                isPresented: $showCancelTempTargetAlert,
                titleVisibility: .visible
            ) {
                Button("Ziel beenden", role: .destructive) {
                    state.cancelTempTarget()
                    toast = "Temp-Ziel beendet"
                }
                Button("Abbrechen", role: .cancel) {}
            }
            .sheet(isPresented: $showStatusPopup) {
                AuroraStatusSheet(state: state)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $displayAutoHistory) {
                AutoISFHistoryView(units: state.data.units)
                    .environment(\.colorScheme, scheme)
            }
            .sheet(isPresented: $displayDynamicHistory) {
                DynamicHistoryView(units: state.data.units)
                    .environment(\.colorScheme, scheme)
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active: state.startTimer()
                case .background,
                     .inactive: state.stopTimer()
                default: break
                }
            }
        }

        /// Small glass pill anchored to a corner of the Aurora ring.
        /// Used for sensor / eventual-BG / TBR / ISF when the matching toggle
        /// is on. The icon can be tinted independently of the text (e.g. for
        /// the sensor pill's expiry color).
        private func infoPill(icon: String, text: String, iconColor: Color? = nil) -> some View {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconColor ?? AuroraPalette.textPrimary(scheme))
                Text(text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .auroraGlassPill()
        }

        /// "Stage" around the Aurora ring: the ring is centered in a full-width
        /// container, and the four corner pills are pinned to the SCREEN edges
        /// (not the ring frame). That gives Sensor / Eventual / TBR / ISF the
        /// same generous gutter the breath skin's StatusRow used.
        ///
        /// Tap on the ring → CGM setup (or snooze if a glucose alarm is active),
        /// long-press inverts that pair — mirrors the breath skin's behavior.
        private var ringStage: some View {
            ZStack {
                AuroraRing(
                    glucose: glucoseValue,
                    delta: glucoseDelta,
                    trendCaption: nil,
                    direction: state.recentGlucose?.direction,
                    bolusProgress: state.bolusProgress.map { NSDecimalNumber(decimal: $0).doubleValue },
                    bolusTotal: state.bolusAmount.map { NSDecimalNumber(decimal: $0).doubleValue }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if state.alarm == nil {
                        state.openCGM()
                    } else {
                        state.showModal(for: .snooze)
                    }
                }
                .onLongPressGesture {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    if state.alarm == nil {
                        state.showModal(for: .snooze)
                    } else {
                        state.openCGM()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) {
                if let txt = tbrText {
                    infoPill(icon: "chart.bar", text: txt)
                        .padding(.leading, 18)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
                }
            }
            .overlay(alignment: .topTrailing) {
                if let txt = eventualBGText {
                    infoPill(icon: "arrow.right", text: txt)
                        .padding(.trailing, 18)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let s = sensorInfo {
                    infoPill(
                        icon: "sensor.tag.radiowaves.forward",
                        text: s.text,
                        iconColor: s.color
                    )
                    .overlay(alignment: .topLeading) {
                        let warning = sensorExpiryWarning
                        if warning.show {
                            PulsingWarningShield(
                                color: AuroraGlucoseStatus(mgdl: glucoseValue).main,
                                pulsing: warning.pulsing,
                                size: 16
                            )
                            .offset(x: -6, y: -8)
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let txt = isfText {
                    infoPill(icon: "divide", text: txt)
                        .padding(.trailing, 18)
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { openISFHistory() }
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: state.displayeventualBG)
            .animation(.easeInOut(duration: 0.25), value: state.displayTBR)
            .animation(.easeInOut(duration: 0.25), value: state.isfView)
            .animation(.easeInOut(duration: 0.25), value: state.displaySAGE)
            .animation(.easeInOut(duration: 0.25), value: state.displayExpiration)
        }

        /// Loop pill — sits centered between the ring and the chart.
        /// Tap → status sheet · long-press → run-loop confirmation.
        /// Pulsing ring around the dot while a loop is actually running.
        private var loopPill: some View {
            HStack(spacing: 8) {
                Text(loopCaption)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
                ZStack {
                    Circle()
                        .fill(loopStatus.color)
                        .frame(width: 8, height: 8)
                        .shadow(color: loopStatus.color.opacity(0.5), radius: 6)
                    if state.isLooping {
                        Circle()
                            .stroke(loopStatus.color.opacity(0.6), lineWidth: 1)
                            .frame(width: 16, height: 16)
                            .scaleEffect(state.isLooping ? 1.4 : 1.0)
                            .opacity(state.isLooping ? 0 : 0.8)
                            .animation(
                                .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                value: state.isLooping
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .auroraGlassPill()
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showStatusPopup = true
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showRunLoopConfirm = true
            }
        }

        private var badgeRow: some View {
            HStack(spacing: 10) {
                AuroraStatBadge(
                    icon: "drop.fill",
                    iconColor: AuroraPalette.textMuted(scheme),
                    value: iobString,
                    unit: "E",
                    label: "Aktiv. Insulin"
                )
                AuroraStatBadge(
                    icon: "leaf.fill",
                    iconColor: AuroraPalette.textMuted(scheme),
                    value: cobString,
                    unit: "g",
                    label: "Kohlenhydrate"
                )
                AuroraStatBadge(
                    icon: "cylinder.fill",
                    iconColor: AuroraPalette.textMuted(scheme),
                    value: reservoirString,
                    unit: "E",
                    label: pumpSub.map { "Pumpe \($0)" } ?? "Pumpe",
                    sub: nil,
                    badge: reservoirBadge,
                    badgeColor: AuroraGlucoseStatus(mgdl: glucoseValue).main,
                    warning: pumpExpiryWarning.show,
                    warningPulsing: pumpExpiryWarning.pulsing,
                    warningColor: AuroraGlucoseStatus(mgdl: glucoseValue).main,
                    onTap: {
                        // Mirror breath: only open settings when a pump is
                        // actually connected — otherwise the modal has nothing
                        // to show.
                        if state.pumpDisplayState != nil {
                            state.setupPump = true
                        }
                    }
                )
            }
        }

        private var tabBar: some View {
            AuroraTabBar(
                glucose: glucoseValue,
                showOverride: state.profileButton,
                showTempTarget: state.useTargetButton,
                profileActive: profileActive,
                targetActive: state.tempTarget != nil,
                onCarbs: {
                    state.showModal(for: .addCarbs(editMode: false, override: false, mode: .meal))
                },
                onBolus: {
                    state.showModal(for: .bolus(waitForSuggestion: true, fetch: false))
                },
                onDataTable: { state.showModal(for: .dataTable) },
                onStatistics: { state.showModal(for: .statistics) },
                onProfile: {
                    // If an override is already running, tapping the icon
                    // offers to end it (same dialog as the active badge).
                    // Otherwise open the config modal as before.
                    if profileActive {
                        showCancelOverrideAlert = true
                    } else {
                        state.showModal(for: .overrideProfilesConfig)
                    }
                },
                onTarget: {
                    if state.tempTarget != nil {
                        showCancelTempTargetAlert = true
                    } else {
                        state.showModal(for: .addTempTarget)
                    }
                },
                onSettings: { state.showModal(for: .settings) }
            )
        }

        /// Live bolus banner — only visible while a bolus is delivering.
        /// Sits between the active-override badges and the floating action bar
        /// so the user always has Stop within thumb reach.
        @ViewBuilder private var bolusOverlay: some View {
            if let progress = state.bolusProgress, progress > 0,
               let amount = state.bolusAmount
            {
                AuroraBolusOverlay(
                    progress: progress,
                    delivered: amount * progress,
                    total: amount,
                    accent: AuroraGlucoseStatus(mgdl: glucoseValue).main,
                    onCancel: { state.cancelBolus() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }

        /// Two compact glass pills — visible only when a profile override or a
        /// temp target is currently active. Tap → confirmation dialog to cancel.
        /// Mirrors the breath skin's "ActiveBadge" row right under the stat
        /// cards so the user always sees what's bending the loop.
        @ViewBuilder private var activeBadgeRow: some View {
            HStack(spacing: 10) {
                if profileActive {
                    activeBadge(
                        dotColor: AuroraPalette.pump,
                        text: profileBadgeText,
                        accessibility: "Aktives Profil — antippen zum Beenden"
                    ) {
                        showCancelOverrideAlert = true
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                }
                if let tt = tempTargetString {
                    activeBadge(
                        dotColor: AuroraPalette.Status.inMain,
                        text: tt,
                        accessibility: "Temporäres Ziel — antippen zum Beenden"
                    ) {
                        showCancelTempTargetAlert = true
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.25), value: profileActive)
            .animation(.easeInOut(duration: 0.25), value: tempTargetString)
        }

        private func activeBadge(
            dotColor: Color,
            text: String,
            accessibility: String,
            action: @escaping () -> Void
        ) -> some View {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: dotColor.opacity(0.5), radius: 4)
                    Text(text)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AuroraPalette.textPrimary(scheme))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .auroraGlassPill()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibility))
        }
    }
}

// MARK: - Bolus overlay (live banner)

/// A calm glass banner shown while a bolus is in flight. Replaces the breath
/// skin's blue-drop overlay — the live status color drives the accent so the
/// banner sits visually with the rest of the Aurora skin.
struct AuroraBolusOverlay: View {
    let progress: Decimal
    let delivered: Decimal
    let total: Decimal
    let accent: Color
    let onCancel: () -> Void

    @State private var pulse = false
    @State private var cancelPressed = false
    @StateObject private var smooth = AuroraBolusProgressAnimator()

    @Environment(\.colorScheme) private var scheme

    /// Truthful pump fraction — drives the numeric "delivered" readout.
    private var realFraction: Double {
        let p = NSDecimalNumber(decimal: progress).doubleValue
        return min(1.0, max(0.0, p))
    }

    private var deliveredString: String {
        let d = NSDecimalNumber(decimal: delivered).doubleValue
        let t = NSDecimalNumber(decimal: total).doubleValue
        return String(format: "%.2f / %.2f E", d, t)
            .replacingOccurrences(of: ".", with: ",")
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AuroraPalette.textMuted(scheme))
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .opacity(pulse ? 1.0 : 0.75)
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: pulse
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Bolus läuft")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    Text(deliveredString)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AuroraPalette.textMuted(scheme))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    withAnimation(.easeOut(duration: 0.12)) { cancelPressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.easeOut(duration: 0.25)) { cancelPressed = false }
                    }
                    onCancel()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Stoppen")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accent)
                            .shadow(
                                color: accent.opacity(0.35),
                                radius: cancelPressed ? 2 : 6,
                                y: cancelPressed ? 1 : 2
                            )
                    )
                    .scaleEffect(cancelPressed ? 0.96 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Bolus stoppen"))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AuroraPalette.hairline(scheme).opacity(0.8))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.6), accent],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * smooth.fraction))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .auroraGlass(radius: 18)
        .onAppear {
            pulse = true
            smooth.sync(real: realFraction, total: NSDecimalNumber(decimal: total).doubleValue)
        }
        .onChange(of: progress) { _ in
            smooth.sync(real: realFraction, total: NSDecimalNumber(decimal: total).doubleValue)
        }
    }
}

// MARK: - Status sheet (Loop details + manual loop trigger)

/// Aurora-style sheet shown when the user taps the loop pill in the top row.
/// Surfaces the current loop status, last loop time, optional error message,
/// the suggestion's reasoning conclusion, and a primary "Loop jetzt ausführen"
/// action.
struct AuroraStatusSheet: View {
    @ObservedObject var state: Home.StateModel

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    private var loopAccent: Color {
        if state.errorMessage != nil { return AuroraLoopStatus.error.color }
        if state.isLooping { return AuroraLoopStatus.looping.color }
        let age = Date().timeIntervalSince(state.lastLoopDate)
        return age > 15 * 60 ? AuroraLoopStatus.stale.color : AuroraLoopStatus.ok.color
    }

    private var lastLoopText: String {
        guard state.lastLoopDate != .distantPast else { return "—" }
        let mins = Int(-state.lastLoopDate.timeIntervalSinceNow / 60)
        if mins < 1 { return "gerade eben" }
        if mins < 60 { return "vor \(mins) Min" }
        return "vor \(mins / 60) h"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let err = state.errorMessage {
                    errorCard(err)
                }

                statusCard
                reasoningCard

                AuroraPrimaryButton(
                    title: state.isLooping ? "Loop läuft …" : "Loop jetzt ausführen",
                    accent: loopAccent
                ) {
                    state.runLoop()
                    dismiss()
                }
                .disabled(state.isLooping)
                .opacity(state.isLooping ? 0.6 : 1.0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(AuroraBackground())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Loop-Status")
                .font(.system(size: 28, weight: .heavy))
                .kerning(-0.5)
                .foregroundStyle(AuroraPalette.textPrimary(scheme))
            Text("Letzter Lauf \(lastLoopText)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AuroraPalette.textMuted(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(loopAccent)
                .frame(width: 12, height: 12)
                .shadow(color: loopAccent.opacity(0.5), radius: 6)
            Text(state.statusTitle.isEmpty ? "Bereit" : state.statusTitle)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(AuroraPalette.textPrimary(scheme))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .auroraGlass(radius: 22)
    }

    @ViewBuilder private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Letzter Loop fehlgeschlagen")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AuroraLoopStatus.error.color)
            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AuroraPalette.textMuted(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .auroraGlass(radius: 22)
    }

    @ViewBuilder private var reasoningCard: some View {
        if let suggestion = state.data.suggestion {
            VStack(alignment: .leading, spacing: 8) {
                Text("Algorithmus-Begründung")
                    .font(.system(size: 12.5, weight: .semibold))
                    .kerning(0.4)
                    .foregroundStyle(AuroraPalette.textMuted(scheme))
                Text(suggestion.reasonConclusion.capitalizingFirstLetter())
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .auroraGlass(radius: 22)
        }
    }
}
