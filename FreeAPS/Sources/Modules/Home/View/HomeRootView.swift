import Charts
import CoreData
import SpriteKit
import SwiftDate
import SwiftUI
import Swinject

extension Home {
    struct RootView: BaseView {
        let resolver: Resolver

        @StateObject var state: StateModel
        @State var isStatusPopupPresented = false
        @State var showCancelAlert = false
        @State var showCancelTTAlert = false
        @State var showBasalInfo = false
        @State var triggerUpdate = false
        @State var display = false
        @State var displayGlucose = false
        @State var animateLoop = Date.distantPast
        @State var animateTIR = Date.distantPast
        @State var showBolusActiveAlert = false
        @State var displayAutoHistory = false
        @State var displayDynamicHistory = false
        @State var showActionSheet = false
        @State var showFirstRunBackupPrompt = false

        let buttonFont = Font.custom("TimeButtonFont", size: 14)
        let viewPadding: CGFloat = 5

        @Environment(\.managedObjectContext) var moc
        @Environment(\.sizeCategory) private var fontSize
        @Environment(\.colorScheme) var colorScheme

        @FetchRequest(
            entity: Override.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var fetchedPercent: FetchedResults<Override>

        @FetchRequest(
            entity: OverridePresets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], predicate: NSPredicate(
                format: "name != %@", "" as String
            )
        ) var fetchedProfiles: FetchedResults<OverridePresets>

        @FetchRequest(
            entity: Auto_ISF.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var fetchedAISF: FetchedResults<Auto_ISF>

        @FetchRequest(
            entity: TempTargets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var sliderTTpresets: FetchedResults<TempTargets>

        @FetchRequest(
            entity: TempTargetsSlider.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var enactedSliderTT: FetchedResults<TempTargetsSlider>

        @FetchRequest(
            entity: InsulinConcentration.entity(),
            sortDescriptors: [NSSortDescriptor(
                key: "date",
                ascending: true
            )]
        ) var concentration: FetchedResults<InsulinConcentration>

        @FetchRequest(
            entity: Onboarding.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var onboarded: FetchedResults<Onboarding>

        private let numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }()

        private let fetchedTargetFormatterMmol: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }()

        private let fetchedTargetFormatterMgdl: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }()

        private var fetchedTargetFormatter: NumberFormatter {
            state.data.units == .mmolL ? fetchedTargetFormatterMmol : fetchedTargetFormatterMgdl
        }

        private let targetFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }()

        private let tirFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }()

