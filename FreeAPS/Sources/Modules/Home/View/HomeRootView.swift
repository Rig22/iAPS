import Charts
import CoreData
import SpriteKit
import SwiftDate
import SwiftUI
import Swinject

extension Home {
    struct RootView: BaseView {
        let resolver: Resolver

        @StateObject var state = StateModel()
        @State var isStatusPopupPresented = false
        @State var showCancelAlert = false
        @State var showCancelTTAlert = false
        @State var triggerUpdate = false
        @State var scrollOffset = CGFloat.zero
        @State var display = false

        @Namespace var scrollSpace

        let scrollAmount: CGFloat = 290
        let buttonFont = Font.custom("TimeButtonFont", size: 14)

        @Environment(\.managedObjectContext) var moc
        @Environment(\.colorScheme) var colorScheme
        @Environment(\.sizeCategory) private var fontSize

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
            entity: TempTargets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var sliderTTpresets: FetchedResults<TempTargets>

        @FetchRequest(
            entity: TempTargetsSlider.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var enactedSliderTT: FetchedResults<TempTargetsSlider>

        @State private var progress: Double = 0.0 // Fortschrittswert als State-Variable

        private var numberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var insulinnumberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0 // Keine unnötigen Nullen
            formatter.locale = Locale(identifier: "de_DE_POSIX") // Standard-Format ohne Leerzeichen
            return formatter
        }

        private var bolusProgressFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimum = 0
            formatter.maximumFractionDigits = state.settingsManager.preferences.bolusIncrement > 0.05 ? 1 : 2
            formatter.minimumFractionDigits = state.settingsManager.preferences.bolusIncrement > 0.05 ? 1 : 2
            formatter.allowsFloats = true
            formatter.roundingIncrement = Double(state.settingsManager.preferences.bolusIncrement) as NSNumber
            return formatter
        }

