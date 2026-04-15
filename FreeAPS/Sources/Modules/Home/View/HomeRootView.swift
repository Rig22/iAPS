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
        @State var triggerUpdate = false
        @State var display = false
        @State var displayGlucose = false
        @State var animateLoop = Date.distantPast
        @State var animateTIR = Date.distantPast
        @State var showBolusActiveAlert = false
        @State var displayAutoHistory = false
        @State var displayDynamicHistory = false

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

        /// Breathing Orb variant — Zen Breath humane-redesign glucose display.
        private var breathingOrbView: some View {
            let recent = state.recentGlucose
            let glucoseMgDl = Decimal(recent?.glucose ?? 0)
            let displayValue: Decimal = state.data.units == .mmolL
                ? glucoseMgDl.asMmolL
                : glucoseMgDl
            // Show "minutes since last loop" rather than "minutes since last CGM tick" —
            // the loop status is what tells the user the system is alive.
            let minutesSinceLoop: Double? = state.lastLoopDate == .distantPast
                ? nil
                : -1 * state.lastLoopDate.timeIntervalSinceNow / 60

            return BreathingGlucoseOrb(
                glucose: displayValue,
                units: state.data.units,
                lowThreshold: state.data.lowGlucose,
                highThreshold: state.data.highGlucose,
                direction: recent?.direction,
                delta: state.displayDelta ? state.glucoseDelta : nil,
                minutesAgo: minutesSinceLoop,
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
                MainChartView(data: state.data, triggerUpdate: $triggerUpdate)
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
                // .padding(.vertical, 10)
                // .padding(.horizontal, 10)
                .frame(minHeight: chartMinHeight)
                .background(
                    Group {
                        if colorScheme != .dark {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                // 1. Schatten: Weiche, weite Streuung für die Tiefe
                                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
                                // 2. Schatten: Scharfer Kernschatten für die Kontur
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                        } else {
                            Color.clear
                        }
                    }
                )
                .padding(.horizontal, 10) // Gesamtbreite
        }

        @ViewBuilder private func buttonPanel(_ geo: GeometryProxy) -> some View {
            let isOverride = fetchedPercent.first?.enabled ?? false
            let isTarget = (state.tempTarget != nil)

            ButtonPanelView(
                geo: geo,
                state: state,
                showCancelAlert: $showCancelAlert,
                showCancelTTAlert: $showCancelTTAlert,
                tempBasalString: tempBasalString,
                isOverride: isOverride,
                profileButton: true,
                isTarget: isTarget,
                displayAutoHistory: $displayAutoHistory,
                onBolusButtonTap: {
                    if state.bolusProgress != nil {
                        showBolusActiveAlert = true
                    } else {
                        state.showModal(for: .bolus(waitForSuggestion: state.useCalc ? true : false, fetch: false))
                    }
                }
            )
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
        }

        struct ButtonPanelView: View {
            let geo: GeometryProxy
            @ObservedObject var state: StateModel
            @Binding var showCancelAlert: Bool
            @Binding var showCancelTTAlert: Bool
            let tempBasalString: String
            @Environment(\.colorScheme) var colorScheme
            let isOverride: Bool
            let profileButton: Bool
            let isTarget: Bool
            @Binding var displayAutoHistory: Bool
            let onBolusButtonTap: () -> Void

            var body: some View {
                VStack {
                    HStack(spacing: 0) {
                        if state.carbButton {
                            // 1. Kohlenhydrate Button
                            Button {
                                state.showModal(for: .addCarbs(
                                    editMode: false,
                                    override: false,
                                    mode: .meal
                                ))
                            } label: {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(.orange.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .contextMenu {
                                Button {
                                    state
                                        .showModal(for: .addCarbs(
                                            editMode: false,
                                            override: false,
                                            mode: .presets
                                        )) }
                                label: { Label("Meal Presets", systemImage: "menucard")
                                }
                                Button {
                                    state
                                        .showModal(for: .addCarbs(
                                            editMode: false,
                                            override: false,
                                            mode: .barcode
                                        )) }
                                label: { Label("Barcode", systemImage: "barcode.viewfinder")
                                }
                                if state.ai {
                                    Button {
                                        state
                                            .showModal(for: .addCarbs(
                                                editMode: false,
                                                override: false,
                                                mode: .image
                                            )) }
                                    label: {
                                        Label(
                                            "AI Image Analysis",
                                            systemImage: "photo.badge.magnifyingglass"
                                        )
                                    }
                                }
                                Button {
                                    state
                                        .showModal(for: .addCarbs(
                                            editMode: false,
                                            override: false,
                                            mode: .meal
                                        )) }
                                label: { Label("Add Meal", systemImage: "birthday.cake")
                                }
                            }
                        }

                        // 2. Bolus Button
                        Button(action: onBolusButtonTap) {
                            Image(systemName: "syringe")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.blue.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)

                        // 3. NEU: Statistik Button
                        Button {
                            state.showModal(for: .statistics)
                        } label: {
                            /* Image(
                                 systemName: // "chart.xyaxis.line")
                                 "chart.pie"
                             )*/
                            /*  DonutIconView()
                             .opacity(0.8)
                             .frame(width: 22, height: 22)*/
                            MealsDonutIconView(
                                carbs: 60,
                                fat: 20,
                                protein: 20
                            )
                            .frame(width: 26, height: 26)
                            .opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)

                        // Zentraler Plus Button
                        Menu {
                            // SEKTION 1: Direkte Aktionen
                            Section(header: Text("Aktionen")) {
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                                    impact.impactOccurred()
                                    state.runLoop()
                                }) {
                                    Label("Run Loop", systemImage: "arrow.clockwise")
                                }
                            }

                            Divider()

                            // SEKTION 2: Chart Range
                            Section(header: Text("Chart Range")) {
                                ForEach([3, 6, 9, 12, 24], id: \.self) { value in
                                    Button(action: { state.hours = value }) {
                                        HStack {
                                            Text("\(value) Stunden")
                                            if state.hours == value {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }

                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: colorScheme == .dark ? [
                                                    ZenPalette.salbei.opacity(0.35),
                                                    ZenPalette.daemmer.opacity(0.55)
                                                ] : [
                                                    ZenPalette.salbei.opacity(0.18),
                                                    ZenPalette.daemmer.opacity(0.22)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            Circle().stroke(
                                                colorScheme == .dark
                                                    ? ZenPalette.strokeDark
                                                    : ZenPalette.strokeLight,
                                                lineWidth: 0.5
                                            )
                                        )
                                )
                        }
                        .menuStyle(DefaultMenuStyle())
                        .frame(maxWidth: .infinity)

                        // 5. Profile Button
                        ZStack {
                            Image(systemName: isOverride ? "person.fill" : "person")
                                .font(.system(size: 22))
                                .foregroundStyle(.purple.opacity(0.7))
                                .padding(8)
                                .background(isOverride ? .purple.opacity(0.15) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            if isOverride { showCancelAlert.toggle() }
                            else { state.showModal(for: .overrideProfilesConfig) }
                        }
                        .onLongPressGesture {
                            state.showModal(for: .overrideProfilesConfig)
                        }

                        // 6. TempTarget Button
                        Image(systemName: "target")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(isTarget ? .green : .green.opacity(0.7))
                            .padding(8)
                            .background(isTarget ? .green.opacity(0.15) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                if isTarget {
                                    showCancelTTAlert.toggle()
                                } else {
                                    state.showModal(for: .addTempTarget)
                                }
                            }
                            .onLongPressGesture {
                                state.showModal(for: .addTempTarget)
                            }
                        // Settings Button
                        Button { state.showModal(for: .settings) }
                        label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.gray.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 0)
                    .padding(.vertical, 8)
                    .elegantShadow(scheme: colorScheme)
                    .padding(.horizontal, 10)
                    .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : 20)
                }
            }
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

        func bolusProgressView(progress _: Decimal, amount _: Decimal) -> some View {
            Button(action: {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                state.cancelBolus()
            }) {
                HStack(spacing: 8) {
                    // Pulsierendes Stopp-Icon
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .symbolEffect(.pulse, options: .repeating) // Nur verfügbar ab iOS 17, sonst ignorieren

                    Text("BOLUS STOPPEN")
                        .font(.system(size: 11, weight: .black))
                }
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(Color.red)
                        .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }

        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
            VStack(spacing: 2) {
                TopStatusPill(state: state)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, geo.safeAreaInsets.top + 5)
                    .padding(.bottom, 10)

                if let progress = state.bolusProgress, progress > 0,
                   let amount = state.bolusAmount
                {
                    bolusProgressView(progress: progress, amount: amount)
                }

                glucoseView
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    .padding(.bottom, 25)
            }
            .background(Color.clear)
        }

        private var isfView: some View {
            HStack(spacing: 4) {
                Image(systemName: "divide")
                    .font(.system(size: 16))
                    .foregroundStyle(.teal)

                Text(String(describing: state.data.suggestion?.sensitivityRatio ?? 1))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.timeSettingFont)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                Group {
                    if colorScheme != .dark {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.00))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
            )
            .onTapGesture {
                if (state.autoisf && !disabled()) || enabled() {
                    displayAutoHistory.toggle()
                } else {
                    displayDynamicHistory.toggle()
                }
            }
            .offset(x: 130)
        }

        private func enabled() -> Bool {
            guard let or = fetchedPercent.first, or.enabled else { return false }
            guard let aisf = fetchedAISF.first else { return false }
            return aisf.autoisf
        }

        private func disabled() -> Bool {
            guard let or = fetchedPercent.first, or.enabled else { return false }
            guard let aisf = fetchedAISF.first else { return false }
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
                    VStack(spacing: 0) {
                        // Header View
                        headerView(geo)
                        ScrollView {
                            VStack {
                                // Main Chart
                                chart
                                StatusCards(state: state)
                                    .padding(.top, 5)
                                    .padding(.bottom, 35)
                                if !state.isfView {
                                    isfView
                                        .padding(.top, -25)
                                        .padding(.bottom, -15)
                                } else {}

                                // COB Chart
                                if state.carbData > 0 {
                                    activeCOBView.padding(.bottom, 15).padding(.top, 45)
                                }

                                // IOB Chart
                                if !state.iobData.isEmpty {
                                    activeIOBView.padding(.bottom, 15)
                                }
                            }
                            .background {
                                // Track vertical scroll
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
                        }.coordinateSpace(name: "HomeScrollView")
                        // Buttons
                        buttonPanel(geo)
                    }
                    .background(
                        colorScheme == .light ? IAPSconfig.homeViewBackgroundLight : IAPSconfig.homeViewBackgrundDark
                    )
                    .sheet(isPresented: $displayAutoHistory) {
                        AutoISFHistoryView(units: state.data.units)
                            .environment(\.colorScheme, colorScheme)
                    }
                    .sheet(isPresented: $displayDynamicHistory) {
                        DynamicHistoryView(units: state.data.units)
                            .environment(\.colorScheme, colorScheme)
                    }
                    .overlay(
                        Group {
                            if state.isStatusPopupPresented {
                                Color.black.opacity(0.2) // Dimmt den Hintergrund leicht ab
                                    .ignoresSafeArea()
                                    .onTapGesture { state.isStatusPopupPresented = false } }
                        }
                    )
                    .ignoresSafeArea(edges: .vertical)
                    .onChange(of: scenePhase) { switch scenePhase {
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
            }
            .onAppear {
                if onboarded.first?.firstRun ?? true {
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
            .popup(isPresented: state.isStatusPopupPresented, alignment: .bottom, direction: .bottom) {
                popup
                    .padding(.bottom, 80)
                    .onTapGesture {
                        state.isStatusPopupPresented = false
                    }
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

        private var popup: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(state.statusTitle)
                        .font(.suggestionHeadline)
                        .foregroundColor(.primary)
                    Spacer()
                }

                // Tag-Cloud Sektion
                if let suggestion = state.data.suggestion {
                    TagCloudView(tags: suggestion.reasonParts)
                        .animation(.none, value: false)

                    Text(suggestion.reasonConclusion.capitalizingFirstLetter())
                        .font(.suggestionSmallParts)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No suggestion found")
                        .font(.suggestionHeadline)
                        .foregroundColor(.secondary)
                }

                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(NSLocalizedString("Status at", comment: "")) \(dateFormatter.string(from: date))")
                            .foregroundColor(.secondary)
                            .font(.caption2)

                        Text(errorMessage)
                            .font(.suggestionError)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                } else if let suggestion = state.data.suggestion, (suggestion.bg ?? 100) == 400 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invalid CGM reading (HIGH).")
                            .font(.suggestionError)
                            .bold()
                            .foregroundColor(.red)
                        Text("SMBs and High Temps Disabled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
