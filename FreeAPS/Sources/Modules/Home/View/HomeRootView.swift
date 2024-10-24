// HomeRootView Design by Rig22
import Charts
import Combine
import CoreData
import DanaKit
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

        @State private var progress: Double = 0.0

        private var numberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var tempRatenumberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2 // Immer zwei Nachkommastellen anzeigen
            return formatter
        }

        private var insulinnumberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0 // Keine unnötigen Nullen
            formatter.locale = Locale(identifier: "de_DE_POSIX")
            return formatter
        }

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if state.units == .mmolL {
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
            }
            formatter.roundingMode = .halfUp
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

        private var reservoirFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
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

        var pumpView: some View {
            PumpView(
                reservoir: $state.reservoir,
                battery: $state.battery,
                name: $state.pumpName,
                // expiresAtDate: $state.pumpExpiresAtDate,
                timerDate: $state.timerDate, timeZone: $state.timeZone,
                state: state
            )
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
        }

        // Bolus Progressbar

        public struct CircularProgressViewStyle: ProgressViewStyle {
            public func makeBody(configuration: Configuration) -> some View {
                let progress = CGFloat(configuration.fractionCompleted ?? 0)

                ZStack {
                    Circle()
                        .trim(from: 0.0, to: progress)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.insulin, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: 270))
                        .animation(.linear(duration: 0.25), value: progress)
                }
                .frame(width: 119, height: 119)
            }
        }

        func bolusProgressView(progress: Decimal, amount: Decimal) -> some View {
            ZStack {
                VStack(alignment: .leading, spacing: 5) {
                    let bolused = bolusProgressFormatter.string(from: (amount * progress) as NSNumber) ?? ""

                    Text(
                        bolused + " " + NSLocalizedString("of", comment: "") + " " + amount
                            .formatted(.number.precision(.fractionLength(2))) +
                            NSLocalizedString(" U", comment: " ")
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white)
                    .offset(x: -120, y: 50)
                    ProgressView(value: Double(truncating: progress as NSNumber))
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, 15)
                }
            }
        }

        // headerView

        private func startProgress() {
            Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                withAnimation(Animation.linear(duration: 0.02)) {
                    progress += 0.01
                }
                if progress >= 1.0 {
                    timer.invalidate()
                }
            }
        }

        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
            addBackground()
                .frame(
                    maxHeight: fontSize < .extraExtraLarge ? 230 + geo.safeAreaInsets.top : 145 + geo.safeAreaInsets.top
                )
                .overlay {
                    VStack {
                        // Oberer Bereich
                        VStack {
                            HStack {
                                // Linker Block
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "chart.xyaxis.line")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundColor(.white)

                                        if let tempRate = state.tempRate {
                                            let rateString = tempRatenumberFormatter.string(from: tempRate as NSNumber) ?? "0"
                                            let manualBasalString = state.apsManager.isManualTempBasal
                                                ? NSLocalizedString(" Manual", comment: "Manual Temp basal")
                                                : ""

                                            Text(rateString)
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                                +
                                                Text(" U/hr")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                +
                                                Text(manualBasalString)
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.leading, 6)
                                }

                                Spacer()

                                glucoseView
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        ZStack {
                                            if let progress = state.bolusProgress {
                                                ProgressView(value: Double(truncating: progress as NSNumber))
                                                    .progressViewStyle(CircularProgressViewStyle())
                                                    .frame(width: 120, height: 120)
                                                    .animation(.easeInOut, value: progress)
                                                // Hintergrundfüllung für den Glucosering
                                                Circle()
                                                    .fill(Color.rig22Background.opacity(1.0))
                                                    .frame(width: 110, height: 110)

                                                VStack {
                                                    Circle()
                                                        .fill(Color.red.opacity(1.0))
                                                        .frame(width: 20, height: 20)
                                                        .overlay(
                                                            Image(systemName: "xmark")
                                                                .font(.system(size: 13))
                                                                .foregroundColor(.white)
                                                                .onTapGesture {
                                                                    state.cancelBolus()
                                                                }
                                                        )
                                                        .padding(.bottom, 5)

                                                    if let progress = state.bolusProgress, let amount = state.bolusAmount {
                                                        let bolusedValue = amount * progress
                                                        let bolused = bolusProgressFormatter
                                                            .string(from: bolusedValue as NSNumber) ?? ""
                                                        let formattedAmount = amount
                                                            .formatted(.number.precision(.fractionLength(2)))

                                                        let bolusText = "\(bolused) / \(formattedAmount) U"

                                                        Text(bolusText)
                                                            .font(.system(size: 14))
                                                            .foregroundStyle(Color.white)
                                                            .offset(y: 2)
                                                    }
                                                }
                                            }
                                            VStack {
                                                loopView
                                                    .frame(maxHeight: .infinity)
                                                    .padding(.top, 225)
                                            }
                                        }
                                    )
                                Spacer()

                                // Rechter Block (eventualBG)
                                if let eventualBG = state.eventualBG {
                                    HStack(spacing: 4) {
                                        Text("⇢")
                                            .font(.statusFont)
                                            .foregroundStyle(.white)

                                        let eventualBGValue = state.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)

                                        if let formattedBG = fetchedTargetFormatter
                                            .string(from: eventualBGValue as NSNumber)
                                        {
                                            Text(formattedBG)
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                        }

                                        Text(state.units.rawValue)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white)
                                            .padding(.leading, -4)
                                    }
                                }
                            }
                            .padding(.horizontal, 22) // Seitenabstand für den HStack
                            .padding(.top, -15) // Oberer Rand
                        }
                        .offset(y: 90)

                        // Unterer Bereich
                        VStack(spacing: 20) {
                            Spacer()
                            HStack {
                                Spacer()
                                carbsView
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom, 20)
                                Spacer(minLength: 200) // Abstand zwischen Carbs und IOB
                                insulinView
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom, 20)
                                Spacer()
                            }
                            .dynamicTypeSize(...DynamicTypeSize.xLarge)
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .clipShape(Rectangle())
        }

        // Pie Animation

        struct PieSliceView: Shape {
            var startAngle: Angle
            var endAngle: Angle
            var animatableData: AnimatablePair<Double, Double> {
                get {
                    AnimatablePair(startAngle.degrees, endAngle.degrees)
                }
                set {
                    startAngle = Angle(degrees: newValue.first)
                    endAngle = Angle(degrees: newValue.second)
                }
            }

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

        class PieSegmentViewModel: ObservableObject {
            @Published var progress: Double = 0.0

            func updateProgress(to newValue: CGFloat, animate: Bool) {
                if animate {
                    withAnimation(.easeInOut(duration: 2.5)) { // Beispiel: Dauer der Animation anpassen
                        self.progress = Double(newValue)
                    }
                } else {
                    progress = Double(newValue)
                }
            }
        }

        struct FillablePieSegment: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

            var fillFraction: CGFloat
            var color: Color
            var backgroundColor: Color
            var displayText: String
            //  var symbolSize: CGFloat
            //  var symbol: String
            var animateProgress: Bool

            var body: some View {
                VStack {
                    ZStack {
                        Circle()
                            .fill(backgroundColor)
                            .opacity(0.3)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )

                        PieSliceView(
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                        )
                        .fill(color)
                        .frame(width: 60, height: 60)
                        .opacity(0.7)

                        /*   Image(systemName: symbol)
                         .resizable()
                         .scaledToFit()
                         .frame(width: symbolSize, height: symbolSize)
                         .foregroundColor(.white)*/
                    }

                    Text(displayText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.top, 0)
                }
                .offset(y: 10)
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { newValue in
                    pieSegmentViewModel.updateProgress(to: newValue, animate: true)
                }
            }
        }

        struct SmallFillablePieSegment: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

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
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )

                        PieSliceView(
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                        )
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .opacity(0.5) // Transparenz der Pie Farb Füllung

                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: symbolSize, height: symbolSize)
                            .foregroundColor(.white)
                    }

                    Text(displayText)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.top, 0)
                }
                .offset(y: 10)
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { newValue in
                    pieSegmentViewModel.updateProgress(to: newValue, animate: true)
                }
            }
        }

        // CarbView

        @StateObject private var carbsPieSegmentViewModel = PieSegmentViewModel()

        var carbsView: some View {
            HStack {
                if let settings = state.settingsManager {
                    HStack(spacing: 0) {
                        ZStack {
                            let substance = Double(state.suggestion?.cob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxCOB), 1)
                            let fraction = CGFloat(substance / maxValue)
                            let fill = max(min(fraction, 1.0), 0.0)
                            //  let carbSymbol = "fork.knife"

                            FillablePieSegment(
                                pieSegmentViewModel: carbsPieSegmentViewModel,
                                fillFraction: fill,
                                color: .loopYellow,
                                backgroundColor: .gray,
                                displayText: "\(numberFormatter.string(from: (state.suggestion?.cob ?? 0) as NSNumber) ?? "0")g",
                                //  symbolSize: 35,
                                //  symbol: "",
                                animateProgress: true
                            )
                            Image("carbs3")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
                        }
                    }
                }
            }
        }

        // InsulinView

        @StateObject private var insulinPieSegmentViewModel = PieSegmentViewModel()

        var insulinView: some View {
            HStack {
                if let settings = state.settingsManager {
                    HStack(spacing: 0) {
                        ZStack {
                            let substance = Double(state.suggestion?.iob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxIOB), 1)
                            let fraction = CGFloat(substance / maxValue)
                            let fill = max(min(fraction, 1.0), 0.0)
                            //  let insulinSymbol = "syringe"

                            FillablePieSegment(
                                pieSegmentViewModel: insulinPieSegmentViewModel,
                                fillFraction: fill,
                                color: substance < 0 ? .blue : .insulin,
                                backgroundColor: .gray,
                                displayText: "\(insulinnumberFormatter.string(from: (state.suggestion?.iob ?? 0) as NSNumber) ?? "0")U",
                                // symbolSize: 0,
                                // symbol: "",
                                animateProgress: true
                            )
                            Image("iob")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                        }
                    }
                }
            }
        }

        // DanaBar

        var infoPanel: some View {
            if state.danaBar {
                return AnyView(
                    ZStack {
                        addBackground()
                        info
                    }
                    .frame(maxWidth: .infinity, maxHeight: 80)
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        func reservoirLevelColor(for reservoirLevel: Double?) -> Color {
            guard let level = reservoirLevel else { return Color.gray.opacity(0.0) }

            if level < 20 {
                return .red.opacity(1.0)
            } else if level < 50 {
                return .yellow
            } else if level <= 300 {
                return .green
            } else {
                return .gray
            }
        }

        @StateObject private var cannulaPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var batteryPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var reservoirPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var connectionPieSegmentViewModel = PieSegmentViewModel()

        var info: some View {
            if state.danaBar {
                return AnyView(
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            // Reservoir Stand
                            HStack(spacing: 10) {
                                let maxValue = Decimal(300)
                                // let reservoirSymbol = "cross.vial"

                                if let reservoir = state.reservoirLevel {
                                    let fraction = CGFloat(
                                        reservoir / NSDecimalNumber(decimal: maxValue)
                                            .doubleValue
                                    )
                                    let fill = max(min(fraction, 1.0), 0.0)
                                    let reservoirColor = reservoirLevelColor(for: reservoir)
                                    let displayText: String = {
                                        if reservoir == 0 {
                                            return "--"
                                        } else {
                                            return "\(reservoirFormatter.string(from: reservoir as NSNumber) ?? "")U"
                                        }
                                    }()

                                    ZStack {
                                        SmallFillablePieSegment(
                                            pieSegmentViewModel: reservoirPieSegmentViewModel,
                                            fillFraction: fill,
                                            color: reservoirColor,
                                            backgroundColor: .gray,
                                            displayText: displayText,
                                            symbolSize: 24,
                                            symbol: "",
                                            animateProgress: true
                                        )
                                        .frame(width: 40, height: 40)

                                        Image("vial")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                    }
                                }
                            }

                            // PumpenBatterie

                            HStack(spacing: 10) {
                                var batteryColor: Color {
                                    if let batteryChargeString = state.pumpBatteryChargeRemaining,
                                       let batteryCharge = Double(batteryChargeString)
                                    {
                                        switch batteryCharge {
                                        case ...25:
                                            return .red
                                        case ...50:
                                            return .yellow
                                        default:
                                            return .green
                                        }
                                    } else {
                                        return Color.gray.opacity(0.0)
                                    }
                                }

                                let batteryText: String = {
                                    if let batteryChargeString = state.pumpBatteryChargeRemaining,
                                       let batteryCharge = Double(batteryChargeString)
                                    {
                                        return "\(Int(batteryCharge))%"
                                    } else {
                                        return "--"
                                    }
                                }()

                                if let batteryChargeString = state.pumpBatteryChargeRemaining,
                                   let batteryCharge = Double(batteryChargeString)
                                {
                                    let batteryFraction = CGFloat(batteryCharge) / 100.0
                                    //  let batteryText = "\(Int(batteryFraction * 100))%"

                                    HStack {
                                        ZStack {
                                            SmallFillablePieSegment(
                                                pieSegmentViewModel: batteryPieSegmentViewModel,
                                                fillFraction: batteryFraction,
                                                color: batteryColor,
                                                backgroundColor: .gray,
                                                displayText: batteryText,
                                                symbolSize: 24,
                                                symbol: "",
                                                animateProgress: true
                                            )
                                            .frame(width: 40, height: 40)

                                            Image("battery")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                        }
                                    }
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray)
                                            .opacity(0.3)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 1)
                                            )

                                        // Battery Fallback
                                        Image("battery")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 1)
                                            )
                                    }
                                }
                            }

                            // Dana Symbol

                            HStack(spacing: 10) {
                                Text("⇠")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.white)
                                    .padding(.trailing, 5)

                                ZStack {
                                    Circle()
                                        .fill(Color.gray)
                                        .opacity(0.3)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 1)
                                        )

                                    if state.danaIcon {
                                        Image("Dana_rs")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 42, height: 42)
                                    } else {
                                        Image("Dana_i")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 42, height: 42)
                                    }
                                }
                                .padding(.horizontal, 5)

                                Text("⇢")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.white)
                                    .padding(.trailing, 5)
                            }
                            .onTapGesture {
                                if state.pumpDisplayState != nil {
                                    state.setupPump = true
                                }
                            }

                            // Kanülenalter

                            HStack(spacing: 10) {
                                let cannulaFraction: CGFloat = {
                                    if let cannulaHours = state.cannulaHours {
                                        if cannulaHours > 71 {
                                            return 72.0 // Voller Pie für Werte über 71 Stunden
                                        } else {
                                            return CGFloat(max(1.0 - cannulaHours / 72.0, 0.0))
                                        }
                                    } else {
                                        return 0.0
                                    }
                                }()

                                let cannulaColor: Color = {
                                    if let cannulaHours = state.cannulaHours {
                                        switch cannulaHours {
                                        case ..<48:
                                            return .green
                                        case 48 ..< 71:
                                            return .yellow
                                        case 72...:
                                            return Color.red.opacity(1.0)
                                        default:
                                            return .gray
                                        }
                                    } else {
                                        return Color.gray.opacity(0.3)
                                    }
                                }()

                                ZStack {
                                    SmallFillablePieSegment(
                                        pieSegmentViewModel: cannulaPieSegmentViewModel,
                                        fillFraction: cannulaFraction, // Umgekehrte Füllung
                                        color: cannulaColor,
                                        backgroundColor: .gray,
                                        // displayText: "",
                                        displayText: state.cannulaHours != nil ? "\(Int(state.cannulaHours!))h" : "--",
                                        symbolSize: 22,
                                        symbol: "",
                                        animateProgress: true
                                    )
                                    .frame(width: 40, height: 40)

                                    Image("infusion")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                }
                            }

                            // Bluetooth Connection

                            HStack(spacing: 10) {
                                let connectionFraction: CGFloat = state.isConnected ? 1.0 : 0.0
                                let connectionColor: Color = state.isConnected ? .green : .green

                                ZStack {
                                    SmallFillablePieSegment(
                                        pieSegmentViewModel: connectionPieSegmentViewModel,
                                        fillFraction: connectionFraction,
                                        color: connectionColor,
                                        backgroundColor: .gray,
                                        displayText: state.isConnected ? "On" : "--",
                                        symbolSize: 22,
                                        symbol: "",
                                        animateProgress: true
                                    )
                                    .frame(width: 40, height: 40)

                                    Image("bluetooth")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                    }
                    .onReceive(timer) { _ in
                        state.specialDanaKitFunction()
                    }.dynamicTypeSize(...DynamicTypeSize.xxLarge)
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect() // Aktualisiert alle 5 Sekunden

        var mainChart: some View {
            ZStack {
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
                    maxBolusValue: $state.maxBolusValue,
                    useInsulinBars: $state.useInsulinBars
                )
            }
            .modal(for: .dataTable, from: self)
            .padding()
        }

        var chart: some View {
            let ratio = state.timeSettings ? 1.9 : 1.8 // TimeSetting ein
            let ratio2 = state.timeSettings ? 1.78 : 1.68 // TimeSetting aus

            return addBackground()
                .overlay {
                    VStack(spacing: 0) {
                        infoPanel
                        mainChart
                        legendPanel
                        tempTargetbar
                            .frame(width: UIScreen.main.bounds.width * 0.99) // Breite der mainChart anpassen
                    }
                }
                // Anpassung: Abhängig von timeSettings und Schriftgröße
                .frame(minHeight: UIScreen.main.bounds.height / (state.timeSettings ? ratio : ratio2))
        }

        var legendPanel: some View {
            if state.legendsSwitch {
                return AnyView(
                    ZStack {
                        HStack {
                            Group {
                                Circle().fill(Color.insulin).frame(width: 8, height: 8)
                                    .padding(.leading, 8)
                                Text("IOB")
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.insulin)
                            }
                            Group {
                                Circle().fill(Color.zt).frame(width: 8, height: 8)
                                    .padding(.leading, 8)
                                Text("ZT")
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.zt)
                            }
                            Group {
                                Circle().fill(Color.loopYellow).frame(width: 8, height: 8)
                                    .padding(.leading, 8)
                                Text("COB")
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.loopYellow)
                            }
                            Group {
                                Circle().fill(Color.uam).frame(width: 8, height: 8)
                                    .padding(.leading, 8)
                                Text("UAM")
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.uam)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        var tempTargetbar: some View {
            ZStack {
                if state.tempTargetbar {
                    addBackground()
                    Targetbar
                } else {
                    addBackground()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: state.tempTargetbar ? 25 : 0)
            .padding(.top, 12)
        }

        var Targetbar: some View {
            HStack {
                if state.pumpSuspended {
                    Text("Pump suspended")
                        .font(.extraSmall)
                        .bold()
                        .foregroundStyle(Color.orange)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.3, alignment: .leading)
                        .frame(height: 20)
                }

                if let tempTargetString = tempTargetString, !(fetchedPercent.first?.enabled ?? false) {
                    Text(tempTargetString)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.4, alignment: .center)
                        .frame(height: 20)
                } else {
                    profileView
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.4, alignment: .center)
                        .frame(height: 20)
                }

                if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                    Text("Check Max IOB Setting")
                        .font(.extraSmall)
                        .foregroundColor(.orange)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.3, alignment: .trailing)
                }
            }
        }

        // BottomInfoBar mit TimeButtons

        var infoPanel2: some View {
            ZStack {
                addBackground()
                info2
            }
            .frame(maxWidth: .infinity, maxHeight: 25)
            .padding(.top, 120)
        }

        struct Buttons: Identifiable {
            let label: String
            let number: String
            var active: Bool
            let hours: Int?
            var action: (() -> Void)?
            var id: String { label }
        }

        @State var timeButtons: [Buttons] = [
            Buttons(label: "3", number: "3", active: false, hours: 3, action: nil),
            Buttons(label: "6", number: "6", active: false, hours: 6, action: nil),
            Buttons(label: "12", number: "12", active: false, hours: 12, action: nil),
            Buttons(label: "24", number: "24", active: false, hours: 24, action: nil)
            //    Buttons(label: "UX", number: "UX", active: false, hours: nil, action: nil)
        ]

        func highlightButtons() {
            for i in 0 ..< timeButtons.count {
                timeButtons[i].active = timeButtons[i].hours == state.hours
            }
        }

        func updateButtonActions() {
            for i in 0 ..< timeButtons.count {
                if timeButtons[i].label == "UX" {
                    timeButtons[i].action = {
                        state.showModal(for: .statisticsConfig)
                    }
                }
            }
        }

        var info2: some View {
            if state.timeSettings {
                return AnyView(
                    HStack(spacing: 25) {
                        // Linker Stack

                        if let currentISF = state.isf {
                            HStack(spacing: 4) {
                                Text("ISF:")
                                    .foregroundColor(.white)
                                    .font(.system(size: 15))

                                Text(glucoseFormatter.string(from: currentISF as NSNumber) ?? " ")
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 15))
                            }
                            .padding(.leading, 25)
                            .frame(maxWidth: 100, alignment: .leading) // Links ausgerichtet
                        } else {
                            HStack(spacing: 4) {
                                Text("ISF:")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 15))

                                // Platzhalter, wenn kein ISF vorhanden ist
                                Text("--")
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 15))
                            }
                            // .padding(.leading, 25)
                            .frame(maxWidth: 100, alignment: .leading)
                        }
                        Spacer()
                        // Mittlerer Stack

                        HStack(spacing: 10) {
                            ForEach(timeButtons) { button in
                                Text(button.active ? NSLocalizedString(button.label, comment: "") : button.number)
                                    .onTapGesture {
                                        if let action = button.action {
                                            action()
                                        } else if let hours = button.hours {
                                            state.hours = hours
                                            highlightButtons()
                                        }
                                    }
                                    .font(.system(size: 13))
                                    .frame(minWidth: 20, maxHeight: 25)
                                    .padding(.horizontal, 2)
                                    .foregroundStyle(Color.white)
                                    .background(button.active ? Color.blue.opacity(0.7) : Color.clear)
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                        .font(buttonFont)
                        .frame(maxWidth: .infinity, alignment: .center)

                        .onAppear {
                            highlightButtons()
                            updateButtonActions()
                        }
                        Spacer()
                        // Rechter Stack - TDD

                        HStack {
                            Text("TDD: " + (numberFormatter.string(from: state.tddActualAverage as NSNumber) ?? "0"))
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(.trailing, 25)
                        }
                        .frame(maxWidth: 100, alignment: .trailing)
                    }
                    .padding(.top, -110)
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        @ViewBuilder private func buttonPanel(_ geo: GeometryProxy) -> some View {
            ZStack {
                addBackground()
                LinearGradient(
                    gradient: Gradient(colors: [.rig22bottomPanel, .rig22bottomPanel]),
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
                            // Circle()
                            //     .fill(Color.gray)
                            //     .opacity(0.3)
                            Image("carbs")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
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
                        Image("insulin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                    }
                    /*  label: {
                         VStack {
                             Image("insulin")
                                 .resizable()
                                 .scaledToFit()
                                 .frame(width: 50, height: 50)
                             Text("Bolus")
                                 .font(.system(size: 14))
                             // .padding(.top, 2) // optional, um etwas Abstand zu schaffen
                         }
                         .padding(.bottom, 10)
                     }*/
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.white)
                    Spacer()
                    if state.allowManualTemp {
                        Button { state.showModal(for: .manualTempBasal) }
                        label: {
                            Image("insulin")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
                        }
                        .foregroundStyle(Color.white)
                        Spacer()
                    }
                    ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom))
                        {
                            Image(isOverride ? "profilefill" : "profile")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .padding(8)
                            // .background(isOverride ? .blue.opacity(0.3) : .clear)
                            // .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        Image(isTarget ? "temptargetactive" : "temptarget")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                            .font(.system(size: 14))
                            .buttonStyle(.borderless)
                            .padding(8)
                            .foregroundStyle(Color.white)
                            // .background(isTarget ? .blue.opacity(0.15) : .clear)
                            // .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    Button { state.showModal(for: .statisticsConfig) }
                    label: {
                        Image("ux")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                            .font(.system(size: 14))
                            .buttonStyle(.borderless)
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.white)
                    Spacer()
                    Button { state.showModal(for: .settings) }
                    label: {
                        Image("settings2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                            .font(.system(size: 14))
                            .buttonStyle(.borderless)
                            .foregroundStyle(Color.white)
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
            .padding(.bottom, 20)
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
                                        Text(shortened).font(.system(size: 15)).foregroundStyle(Color.white)
                                    } else {
                                        Text(name).font(.system(size: 15)).foregroundStyle(Color.white)
                                    }
                                }
                            } else { Text("📉") } // Hypo Treatment is not actually a preset
                        } else if override.percentage != 100 {
                            Text(override.percentage.formatted() + " %").font(.statusFont).foregroundStyle(.secondary)
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

        @ViewBuilder private func glucoseHeaderView() -> some View {
            addBackground()
                .frame(maxHeight: 90)
                .overlay {
                    VStack {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [.rig22Background, .rig22Background]),
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
                        .foregroundStyle(Color.white)
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
                                infoPanel2
                                preview
                                loopPreview
                                if state.iobData.count > 5 {
                                    activeCOBView.padding(.top, 15)
                                    activeIOBView.padding(.top, 15)
                                }
                            }
                            .background(GeometryReader { geo in
                                let offset = -geo.frame(in: .named(scrollSpace)).minY
                                Color.rig22Background
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
                    //      .padding(.top, 10)
                    buttonPanel(geo)
                        .frame(height: 60)
                }
                .background(Color.rig22Background)
                .ignoresSafeArea(edges: .vertical)
            }
            .onAppear(perform: startProgress)
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
            .background(Color.rig22Background)
            .cornerRadius(10)
            .shadow(radius: 2)
        }
    }
}