        private var fetchedTargetFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
            } else { formatter.maximumFractionDigits = 0 }
            return formatter
        }

        private var targetFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var tirFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        private var dateFormatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            return dateFormatter
        }

        private var spriteScene: SKScene {
            let scene = SnowScene()
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            return scene
        }

        var glucoseView: some View {
            CurrentGlucoseView(
                recentGlucose: $state.recentGlucose,
                timerDate: $state.timerDate,
                delta: $state.glucoseDelta,
                units: $state.units,
                alarm: $state.alarm,
                lowGlucose: $state.lowGlucose,
                highGlucose: $state.highGlucose
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

        /*        struct FillableCircle: View {
             var fillFraction: CGFloat // Wert zwischen 0 und 1 für die Füllmenge
             var color: Color // Farbe der Füllung
             var opacity: CGFloat // Transparenz des Hintergrundkreises

             var body: some View {
                 ZStack {
                     Circle()
                         .stroke(lineWidth: 3)
                         .opacity(Double(opacity))
                         .foregroundColor(color.opacity(0.5)) // Hintergrund des Kreises

                     Circle()
                         .trim(from: 0.0, to: fillFraction) // Teil des Kreises, der gefüllt wird
                         .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                         .rotationEffect(.degrees(-90)) // Start bei 12 Uhr
                         .animation(.easeInOut, value: fillFraction) // Animation der Füllung
                 }
                 .frame(width: 54, height: 54) // Größe des Kreises
             }
         }*/

        var pumpView: some View {
            PumpView(
                reservoir: $state.reservoir,
                battery: $state.battery,
                name: $state.pumpName,
                expiresAtDate: $state.pumpExpiresAtDate,
                timerDate: $state.timerDate, timeZone: $state.timeZone,
                state: state
            )
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
        }

        // Fortschrittsanzeige
        private func startProgress() {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                withAnimation {
                    progress += 0.01 // Fortschritt in kleinen Schritten erhöhen
                }
                if progress >= 1.0 {
                    timer.invalidate()
                }
            }
        }

        struct PieSliceView: Shape {
            var startAngle: Angle
            var endAngle: Angle

            func path(in rect: CGRect) -> Path {
                var path = Path()
                let center = CGPoint(x: rect.midX, y: rect.midY)
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: rect.width / 2,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
                return path
            }
        }

        struct FillablePieSegment: View {
            @State private var progress: CGFloat = 0.0
            var fillFraction: CGFloat
            var color: Color
            var backgroundColor: Color
            var displayText: String
            var symbolSize: CGFloat
            var symbol: String
            var animateProgress: Bool

            var body: some View {
                VStack {
                    ZStack {
                        Circle()
                            .fill(backgroundColor)
                            .opacity(0.3)
                            .frame(width: 50, height: 50)

                        PieSliceView(startAngle: .degrees(-92), endAngle: .degrees(-92 + Double(progress * 360)))
                            .fill(color)
                            .frame(width: 50, height: 50)
                            .opacity(0.6)

                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: symbolSize, height: symbolSize)
                            .foregroundColor(.white)
                    }

                    Text(displayText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.top, 0)
                }
                .offset(y: 10)
                .onAppear {
                    updateProgress()
                }
                .onChange(of: fillFraction) { _ in
                    updateProgress()
                }
            }

            private func updateProgress() {
                if fillFraction < 0.001 {
                    // Bei sehr kleinem fillFraction sofort den Fortschritt auf 0 setzen
                    progress = 0.0
                } else if animateProgress {
                    startProgress()
                } else {
                    progress = fillFraction
                }
            }

            private func startProgress() {
                progress = 0.0
                let animationDuration = 0.5
                let steps = Int(animationDuration / 0.025)
                let stepAmount = fillFraction / CGFloat(steps)

                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    withAnimation {
                        progress += stepAmount
                    }
                    if progress >= fillFraction || fillFraction < 0.001 {
                        timer.invalidate()
                        progress = fillFraction

                        // Fallback: Wenn fillFraction sehr klein ist, setze progress auf 0
                        if fillFraction < 0.001 {
                            progress = 0
                        }
                    }
                }
            }
        }

        var carbsAndInsulinView: some View {
            HStack {
                if let settings = state.settingsManager {
                    HStack(spacing: 18) {
                        VStack {
                            let substance = Double(state.suggestion?.cob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxCOB), 1)
                            let fraction = CGFloat(substance / maxValue)
                            let fill = max(min(fraction, 1.0), 0.0)
                            let carbSymbol = "fork.knife"

                            FillablePieSegment(
                                fillFraction: fill,
                                color: .loopYellow,
                                backgroundColor: .gray,
                                displayText: "\(numberFormatter.string(from: (state.suggestion?.cob ?? 0) as NSNumber) ?? "0")g",
                                symbolSize: 26,
                                symbol: carbSymbol,
                                animateProgress: true
                            )

                            HStack(spacing: 0) {
                                Text(numberFormatter.string(from: (state.suggestion?.cob ?? 0) as NSNumber) ?? "0")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                Text(NSLocalizedString("g", comment: "gram of carbs"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(.leading, -1)
                            }
                            .offset(y: 20)
                        }

                        VStack {
                            let substance = Double(state.suggestion?.iob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxIOB), 1)
                            let fraction = CGFloat(substance / maxValue)
                            let fill = max(min(fraction, 1.0), 0.0)
                            let insulinSymbol = "syringe"

                            FillablePieSegment(
                                fillFraction: fill,
                                color: substance < 0 ? .blue : .insulin,
                                backgroundColor: .gray,
                                displayText: "\(insulinnumberFormatter.string(from: (state.suggestion?.iob ?? 0) as NSNumber) ?? "0")U",
                                symbolSize: 26,
                                symbol: insulinSymbol,
                                animateProgress: true
                            )

                            HStack(spacing: 0) {
                                Text(insulinnumberFormatter.string(from: (state.suggestion?.iob ?? 0) as NSNumber) ?? "0")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                Text(NSLocalizedString("U", comment: "Insulin unit"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(.leading, -1)
                            }
                            .offset(y: 20)
                        }
                    }
                    .padding(.horizontal, 5)
                }
            }
        }

        var loopView: some View {
            LoopView(
                suggestion: $state.suggestion,
                enactedSuggestion: $state.enactedSuggestion,
                closedLoop: $state.closedLoop,
                timerDate: $state.timerDate,
                isLooping: $state.isLooping,
                lastLoopDate: $state.lastLoopDate,
                manualTempBasal: $state.manualTempBasal
            )
            .onTapGesture {
                state.isStatusPopupPresented.toggle()
            }.onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                state.runLoop()
            }
        }

        var tempBasalString: String? {
            guard let tempRate = state.tempRate else {
                return nil
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
                                .font(.extraSmall).bold().foregroundStyle(Color.white)
                        } else if let tempBasalString = tempBasalString {
                            Text(tempBasalString)
                                .font(.statusFont).bold()
                                .foregroundStyle(Color.white)
                        }
                        if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                            Text("Check Max IOB Setting").font(.extraSmall).foregroundColor(.orange)
                        }
                    }
                }
                .padding(.leading, 0)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let tempTargetString = tempTargetString, !(fetchedPercent.first?.enabled ?? false) {
                    Text(tempTargetString)
                        .font(.buttonFont)
                        .foregroundStyle(Color.white)
                } else {
                    profileView
                }

                ZStack {
                    if let eventualBG = state.eventualBG {
                        HStack {
                            Text("⇢").font(.statusFont).foregroundStyle(.white)

                            // Image(systemName: "arrow.forward")
                            Text(
                                fetchedTargetFormatter.string(
                                    from: (state.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                                )!
                            ).font(.statusFont).foregroundColor(colorScheme == .dark ? .white : .white)
                            Text(state.units.rawValue).font(.system(size: 12)).foregroundStyle(.white)
                                .foregroundStyle(Color.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                    }
                }
            }.dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }

        var infoPanel: some View {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.black, .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                info
                    .frame(minWidth: 100, idealWidth: 200, maxWidth: 430, minHeight: 15, maxHeight: 45)
                    .padding(20)
            }
            .frame(width: 430, height: 45) // Optional: Festlegen einer festen Größe für den gesamten ZStack
        }

        var mainChart: some View {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.black, .black, .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                if state.animatedBackground {
                    SpriteView(scene: spriteScene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                MainChartView(
                    glucose: $state.glucose,
                    isManual: $state.isManual,
                    suggestion: $state.suggestion,
                    tempBasals: $state.tempBasals,
                    boluses: $state.boluses,
                    suspensions: $state.suspensions,
                    announcement: $state.announcement,
                    hours: .constant(state.filteredHours),
                    maxBasal: $state.maxBasal,
                    autotunedBasalProfile: $state.autotunedBasalProfile,
                    basalProfile: $state.basalProfile,
                    tempTargets: $state.tempTargets,
                    carbs: $state.carbs,
                    timerDate: $state.timerDate,
                    units: $state.units,
                    smooth: $state.smooth,
                    highGlucose: $state.highGlucose,
                    lowGlucose: $state.lowGlucose,
                    screenHours: $state.hours,
                    displayXgridLines: $state.displayXgridLines,
                    displayYgridLines: $state.displayYgridLines,
                    thresholdLines: $state.thresholdLines,
                    triggerUpdate: $triggerUpdate,
                    overrideHistory: $state.overrideHistory,
                    minimumSMB: $state.minimumSMB,
                    maxBolus: $state.maxBolus,
                    maxBolusValue: $state.maxBolusValue, useInsulinBars: $state.useInsulinBars
                )
            }
            .padding(.bottom, 50)
            .modal(for: .dataTable, from: self)
        }

        @ViewBuilder private func buttonPanel(_ geo: GeometryProxy) -> some View {
            ZStack {
                addBackground()
                LinearGradient(
                    gradient: Gradient(colors: [.black, .blueComplicationBackground]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60 + geo.safeAreaInsets.bottom)
                let isOverride = fetchedPercent.first?.enabled ?? false
                let isTarget = (state.tempTarget != nil)
                HStack {
                    Button { state.showModal(for: .addCarbs(editMode: false, override: false)) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image(systemName: "fork.knife")
                                .renderingMode(.template)
                                .font(.custom("Buttons", size: 24))
                                .foregroundColor(colorScheme == .dark ? .loopYellow : .orange)
                                .padding(8)
                                .foregroundStyle(Color.white)
                            if let carbsReq = state.carbsRequired {
                                Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                    .font(.caption)
                                    .foregroundStyle(Color.white)
                                    .padding(4)
                                    .background(Capsule().fill(Color.red))
                            }
                        }
                    }.buttonStyle(.borderless)
                    Spacer()
                    Button {
                        state.showModal(for: .bolus(
                            waitForSuggestion: state.useCalc ? true : false,
                            fetch: false
                        ))
                    }
                    label: {
                        Image(systemName: "syringe")
                            .renderingMode(.template)
                            .font(.custom("Buttons", size: 24))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.blue)
                    Spacer()
                    if state.allowManualTemp {
                        Button { state.showModal(for: .manualTempBasal) }
                        label: {
                            Image("bolus1")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: IAPSconfig.buttonSize, height: IAPSconfig.buttonSize, alignment: .bottom)
                        }
                        .foregroundStyle(Color.white)
                        Spacer()
                    }
                    ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                        Image(systemName: isOverride ? "person.fill" : "person")
                            .symbolRenderingMode(.palette)
                            .font(.custom("Buttons", size: 24))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(isOverride ? .blue.opacity(0.5) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
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
                    if state.useTargetButton {
                        Spacer()
                        Image(systemName: "scope")
                            .renderingMode(.template)
                            .font(.custom("Buttons", size: 24))
                            .padding(8)
                            .foregroundStyle(Color.white)
                            .background(isTarget ? .green.opacity(0.15) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    }
                    Spacer()
                    Button { state.showModal(for: .settings) }
                    label: {
                        Image(systemName: "gear")
                            .renderingMode(.template)
                            .font(.custom("Buttons", size: 24))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.white)
                }
                .padding(.horizontal, state.allowManualTemp ? 5 : 24)
                .padding(.bottom, geo.safeAreaInsets.bottom)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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
        }

        /*       var chart: some View {
             //           let ratio = state.timeSettings ? 1.61 : 1.44
             //           let ratio2 = state.timeSettings ? 1.65 : 1.51

             let ratio = state.timeSettings ? 1.8 : 1.6
             let ratio2 = state.timeSettings ? 1.9 : 1.7

             return addBackground()
                 .overlay {
                     VStack(spacing: 0) {
                         infoPanel
                         mainChart
                     }
                 }
                 .frame(minHeight: UIScreen.main.bounds.height / (fontSize < .extraExtraLarge ? ratio : ratio2))
         }*/
        var chart: some View {
            // Leicht erhöhte Ratios für eine moderate Verkleinerung
            let ratio = state.timeSettings ? 1.85 : 1.65
            let ratio2 = state.timeSettings ? 1.95 : 1.75

            return addBackground()
                .overlay {
                    VStack(spacing: 0) {
                        infoPanel
                        mainChart
                    }
                }
                .frame(minHeight: UIScreen.main.bounds.height / (fontSize < .extraExtraLarge ? ratio : ratio2))
        }

        var preview: some View {
            addBackground()
                .frame(minHeight: 200)
                .overlay {
                    PreviewChart(readings: $state.readings, lowLimit: $state.lowGlucose, highLimit: $state.highGlucose)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 10)
                .foregroundStyle(Color.white)
                .onTapGesture {
                    state.showModal(for: .statistics)
                }
        }

        var activeIOBView: some View {
            addBackground()
                .frame(minHeight: 430)
                .overlay {
                    ActiveIOBView(
                        data: $state.iobData,
                        neg: $state.neg,
                        tddChange: $state.tddChange,
                        tddAverage: $state.tddAverage,
                        tddYesterday: $state.tddYesterday,
                        tdd2DaysAgo: $state.tdd2DaysAgo,
                        tdd3DaysAgo: $state.tdd3DaysAgo,
                        tddActualAverage: $state.tddActualAverage
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 10)
                .foregroundStyle(Color.white)
        }

        var activeCOBView: some View {
            addBackground()
                .frame(minHeight: 230)
                .overlay {
                    ActiveCOBView(data: $state.iobData)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
        }

        var loopPreview: some View {
            addBackground()
                .frame(minHeight: 190)
                .overlay {
                    LoopsView(loopStatistics: $state.loopStatistics)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 10)
                .foregroundStyle(Color.white)
                .onTapGesture {
                    state.showModal(for: .statistics)
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
                                        Text(shortened).font(.statusFont).foregroundStyle(.white)
                                    } else {
                                        Text(name).font(.statusFont).foregroundStyle(.white)
                                    }
                                }
                            }
                        } else if override.percentage != 100 {
                            Text(override.percentage.formatted() + " %").font(.statusFont).foregroundStyle(.white)
                        } else if override.smbIsOff, !override.smbIsAlwaysOff {
                            Text("No ").font(.statusFont).foregroundStyle(.white) // "No" as in no SMBs
                            Image(systemName: "syringe")
                                .font(.previewNormal).foregroundStyle(.white)
                        } else if override.smbIsOff {
                            Image(systemName: "clock").font(.statusFont).foregroundStyle(.white)
                            Image(systemName: "syringe")
                                .font(.previewNormal).foregroundStyle(.white)
                        } else {
                            Text("Override").font(.statusFont).foregroundStyle(.white)
                        }
                    }
                }
            }
        }

        public struct CircularProgressViewStyle: ProgressViewStyle {
            public func makeBody(configuration: Configuration) -> some View {
                let progress = CGFloat(configuration.fractionCompleted ?? 0)

                ZStack {
                    Circle()
                        .stroke(lineWidth: 8)
                        .opacity(0.3)
                        .foregroundColor(Color.gray)

                    Circle()
                        .trim(from: 0.0, to: progress)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blueComplicationBackground]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: 270))
                        .animation(.linear(duration: 0.25), value: progress)

                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .foregroundColor(.white)
                        .offset(x: 3)
                }
                .frame(width: 100, height: 100)
            }
        }

        // Progressbar in rounded style
        func bolusProgressView(progress: Decimal, amount: Decimal) -> some View {
            ZStack {
                VStack {
//                    Text("Bolusing")
//                        .foregroundColor(.white)
//                        .font(.subheadline)
//                        .fontWeight(.bold)
//                        .padding(.bottom, 10)

                    let bolused = bolusProgressFormatter.string(from: (amount * progress) as NSNumber) ?? ""

                    Text(
                        bolused + " " + NSLocalizedString("of", comment: "") + " " + amount
                            .formatted(.number.precision(.fractionLength(2))) +
                            NSLocalizedString(" U", comment: " ")
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.white)

                    ProgressView(value: Double(truncating: progress as NSNumber))
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, 10)
                }

                Image(systemName: "xmark.circle")
                    .font(.system(size: 20))
                    .onTapGesture { state.cancelBolus() }
                    .offset(x: 80, y: -80)
            }
        }

        // Normal progressbar
        /* func bolusProgressView(progress: Decimal, amount: Decimal) -> some View {
             ZStack {
                 HStack {
                     VStack {
                         HStack {
                             Text("Bolusing")
                                 .foregroundColor(.white)
                                 .font(.subheadline)
                                 .fontWeight(.bold)

                             let bolused = bolusProgressFormatter.string(from: (amount * progress) as NSNumber) ?? ""

                             Text(
                                 bolused + " " + NSLocalizedString("of", comment: "") + " " + amount
                                     .formatted(.number.precision(.fractionLength(2))) +
                                     NSLocalizedString(" U", comment: " ")
                             )
                             .font(.subheadline)
                             .foregroundStyle(Color.white)
                         }
                         .frame(width: 300, height: 30)
                         VStack {
                             ProgressView(value: Double(truncating: progress as NSNumber))
                                 .progressViewStyle(BolusProgressViewStyle())
                                 .offset(x: 16, y: -3)
                         }
                     }
                     Image(systemName: "xmark.circle")
                         .font(.system(size: 20))
                         .onTapGesture { state.cancelBolus() }
                         .offset(x: -20, y: -8)
                 }
             }
         }*/

        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
            addHeaderBackground()
                .frame(
                    maxHeight: fontSize < .extraExtraLarge ? 240 + geo.safeAreaInsets.top : 135 + geo
                        .safeAreaInsets.top
                )
                .overlay {
                    VStack {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [.blueComplicationBackground, .black]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            glucoseView.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 75)
                            HStack {
                                carbsAndInsulinView
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                Spacer()
                                loopView.frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 5)
                                    .offset(x: -4)
                                Spacer()
                                pumpView
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom, 30)
                            }
                            .dynamicTypeSize(...DynamicTypeSize.xLarge)
                            .padding(.horizontal, 10)
                        }
                    }
                    //                   .padding(.top, geo.safeAreaInsets.top).padding(.bottom, 0)
                    .padding(.top, 0).padding(.bottom, 0)
                }
                .clipShape(Rectangle())
        }

        @ViewBuilder private func glucoseHeaderView() -> some View {
            addBackground()
                .frame(maxHeight: 90)
                .overlay {
                    VStack {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [.black, .black]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            glucosePreview.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .dynamicTypeSize(...DynamicTypeSize.medium)
                        }
                    }
                }
                .clipShape(Rectangle())
                .foregroundStyle(Color.white)
        }

        var glucosePreview: some View {
            let data = state.glucose
            let minimum = data.compactMap(\.glucose).min() ?? 0
            let minimumRange = Double(minimum) * 0.8
            let maximum = Double(data.compactMap(\.glucose).max() ?? 0) * 1.1

            let high = state.highGlucose
            let low = state.lowGlucose
            let veryHigh = 198

            return Chart(data) {
                PointMark(
                    x: .value("Time", $0.dateString),
                    y: .value("Glucose", Double($0.glucose ?? 0) * (state.units == .mmolL ? 0.0555 : 1.0))
                )
                .foregroundStyle(
                    (($0.glucose ?? 0) > veryHigh || Decimal($0.glucose ?? 0) < low) ? Color(.red) :
                        Decimal($0.glucose ?? 0) >
                        high ? Color(.yellow) : Color(.darkGreen)
                )
                .symbolSize(7)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                    AxisValueLabel(
                        format: .dateTime.hour(.defaultDigits(amPM: .omitted))
                            .locale(Locale(identifier: "sv"))
                    )
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .chartYScale(
                domain: minimumRange * (state.units == .mmolL ? 0.0555 : 1.0) ... maximum *
                    (state.units == .mmolL ? 0.0555 : 1.0)
            )
            .chartXScale(
                domain: Date.now.addingTimeInterval(-1.days.timeInterval) ... Date.now
            )
            .frame(maxHeight: 70)
            .padding(.leading, 30)
            .padding(.trailing, 32)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .foregroundStyle(Color.white)
        }

        var timeSetting: some View {
            let string = "\(state.hours) " + NSLocalizedString("hours", comment: "") + "   "
            return Menu(string) {
                Button("3 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 3 })
                Button("6 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 6 })
                Button("12 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 12 })
                Button("24 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 24 })
                Button("UI/UX Settings", action: { state.showModal(for: .statisticsConfig) })
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white)
            .font(.timeSettingFont)
//            .padding(.vertical, -25)
            .background(TimeEllipse(characters: string.count))
            .offset(y: -25)
        }

        var body: some View {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    headerView(geo)

                    if !state.skipGlucoseChart, scrollOffset > scrollAmount {
                        glucoseHeaderView()
                            .transition(.move(edge: .top))
                    }

                    ScrollView {
                        ScrollViewReader { _ in
                            LazyVStack {
                                chart
                                if state.timeSettings { timeSetting }
                                preview.padding(.top, state.timeSettings ? 5 : -15)
                                loopPreview.padding(.top, 0)
                                if state.iobData.count > 5 {
                                    activeCOBView.padding(.top, 15)
                                    activeIOBView.padding(.top, 15)
                                }
                            }
                            .background(GeometryReader { geo in
                                let offset = -geo.frame(in: .named(scrollSpace)).minY
                                Color.black
                                    .preference(
                                        key: ScrollViewOffsetPreferenceKey.self,
                                        value: offset
                                    )
                            })
                        }
                    }
                    .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                        if !state.skipGlucoseChart, scrollOffset > scrollAmount {
                            display.toggle()
                        }
                    }
                    buttonPanel(geo)
                        .frame(height: 60)
                }
                .background(
                    colorScheme == .light ? .gray.opacity(IAPSconfig.backgroundOpacity * 2) : .white
                        .opacity(IAPSconfig.backgroundOpacity * 2)
                )
                .ignoresSafeArea(edges: .vertical)
                .overlay {
                    if let progress = state.bolusProgress, let amount = state.bolusAmount {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.black.opacity(1.0))
                                .frame(width: 190, height: 190)
                                .shadow(color: .white, radius: 2, x: 0, y: 0)
                            bolusProgressView(progress: progress, amount: amount)
                        }
                        .offset(y: -10)
                    }
                }
            }
            .onAppear(perform: startProgress) // Startet den Fortschritt, wenn die Ansicht erscheint
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .popup(isPresented: state.isStatusPopupPresented, alignment: .center, direction: .bottom) {
                popup
                    .padding(10)
                    .shadow(color: .white, radius: 2, x: 0, y: 0)
                    .cornerRadius(10)
                    .onTapGesture {
                        state.isStatusPopupPresented = false
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.height < 0 {
                                    state.isStatusPopupPresented = false
                                }
                            }
                    )
            }
            .onAppear(perform: configureView)
        }

        var popup: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusTitle).font(.suggestionHeadline).foregroundStyle(Color.white)
                    .padding(.bottom, 4)
                if let suggestion = state.suggestion {
                    TagCloudView(tags: suggestion.reasonParts).animation(.none, value: false)

                    Text(suggestion.reasonConclusion.capitalizingFirstLetter()).font(.suggestionSmallParts)
                        .foregroundStyle(Color.white)
                } else {
                    Text("No sugestion found").font(.suggestionHeadline).foregroundStyle(Color.white)
                }
                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    Text(NSLocalizedString("Error at", comment: "") + " " + dateFormatter.string(from: date))
                        .foregroundStyle(Color.white)
                        .font(.suggestionError)
                        .padding(.bottom, 4)
                        .padding(.top, 8)
                    Text(errorMessage).font(.suggestionError).fontWeight(.semibold).foregroundColor(.orange)
                } else if let suggestion = state.suggestion, (suggestion.bg ?? 100) == 400 {
                    Text("Invalid CGM reading (HIGH).").font(.suggestionError).bold().foregroundColor(.loopRed)
                        .padding(.top, 8)
                    Text("SMBs and High Temps Disabled.").font(.suggestionParts).foregroundStyle(Color.white)
                        .padding(.bottom, 4)
                }
            }
            .padding()
            .background(Color.black)
            .cornerRadius(10)
            .shadow(radius: 2)
        }
    }
}
