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
            CurrentGlucoseView(
                recentGlucose: $state.recentGlucose,
                delta: $state.glucoseDelta,
                units: $state.data.units,
                alarm: $state.alarm,
                lowGlucose: $state.data.lowGlucose,
                highGlucose: $state.data.highGlucose,
                alwaysUseColors: $state.alwaysUseColors,
                displayDelta: $state.displayDelta,
                scrolling: $displayGlucose, displaySAGE: $state.displaySAGE,
                displayExpiration: $state.displayExpiration,
                sensordays: $state.sensorDays,
                timerDate: $state.data.timerDate
            )
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

            let chartRatio: CGFloat = 3.6
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

            ButtonPanelView(
                geo: geo,
                state: state,
                showCancelAlert: $showCancelAlert,
                tempBasalString: tempBasalString,
                isOverride: isOverride,
                profileButton: state.profileButton,
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
            let tempBasalString: String
            @Environment(\.colorScheme) var colorScheme
            let isOverride: Bool
            let profileButton: Bool
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
                            /* .contextMenu {
                                 Button {
                                     state.showModal(for: .addCarbs(
                                         editMode: false,
                                         override: false,
                                         mode: .presets
                                     ))
                                 } label: {
                                     Label("Meal Presets", systemImage: "menucard")
                                 }

                                 /* Button {
                                      state.showModal(for: .addCarbs(
                                          editMode: false,
                                          override: false,
                                          mode: .search
                                      ))
                                  } label: {
                                      Label("Search", systemImage: "network")
                                  }*/

                                 Button {
                                     state.showModal(for: .addCarbs(
                                         editMode: false,
                                         override: false,
                                         mode: .barcode
                                     ))
                                 } label: {
                                     Label("Barcode", systemImage: "barcode.viewfinder")
                                 }

                                 Button {
                                     state.showModal(for: .addCarbs(
                                         editMode: false,
                                         override: false,
                                         mode: .image
                                     ))
                                 } label: {
                                     Label("AI Image Analysis", systemImage: "photo.badge.magnifyingglass")
                                 }

                                 Button {
                                     state.showModal(for: .addCarbs(
                                         editMode: false,
                                         override: false,
                                         mode: .meal
                                     ))
                                 } label: {
                                     Label("Add Meal", systemImage: "birthday.cake")
                                 }
                             } */
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

                                // Hier kannst du auch den detaillierten Status öffnen
                                /*         Button(action: {
                                     isDetailSheetPresented = true
                                 }) {
                                     Label("System-Details", systemImage: "info.circle")
                                 }*/
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

                            // SEKTION 3: Status Infos
                            /*   Section(header: Text("Status")) {
                                 if let sensor = state.calculateSensorInfo() {
                                     Button(action: { state.showModal(for: .cgm) }) {
                                         Label("\(sensor.text)", systemImage: "sensor.tag.radiowaves.forward")
                                     }
                                 }
                                 if state.tempRate != nil {
                                     Button(action: { state.showModal(for: .manualTempBasal) }) {
                                         Label(
                                             "Basal: \(tempBasalString)",
                                             systemImage: "chart.bar.xaxis.ascending.badge.clock"
                                         )
                                     }
                                 }
                             }*/
                        } label: {
                            // Das visuelle Design des Buttons bleibt exakt gleich
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                                .frame(width: 55, height: 55)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: colorScheme == .dark ? [
                                                    Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.6),
                                                    Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.8),
                                                    Color(red: 0.0, green: 0.2, blue: 0.7).opacity(1.0)
                                                ] : [
                                                    Color(red: 0.7, green: 0.9, blue: 0.5).opacity(0.10),
                                                    Color(red: 0.3, green: 0.8, blue: 0.6).opacity(0.15),
                                                    Color(red: 0.1, green: 0.6, blue: 0.9).opacity(0.20)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                        .menuStyle(DefaultMenuStyle())
                        .frame(maxWidth: .infinity)

                        // Profile Button
                        if profileButton {
                            ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                                Image(systemName: isOverride ? "person.fill" : "person")
                                    .symbolRenderingMode(.palette)
                                    .font(.custom("Buttons", size: 22))
                                    .foregroundStyle(.purple.opacity(0.7))
                                    .padding(8)
                                    .background(isOverride ? .purple.opacity(0.15) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                if isOverride {
                                    showCancelAlert.toggle()
                                } else {
                                    state.showModal(for: .overrideProfilesConfig)
                                }
                            }
                            .onLongPressGesture {
                                state.showModal(for: .overrideProfilesConfig)
                            }
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .elegantShadow(scheme: colorScheme)
                    .padding(.horizontal, 10)
                    .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : 20)
                }
            }
        }

        // MARK: - Statistik & Info Panels

        var preview: some View {
            VStack {
                PreviewChart(
                    readings: $state.readings,
                    lowLimit: $state.data.lowGlucose,
                    highLimit: $state.data.highGlucose
                )
                .padding(15)
            }
            .frame(minHeight: 200)
            .elegantShadow(scheme: colorScheme)
            .padding(.horizontal, 10)
            .blur(radius: animateTIRView ? 2 : 0)
            .onTapGesture {
                timeIsNowTIR()
                state.showModal(for: .statistics)
            }
            .overlay {
                if animateTIRView { animation.asAny() }
            }
        }

        var infoPanelView: some View {
            VStack {
                info.padding(.horizontal, 15)
            }
            .frame(height: 40)
            .elegantShadow(scheme: colorScheme)
            .padding(.horizontal, 10)
        }

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

        var insulinView: some View {
            VStack {
                InsulinSummaryView(
                    neg: $state.neg,
                    tddChange: $state.tddChange,
                    tddAverage: $state.tddAverage,
                    tddYesterday: $state.tddYesterday,
                    tdd2DaysAgo: $state.tdd2DaysAgo,
                    tdd3DaysAgo: $state.tdd3DaysAgo,
                    tddActualAverage: $state.tddActualAverage
                )
                .padding(15)
            }
            .frame(minHeight: 280)
            .elegantShadow(scheme: colorScheme)
            .padding(.horizontal, 10)
        }

        var mealsView: some View {
            VStack {
                MealsSummaryView(data: $state.mealData)
                    .padding(15)
            }
            .frame(minHeight: 190)
            .elegantShadow(scheme: colorScheme)
            .padding(.horizontal, 10)
        }

        var loopPreview: some View {
            VStack {
                LoopsView(loopStatistics: $state.loopStatistics)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 15)
            }
            .frame(minHeight: 160)
            .blur(radius: animateLoopView ? 2.5 : 0)
            .elegantShadow(scheme: colorScheme) // Erst den Hintergrund mit Schatten...
            .padding(.horizontal, 10)
            .onTapGesture {
                timeIsNowLoop()
                state.showModal(for: .statistics)
            }
            .overlay {
                if animateLoopView {
                    animation.asAny()
                }
            }
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

        // TopStatusPill unter dem Glucose Rad

        /*  @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
             VStack(spacing: 0) { // Spacing auf 0, um volle Kontrolle über Paddings zu haben
                 // 1. Die Glukose-Anzeige (jetzt ganz oben)
                 glucoseView
                     .padding(.top, geo.safeAreaInsets.top + 10) // Schiebt das Rad unter die Dynamic Island
                     .padding(.bottom, 10)
                     .padding(.horizontal, 20)

                 // 2. topStatusPill (jetzt unter der Glukose)
                 TopStatusPill(state: state)
                     .frame(maxWidth: .infinity, alignment: .center)
                     .padding(.top, 15)
                     .padding(.bottom, 20) // Abstand nach unten zur Status-Leiste/Chart

                 // 3. Falls ein Bolus läuft
                 if let progress = state.bolusProgress, progress > 0,
                    let amount = state.bolusAmount
                 {
                     bolusProgressView(progress: progress, amount: amount)
                         .padding(.bottom, 10)
                 }
             }
             .background(Color.clear)
         }*/

        var glucosePreview: some View {
            let data = state.data.glucose
            let minimum = data.compactMap(\.glucose).min() ?? 0
            let minimumRange = Double(minimum) * 0.8
            let maximum = Double(data.compactMap(\.glucose).max() ?? 0) * 1.1

            let high = state.data.highGlucose
            let low = state.data.lowGlucose
            let veryHigh = 198

            return Chart(data) {
                PointMark(
                    x: .value("Time", $0.dateString),
                    y: .value("Glucose", Double($0.glucose ?? 0) * (state.data.units == .mmolL ? 0.0555 : 1.0))
                )
                .foregroundStyle(
                    (($0.glucose ?? 0) > veryHigh || Decimal($0.glucose ?? 0) < low) ? Color(.red) : Decimal($0.glucose ?? 0) >
                        high ? Color(.yellow) : Color(.darkGreen)
                )
                .symbolSize(5)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .chartYScale(
                domain: minimumRange * (state.data.units == .mmolL ? 0.0555 : 1.0) ... maximum *
                    (state.data.units == .mmolL ? 0.0555 : 1.0)
            )
            .chartXScale(
                domain: Date.now.addingTimeInterval(-1.days.timeInterval) ... Date.now
            )
            .frame(height: 50)
            .padding(.leading, 30)
            .padding(.trailing, 32)
            .padding(.top, 15)
            .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.large)
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
                                // timeSetting
                                // .overlay { isfView }
                                if !state.isfView {
                                    isfView
                                        .padding(.top, -25)
                                        .padding(.bottom, -15)
                                } else {}

                                // TIR Chart
                                if !state.data.glucose.isEmpty {
                                    preview.padding(.top, 15)
                                }
                                // Loops Chart
                                loopPreview.padding(.vertical, 15)

                                // COB Chart
                                if state.carbData > 0 {
                                    activeCOBView.padding(.bottom, 15)
                                }

                                // IOB Chart
                                if !state.iobData.isEmpty {
                                    activeIOBView.padding(.bottom, 15)
                                }

                                // Summary Views
                                insulinView.padding(.bottom, 15)
                                mealsView.padding(.bottom, 15)
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