        private let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            return dateFormatter
        }()

        private var remainingTimeFormatter: DateComponentsFormatter {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day, .hour]
            formatter.unitsStyle = .abbreviated
            return formatter
        }

        private var remainingTimeFormatterDays: DateComponentsFormatter {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day]
            formatter.unitsStyle = .abbreviated
            return formatter
        }

        private var spriteScene: SKScene {
            let scene = SnowScene()
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            return scene
        }

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 1
            return formatter
        }

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var glucoseView: some View {
            breathingOrbView
                .overlay(alignment: .topLeading) {
                    sensorBadgeView
                        .padding(.leading, 10)
                        .padding(.top, 6)
                }
                .overlay(alignment: .topTrailing) {
                    eventualBadgeView
                        .padding(.trailing, 10)
                        .padding(.top, 6)
                }
                .onTapGesture {
                    if state.alarm == nil {
                        state.openCGM()
                    } else {
                        state.showModal(for: .snooze)
                    }
                }
                .onLongPressGesture {
                    let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                    impactHeavy.impactOccurred()
                    if state.alarm == nil {
                        state.showModal(for: .snooze)
                    } else {
                        state.openCGM()
                    }
                }
        }

        @ViewBuilder private var sensorBadgeView: some View {
            if state.displaySAGE || state.displayExpiration,
               let info = state.calculateSensorInfo()
            {
                let dotColor: Color = {
                    if info.timeToShow <= 0 { return .red }
                    if info.timeToShow < 6 * 3600 { return .orange }
                    if info.timeToShow < 24 * 3600 { return BreathePalette.kamille }
                    return .primary.opacity(0.5)
                }()
                let text = info.text
                    .replacingOccurrences(of: "Sensor: ", with: "")
                Home.ActiveBadge(
                    dotColor: dotColor,
                    text: text,
                    systemImage: "sensor.tag.radiowaves.forward.fill"
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
            }
        }

        /// Top-right badge showing the predicted "eventual" glucose from the
        /// last loop suggestion. Controlled by the `displayeventualBG` setting.
        @ViewBuilder private var eventualBadgeView: some View {
            if state.displayeventualBG, let eventual = state.eventualBG {
                let isMmol = state.data.units == .mmolL
                let converted: Double = isMmol
                    ? Double(eventual) * 0.0555
                    : Double(eventual)
                let text: String = {
                    if isMmol {
                        return String(format: "%.1f", converted)
                            .replacingOccurrences(of: ".", with: ",")
                    } else {
                        return "\(Int(converted.rounded()))"
                    }
                }()
                Home.ActiveBadge(
                    dotColor: .primary,
                    text: text,
                    systemImage: "arrow.right"
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
            }
        }

        /// Breathing Orb variant — Breathe humane-redesign glucose display.
        private var breathingOrbView: some View {
            let recent = state.recentGlucose
            let glucoseMgDl = Decimal(recent?.glucose ?? 0)
            let displayValue: Decimal = state.data.units == .mmolL
                ? glucoseMgDl.asMmolL
                : glucoseMgDl
            return BreathingGlucoseOrb(
                glucose: displayValue,
                units: state.data.units,
                lowThreshold: state.data.lowGlucose,
                highThreshold: state.data.highGlucose,
                direction: recent?.direction,
                delta: state.glucoseDelta,
                minutesAgo: nil,
                size: 160
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }

        var pumpView: some View {
            PumpView(
                reservoir: $state.reservoir,
                battery: $state.battery,
                name: $state.pumpName,
                expiresAtDate: $state.pumpExpiresAtDate,
                timerDate: $state.data.timerDate, timeZone: $state.timeZone,
                state: state
            )
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
            .offset(y: 1)
        }

        var tempBasalString: String {
            guard let tempRate = state.tempRate else {
                return "?" + NSLocalizedString(" U/hr", comment: "Unit per hour with space")
            }
            let rateString = numberFormatter.string(from: tempRate as NSNumber) ?? "0"
            var manualBasalString = ""

            if state.apsManager.isManualTempBasal {
                manualBasalString = NSLocalizedString(
                    " Manual",
                    comment: "Manual Temp basal"
                )
            }
            return rateString + " " + NSLocalizedString(" U/hr", comment: "Unit per hour with space") + manualBasalString
        }

        var tempTargetString: String? {
            guard let tempTarget = state.tempTarget else {
                return nil
            }
            return tempTarget.displayName
        }

        var info: some View {
            HStack(spacing: 10) {
                ZStack {
                    HStack {
                        if state.pumpSuspended {
                            Text("Pump suspended")
                                .font(.extraSmall).bold().foregroundColor(.loopGray)
                        } else {
                            Text(tempBasalString)
                                .font(.statusFont).bold()
                                .foregroundColor(.insulin)
                        }
                    }
                }
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let tempTargetString = tempTargetString, !(fetchedPercent.first?.enabled ?? false) {
                    Text(tempTargetString)
                        .font(.buttonFont)
                        .foregroundColor(.secondary)
                } else {
                    profileView
                }

                ZStack {
                    HStack {
                        Text("⇢").font(.statusFont).foregroundStyle(.secondary)

                        if let eventualBG = state.eventualBG {
                            Text(
                                fetchedTargetFormatter.string(
                                    from: (state.data.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                                ) ?? ""
                            ).font(.statusFont).foregroundColor(colorScheme == .dark ? .white : .black)
                        } else {
                            Text("?").font(.statusFont).foregroundStyle(.secondary)
                        }
                        Text(state.data.units.rawValue).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }

        var infoPanel: some View {
            info.frame(height: 26)
                .background {
                    InfoPanelBackground(colorScheme: colorScheme)
                }
        }

        var mainChart: some View {
            ZStack {
                if state.animatedBackground {
                    SpriteView(scene: spriteScene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                BreatheMainChart(data: state.data)
            }
            // .padding(.bottom, 5)
            .modal(for: .dataTable, from: self)
        }

        var chart: some View {
            // let ratio = 2.8

            // let chartRatio: CGFloat = 3.6
            let chartRatio: CGFloat = 3.4
            let chartMinHeight = UIScreen.main.bounds.height / chartRatio

            return mainChart
                .frame(minHeight: chartMinHeight)
        }

        // MARK: - Statistik & Info Panels

        var activeIOBView: some View {
            VStack {
                ActiveIOBView(data: $state.iobData)
                    .padding(15)
            }
            .frame(minHeight: 190)
            .elegantShadow(scheme: colorScheme)
            .padding(.horizontal, 10)
        }

        var activeCOBView: some View {
            VStack {
                ActiveCOBView(data: $state.iobData)
                    .padding(15)
            }
            .frame(minHeight: 190)
            .elegantShadow(scheme: colorScheme)
            .padding(.horizontal, 10)
        }

        var profileView: some View {
            HStack(spacing: 0) {
                if let override = fetchedPercent.first {
                    if override.enabled {
                        if override.isPreset {
                            let profile = fetchedProfiles.first(where: { $0.id == override.id })
                            if let currentProfile = profile {
                                if let name = currentProfile.name, name != "EMPTY", name.nonEmpty != nil, name != "",
                                   name != "\u{0022}\u{0022}"
                                {
                                    if name.count > 15 {
                                        let shortened = name.prefix(15)
                                        Text(shortened).font(.statusFont).foregroundStyle(.secondary)
                                    } else {
                                        Text(name).font(.statusFont).foregroundStyle(.secondary)
                                    }
                                }
                            } else { Text("📉") } // Hypo Treatment is not actually a preset
                        } else if override.percentage != 100 {
                            Text((tirFormatter.string(from: override.percentage as NSNumber) ?? "") + " %").font(.statusFont)
                                .foregroundStyle(.secondary)
                        } else if override.smbIsOff, !override.smbIsAlwaysOff {
                            Text("No ").font(.statusFont).foregroundStyle(.secondary) // "No" as in no SMBs
                            Image(systemName: "syringe")
                                .font(.previewNormal).foregroundStyle(.secondary)
                        } else if override.smbIsOff {
                            Image(systemName: "clock").font(.statusFont).foregroundStyle(.secondary)
                            Image(systemName: "syringe")
                                .font(.previewNormal).foregroundStyle(.secondary)
                        } else {
                            Text("Override").font(.statusFont).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
            VStack(spacing: 2) {
                Color.clear
                    .frame(height: geo.safeAreaInsets.top + 5)

                glucoseView
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    .padding(.bottom, 25)
            }
            .background(Color.clear)
        }

        /// Row of small badges directly under the four watches.
        /// Slot 1 — Basal/Temp-Target badge centered under Insulin tile
        ///          (toggled by tapping the Insulin tile).
        /// Slot 2 — Active profile override badge (tap → cancel dialog).
        /// Slot 3 — Active temporary target badge (tap → cancel dialog).
        /// Slot 4 — ISF badge centered under Loop tile
        ///          (toggled via Settings switch — `state.isfView`).
        private var breatheBadgeRow: some View {
            HStack(spacing: 10) {
                ZStack {
                    if showBasalInfo {
                        Home.BasalInfoBadge(text: Home.breatheTempBasalText(state: state))
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)

                ZStack {
                    if profileActive {
                        ActiveBadge(
                            dotColor: BreathePalette.salbei,
                            text: profileBadgeText
                        ) {
                            showCancelAlert = true
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)

                ZStack {
                    if let tt = tempTargetString {
                        ActiveBadge(
                            dotColor: BreathePalette.flieder,
                            text: tt
                        ) {
                            showCancelTTAlert = true
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)

                ZStack {
                    if !state.isfView {
                        isfView
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)
            }
            .padding(.horizontal, 10)
            .animation(.easeInOut(duration: 0.25), value: showBasalInfo)
            .animation(.easeInOut(duration: 0.25), value: profileActive)
            .animation(.easeInOut(duration: 0.25), value: tempTargetString)
        }

        /// Whether a profile override is currently enabled.
        private var profileActive: Bool {
            fetchedPercent.first?.enabled ?? false
        }

        /// Label text for the active-profile badge. Mirrors the logic of
        /// `profileView` but collapses everything into a single compact string.
        private var profileBadgeText: String {
            guard let override = fetchedPercent.first, override.enabled else {
                return NSLocalizedString("Profil", comment: "Profile badge fallback")
            }
            if override.isPreset {
                if let profile = fetchedProfiles.first(where: { $0.id == override.id }),
                   let name = profile.name,
                   name != "EMPTY", name.nonEmpty != nil, name != "", name != "\u{0022}\u{0022}"
                {
                    return name.count > 14 ? String(name.prefix(14)) : name
                }
                return NSLocalizedString("Profil", comment: "Profile badge fallback")
            }
            if override.percentage != 100 {
                let pct = tirFormatter.string(from: override.percentage as NSNumber) ?? ""
                return "\(pct) %"
            }
            if override.smbIsOff {
                return NSLocalizedString("No SMB", comment: "Profile badge: SMBs off")
            }
            return NSLocalizedString("Override", comment: "Profile badge default label")
        }

        private var isfView: some View {
            HStack(spacing: 5) {
                Image(systemName: "divide")
                    .font(.system(size: 10, weight: .medium))
                Text(String(describing: state.data.suggestion?.sensitivityRatio ?? 1))
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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
            .onTapGesture {
                if (state.autoisf && !disabled()) || enabled() {
                    displayAutoHistory.toggle()
                } else {
                    displayDynamicHistory.toggle()
                }
            }
        }

        private func enabled() -> Bool {
            guard let or = fetchedPercent.first, or.enabled else { return false }
            guard let aisf = fetchedAISF.first(where: { $0.id == or.id }) else { return false }
            return aisf.autoisf
        }

        private func disabled() -> Bool {
            guard let or = fetchedPercent.first, or.enabled else { return false }
            guard let aisf = fetchedAISF.first(where: { $0.id == or.id }) else { return false }
            return !aisf.autoisf
        }

        private var animateLoopView: Bool {
            -1 * animateLoop.timeIntervalSinceNow < 1.5
        }

        private var animateTIRView: Bool {
            -1 * animateTIR.timeIntervalSinceNow < 1.5
        }

        private func timeIsNowLoop() {
            animateLoop = Date.now
        }

        private func timeIsNowTIR() {
            animateTIR = Date.now
        }

        private var animation: any View {
            ActivityIndicator(isAnimating: .constant(true), style: .large)
        }

        @Environment(\.scenePhase) private var scenePhase

        var body: some View {
            GeometryReader { geo in
                if onboarded.first?.firstRun ?? true, let openAPSSettings = state.openAPSSettings {
                    /// If old iAPS user pre v5.7.1 OpenAPS settings will be reset, but can be restored in View below
                    importResetSettingsView(settings: openAPSSettings)
                } else {
                    mainScreen(geo: geo)
                }
            }
            .onAppear {
                if onboarded.first?.firstRun ?? true {
                    showFirstRunBackupPrompt = true
                    state.fetchPreferences()
                }
            }
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .sheet(isPresented: $displayAutoHistory) {
                AutoISFHistoryView(units: state.data.units)
                    .environment(\.colorScheme, colorScheme)
            }
            .sheet(isPresented: $displayDynamicHistory) {
                DynamicHistoryView(units: state.data.units)
                    .environment(\.colorScheme, colorScheme)
            }
            .fullScreenCover(isPresented: $showFirstRunBackupPrompt) {
                FirstRunRestorePromptView(resolver: resolver) {
                    CoreDataStorage().saveOnbarding()
                    showFirstRunBackupPrompt = false
                }
            }
            .popup(isPresented: state.isStatusPopupPresented, alignment: .bottom, direction: .bottom) {
                popup
                    .padding(.bottom, 80)
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.height > 0 {
                                    state.isStatusPopupPresented = false
                                }
                            }
                    )

                    .alert("Bolus is already running", isPresented: $showBolusActiveAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("A bolus is already being administered. Please wait.")
                    }
            }
        }

        // MARK: - Body decomposition (keeps type-checker budget sane)

        @ViewBuilder private func mainScreen(geo: GeometryProxy) -> some View {
            mainStack(geo: geo)
                .overlay(alignment: .bottom) { bottomFAB(geo: geo) }
                .overlay(alignment: .bottom) { bolusOverlay(geo: geo) }
                .animation(.easeInOut(duration: 0.3), value: state.bolusProgress)
                .sheet(isPresented: $showActionSheet) { actionSheetContent }
                .confirmationDialog("Cancel Profile Override", isPresented: $showCancelAlert) {
                    Button("Cancel Profile Override", role: .destructive) {
                        state.cancelProfile()
                        triggerUpdate.toggle()
                    }
                }
                .confirmationDialog("Cancel Temporary Target", isPresented: $showCancelTTAlert) {
                    Button("Cancel Temporary Target", role: .destructive) {
                        state.cancelTempTarget()
                        triggerUpdate.toggle()
                    }
                }
                .confirmationDialog("Bolus already in Progress", isPresented: $showBolusActiveAlert) {
                    Button("Bolus already in Progress!", role: .destructive) {
                        showBolusActiveAlert = false
                    }
                }
                .background(
                    colorScheme == .light ? BreathePalette.dunstLight : BreathePalette.dunstDark
                )
                .sheet(isPresented: $displayAutoHistory) {
                    AutoISFHistoryView(units: state.data.units)
                        .environment(\.colorScheme, colorScheme)
                }
                .sheet(isPresented: $displayDynamicHistory) {
                    DynamicHistoryView(units: state.data.units)
                        .environment(\.colorScheme, colorScheme)
                }
                .overlay(statusPopupDimmer)
                .ignoresSafeArea(edges: .vertical)
                .onChange(of: scenePhase) {
                    switch scenePhase {
                    case .active:
                        state.startTimer()
                    case .background,
                         .inactive:
                        state.stopTimer()
                    default:
                        break
                    }
                }
        }

        @ViewBuilder private func mainStack(geo: GeometryProxy) -> some View {
            VStack(spacing: 0) {
                headerView(geo)
                ScrollView {
                    VStack {
                        chart
                        BreatheStatusRow(state: state, showBasalInfo: $showBasalInfo)
                            .padding(.top, 28)
                            .padding(.bottom, 8)
                        breatheBadgeRow
                            .padding(.bottom, 25)
                    }
                    .background { scrollTracker }
                }
                .coordinateSpace(name: "HomeScrollView")
            }
        }

        private var scrollTracker: some View {
            GeometryReader { proxy in
                let scrollPosition = proxy.frame(in: .named("HomeScrollView")).minY
                let yThreshold: CGFloat = -550
                Color.clear
                    .onChange(of: scrollPosition) {
                        if scrollPosition < yThreshold, state.iobs > 0 || state.carbData > 0,
                           !state.skipGlucoseChart
                        {
                            withAnimation(.easeOut(duration: 0.3)) { displayGlucose = true }
                        } else {
                            withAnimation(.easeOut(duration: 0.4)) { displayGlucose = false }
                        }
                    }
            }
        }

        @ViewBuilder private func bottomFAB(geo: GeometryProxy) -> some View {
            BreathePlusFAB { showActionSheet = true }
                .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom + 8 : 24)
        }

        @ViewBuilder private func bolusOverlay(geo: GeometryProxy) -> some View {
            if let progress = state.bolusProgress, progress > 0,
               let amount = state.bolusAmount
            {
                let safeBottom = geo.safeAreaInsets.bottom > 0
                    ? geo.safeAreaInsets.bottom + 8 : 24
                BreatheBolusOverlay(
                    progress: progress,
                    delivered: amount * progress,
                    total: amount,
                    onCancel: { state.cancelBolus() }
                )
                .padding(.bottom, safeBottom + 64 + 14)
            }
        }

        @ViewBuilder private var statusPopupDimmer: some View {
            if state.isStatusPopupPresented {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { state.isStatusPopupPresented = false }
            }
        }

        // MARK: Action Sheet wiring

        private var actionSheetContent: some View {
            BreatheActionSheet(
                isPresented: $showActionSheet,
                isOverride: fetchedPercent.first?.enabled ?? false,
                isTarget: state.tempTarget != nil,
                onProfile: handleProfileTap,
                onTempTarget: handleTempTargetTap,
                onStatistics: handleStatisticsTap,
                onUIUX: handleUIUXTap,
                onSettings: handleSettingsTap
            )
        }

        private func handleProfileTap() {
            let active = fetchedPercent.first?.enabled ?? false
            showActionSheet = false
            if active { showCancelAlert = true }
            else { state.showModal(for: .overrideProfilesConfig) }
        }

        private func handleTempTargetTap() {
            let active = state.tempTarget != nil
            showActionSheet = false
            if active { showCancelTTAlert = true }
            else { state.showModal(for: .addTempTarget) }
        }

        private func handleStatisticsTap() {
            showActionSheet = false
            state.showModal(for: .statistics)
        }

        private func handleUIUXTap() {
            showActionSheet = false
            state.showModal(for: .uiConfig)
        }

        private func handleSettingsTap() {
            showActionSheet = false
            state.showModal(for: .settings)
        }

        private var popupStatusBadgeColor: Color {
            guard let suggestion = state.data.suggestion, suggestion.timestamp != nil else {
                return .secondary
            }
            let delta = state.data.timerDate.timeIntervalSince(state.lastLoopDate) - 30

            if delta <= 5.minutes.timeInterval {
                guard suggestion.deliverAt != nil else { return .loopYellow }
                return .loopGreen
            } else if delta <= 10.minutes.timeInterval {
                return .loopYellow
            } else {
                return .loopRed
            }
        }

        private var popupStatusBadgeTextColor: Color {
            if popupStatusBadgeColor == .secondary {
                return .black
            }
            return colorScheme == .dark
                ? Color(red: 25.0 / 255.0, green: 39.0 / 255.0, blue: 53.0 / 255.0, opacity: 1.0)
                : .white
        }

        private var popup: some View {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Loop Status")
                        .font(.headline)
                        .bold()

                    Text(state.statusTitle)
                        .font(.subheadline)
                        .bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundColor(popupStatusBadgeTextColor)
                        .background(popupStatusBadgeColor)
                        .clipShape(Capsule())
                }

                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            "\(NSLocalizedString("Loop at", comment: "")) \(dateFormatter.string(from: date)) \(NSLocalizedString("failed.", comment: ""))"
                        )
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.loopRed)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.loopRed)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let suggestion = state.data.suggestion, (suggestion.bg ?? 100) == 400 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invalid CGM reading (HIGH).")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.red)
                        Text("SMBs and High Temps Disabled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let suggestion = state.data.suggestion {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest Raw Algorithm Output")
                            .font(.headline)
                            .bold()

                        Text("iAPS is currently using these metrics and values:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TagCloudView(tags: suggestion.reasonParts)
                            .animation(.none, value: false)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Algorithm Reasoning")
                            .font(.headline)
                            .bold()

                        Text(suggestion.reasonConclusion.capitalizingFirstLetter())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("No suggestion found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Button {
                    state.isStatusPopupPresented = false
                } label: {
                    Text("Got it!")
                        .bold()
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .light ? BreathePalette.dunstLight : BreathePalette.dunstDark)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.22 : 0.07),
                        radius: 10, x: 0, y: 5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }

        private func importResetSettingsView(settings: Preferences) -> some View {
            Restore.RootView(
                resolver: resolver,
                openAPS: settings
            )
        }
    }
}
