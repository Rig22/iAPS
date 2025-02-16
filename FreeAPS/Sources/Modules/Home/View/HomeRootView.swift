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
        @State var showBolusActiveAlert = false
        @State var displayAutoHistory = false

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
            if state.data.units == .mmolL {
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
            if state.data.units == .mmolL {
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

        private var daysFormatter: DateComponentsFormatter {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day, .hour]
            formatter.unitsStyle = .abbreviated
            return formatter
        }

        let percentageFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0 // Keine Nachkommastellen
            return formatter
        }()

        private var spriteScene: SKScene {
            let scene = SnowScene()
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            return scene
        }

        var glucoseView: some View {
            let doubleBolusProgress = Binding<Double?> {
                state.bolusProgress.map { Double(truncating: $0 as NSNumber) }
            } set: { newValue in
                if let newDecimalValue = newValue.map({ Decimal($0) }) {
                    state.bolusProgress = newDecimalValue
                }
            }

            return CurrentGlucoseView(
                recentGlucose: $state.recentGlucose,
                timerDate: $state.data.timerDate,
                delta: $state.glucoseDelta,
                units: $state.data.units,
                alarm: $state.alarm,
                lowGlucose: $state.data.lowGlucose,
                highGlucose: $state.data.highGlucose,
                bolusProgress: doubleBolusProgress,
                displayDelta: $state.displayDelta,
                displayExpiration: $state.displayExpiration
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

        // Pie Animation Anfang

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
                    withAnimation(.easeInOut(duration: 2.5)) {
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
            var symbolSize: CGFloat
            var symbol: String
            var animateProgress: Bool

            var body: some View {
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.darkGray.opacity(0.5))
                            .frame(width: 60, height: 60)

                        Circle()
                            .stroke(Color.white, lineWidth: 0)

                        PieSliceView(
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                        )
                        .fill(color)
                        .frame(width: 60, height: 60)
                        .opacity(0.6)
                    }

                    Text(displayText)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(.top, 0)
                }
                .offset(y: 10)
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { _, newValue in
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
                            // .fill(backgroundColor)
                            .fill(Color.darkGray.opacity(0.5))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 0)
                            )

                        PieSliceView(
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                        )
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .opacity(0.6) // Transparenz der Pie Farb Füllung

                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: symbolSize, height: symbolSize)
                            .foregroundColor(.white)
                    }

                    Text(displayText)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.top, 0)
                }
                .offset(y: 10)
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { _, newValue in
                    pieSegmentViewModel.updateProgress(to: newValue, animate: true)
                }
            }
        }

        struct BigFillablePieSegment: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

            var fillFraction: CGFloat
            var color: Color
            var displayText: String
            var animateProgress: Bool

            var body: some View {
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(1.0))
                            .frame(width: 110, height: 110)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 0)
                            )

                        PieSliceView(
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                        )
                        .fill(color)
                        .frame(width: 110, height: 110)
                        .opacity(1.0)
                    }

                    Text(displayText)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(.top, 5)
                }
                .offset(y: 14)
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { _, newValue in
                    pieSegmentViewModel.updateProgress(to: newValue, animate: true)
                }
            }
        }

        @StateObject private var bolusPieSegmentViewModel = PieSegmentViewModel()

        @ViewBuilder private func bolusProgressView() -> some View {
            if let progress = state.bolusProgress, let amount = state.bolusAmount {
                let fillFraction = max(min(CGFloat(progress), 1.0), 0.0)
                let bolusedValue = amount * progress
                let bolused = bolusProgressFormatter.string(from: bolusedValue as NSNumber) ?? ""
                let formattedAmount = amount.formatted(.number.precision(.fractionLength(2)))
                let displayText = "\(bolused) / \(formattedAmount) U"

                VStack {
                    ZStack {
                        BigFillablePieSegment(
                            pieSegmentViewModel: bolusPieSegmentViewModel,
                            fillFraction: fillFraction,
                            color: backgroundColor,
                            displayText: displayText,
                            animateProgress: true
                        )
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .fill(Color.red)
                                .frame(width: 25, height: 25)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                )
                                .onTapGesture {
                                    state.cancelBolus()
                                }
                        )
                    }
                }
            }
        }

        private var sageView: some View {
            ZStack {
                if let date = state.recentGlucose?.sessionStartDate {
                    let timeAgo: TimeInterval = -1 * date.timeIntervalSinceNow

                    HStack {
                        Image(systemName: "clock") // Oder ein passenderes Symbol
                            .font(.system(size: 12))
                            .foregroundStyle(.white)

                        Text(
                            (daysFormatter.string(from: timeAgo) ?? "").trimmingCharacters(in: .whitespaces)
                                .replacingOccurrences(of: ",", with: " ")
                        )
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    }
                    .background(TimeEllipse(characters: 8))
                } else {
                    EmptyView() // Stellt sicher, dass immer ein View existiert
                }
            }
            .font(.timeSettingFont)
            .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.large)
            .frame(maxHeight: .infinity, alignment: .center)
            .offset(x: 0, y: 3)
        }

        // Header Anfang
        // Temp Basal Anfang
        private var tempRateView: some View {
            ZStack {
                VStack {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)

                        if let tempRate = state.tempRate {
                            let rateString = tempRatenumberFormatter.string(from: tempRate as NSNumber) ?? "0"
                            let manualBasalString = state.apsManager.isManualTempBasal
                                ? NSLocalizedString(" Manual", comment: "Manual Temp basal")
                                : ""

                            HStack(spacing: 0) {
                                Text(rateString)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                Text("\u{00A0}U/hr") // Ein geschütztes Leerzeichen
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    +
                                    Text(manualBasalString)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text("---")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                    .font(.timeSettingFont)
                    .background(TimeEllipseBig(characters: 10))
                }
            }
            .offset(x: 20, y: 0)
        }

        // Temp Basal Ende
        // GlucoseWheel Anfang
        struct BigFillablePieSegment2: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

            private let backgroundColorCircle = Color(red: 0.31, green: 0.42, blue: 0.66)

            var fillFraction: CGFloat
            var color: Color
            var displayText: String
            var animateProgress: Bool

            var body: some View {
                ZStack {
                    Circle()
                        .fill(backgroundColorCircle.opacity(1.0))
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 0)
                        )

                    PieSliceView(
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                    )
                    .fill(color)
                    .frame(width: 110, height: 110)
                    .opacity(1.0)

                    Text(displayText)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 100)
                        .offset(y: 27)
                }
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { _, newValue in
                    pieSegmentViewModel.updateProgress(to: newValue, animate: true)
                }
            }
        }

        @StateObject private var bolusPieSegmentViewModel2 = PieSegmentViewModel()

        @ViewBuilder private func bolusProgressView2() -> some View {
            if let progress = state.bolusProgress, let amount = state.bolusAmount {
                let fillFraction = max(min(CGFloat(progress), 1.0), 0.0)
                let bolusedValue = amount * progress
                let bolused = bolusProgressFormatter.string(from: bolusedValue as NSNumber) ?? ""
                let formattedAmount = amount.formatted(.number.precision(.fractionLength(2)))
                let displayText = "\(bolused) / \(formattedAmount) U"

                VStack {
                    ZStack {
                        BigFillablePieSegment2(
                            pieSegmentViewModel: bolusPieSegmentViewModel2,
                            fillFraction: fillFraction,
                            color: backgroundColor,
                            displayText: displayText,
                            animateProgress: true
                        )
                        .frame(width: 110, height: 110)

                        // X-Button Overlay
                        Circle()
                            .fill(Color.red)
                            .frame(width: 25, height: 25)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            )
                            .onTapGesture {
                                state.cancelBolus()
                            }
                    }
                }
            }
        }

        // GlucoseWheel Ende

        // eventualBG Anfang

        private var eventualBGView: some View {
            ZStack {
                VStack {
                    HStack {
                        /* Image(systemName: "timer")
                         .font(.system(size: 14))
                         .foregroundStyle(.teal)*/

                        if let eventualBG = state.eventualBG {
                            HStack(spacing: 4) {
                                Text("⇢")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)

                                let eventualBGValue = state.data.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)

                                if let formattedBG = fetchedTargetFormatter
                                    .string(from: eventualBGValue as NSNumber)
                                {
                                    Text(formattedBG)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }

                                Text(state.data.units.rawValue)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .padding(.leading, -1)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Text("⇢")
                                    .font(.statusFont)
                                    .foregroundStyle(.white)

                                Text("---")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .font(.timeSettingFont)
                    .background(TimeEllipseBig(characters: 10))
                }
            }
            .offset(x: -20, y: 0)
        }

        // eventualBG Ende

        @ViewBuilder private func glucoseAndLoopView() -> some View {
            VStack {
                glucoseView
                    .frame(width: 110, height: 110)
            }
        }

        @ViewBuilder private func loopViewSelector() -> some View {
            if let loopOption = LoopViewOption(rawValue: state.loopViewOption) {
                switch loopOption {
                case .view1:
                    loopView
                        .frame(maxHeight: .infinity)
                        .offset(y: 25)
                        .padding(.bottom, 10)

                case .view2:
                    loopView2
                        .frame(maxHeight: .infinity)
                        .offset(y: 25)
                        .padding(.bottom, 10)
                }
            } else {
                // Fallback-Ansicht, falls der String-Wert ungültig ist
                Text("Ungültige Ansichtsauswahl")
                    .foregroundColor(.red)
            }
        }

        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
            /* LinearGradient(
                 gradient: Gradient(colors: [
                     .black.opacity(0.7),
                     .black.opacity(0.5),
                     .black.opacity(0.3),
                     .clear,
                     .clear,
                     .clear
                 ]),
                 startPoint: .top,
                 endPoint: .bottom
             )*/
            LinearGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .clear,
                    .clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(
                maxHeight: fontSize < .extraExtraLarge ? 105 + geo.safeAreaInsets.top : 0 + geo.safeAreaInsets.top
            )
            .padding(.top, geo.safeAreaInsets.top)
            .overlay {
                VStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 5) {
                                    tempRateView
                                        .offset(y: 8)
                                }
                            }
                            Spacer()
                            HStack {
                                Spacer()
                                if state.bolusProgress != nil, state.bolusAmount != nil {
                                    bolusProgressView2()
                                        .offset(y: 8)

                                } else {
                                    glucoseAndLoopView()
                                        .offset(y: 8)
                                }
                                Spacer()
                            }
                            if state.displayExpiration {
                                ZStack {
                                    sageView
                                        .offset(y: -45)
                                    eventualBGView
                                        .offset(y: 8)
                                }
                            } else {
                                eventualBGView
                                    .offset(y: 8)
                            }
                        }
                    }
                    .offset(y: state.displayExpiration ? 25 : 80)
                    Spacer()
                }
            }
            /*   // Schatten oben
             .overlay(
                 LinearGradient(
                     gradient: Gradient(colors: [
                         backgroundColor.opacity(1),
                         backgroundColor.opacity(1),
                         // Color.black.opacity(0.5),
                         Color.black.opacity(0.4),
                         Color.black.opacity(0.3),
                         Color.black.opacity(0.2),
                         Color.black.opacity(0.1),
                         Color.black.opacity(0.0)
                     ]),
                     startPoint: .top,
                     endPoint: .bottom
                 )
                 .frame(height: 25),
                 alignment: .top

             )*/
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        backgroundColor.opacity(1),
                        backgroundColor.opacity(1),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.1),
                        Color.black.opacity(0.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 25)
                .offset(y: 50),
                alignment: .top
            )
            // Schatten unten
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.1),
                        Color.black.opacity(0)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 20),
                alignment: .bottom
            )
        }

        // Head Ende

        // TopBar Anfang

        // CarbView Anfang
        @StateObject private var carbsPieSegmentViewModel = PieSegmentViewModel()

        var carbsView: some View {
            HStack {
                if let settings = state.settingsManager {
                    HStack(spacing: 0) {
                        ZStack {
                            let substance = Double(state.data.suggestion?.cob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxCOB), 1)
                            let fraction = CGFloat(substance / maxValue)
                            let fill = max(min(fraction, 1.0), 0.0)
                            //  let carbSymbol = "fork.knife"

                            FillablePieSegment(
                                pieSegmentViewModel: carbsPieSegmentViewModel,
                                fillFraction: fill,
                                color: .loopYellow,
                                backgroundColor: .clear,
                                displayText: "\(numberFormatter.string(from: (state.data.suggestion?.cob ?? 0) as NSNumber) ?? "0")g",
                                symbolSize: 0,
                                symbol: "syringe",
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

        // CarbView Ende

        var loopView: some View {
            LoopView(
                suggestion: $state.data.suggestion,
                enactedSuggestion: $state.enactedSuggestion,
                closedLoop: $state.closedLoop,
                timerDate: $state.data.timerDate,
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

        var loopView2: some View {
            LoopView2(
                suggestion: $state.data.suggestion,
                enactedSuggestion: $state.enactedSuggestion,
                closedLoop: $state.closedLoop,
                timerDate: $state.data.timerDate,
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

        @StateObject private var insulinPieSegmentViewModel = PieSegmentViewModel()

        var insulinView: some View {
            HStack {
                if let settings = state.settingsManager {
                    HStack(spacing: 0) {
                        ZStack {
                            let substance = Double(state.data.suggestion?.iob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxIOB), 1)

                            let fraction = CGFloat(abs(substance) / maxValue)
                            let fill = min(fraction, 1.0) // Begrenzung auf max 1

                            let isNegative = substance < 0
                            let pieColor: Color = isNegative ? .red : .insulin
                            let _: Double = isNegative ? 90 : -90

                            FillablePieSegment(
                                pieSegmentViewModel: insulinPieSegmentViewModel,
                                fillFraction: fill,
                                color: pieColor,
                                backgroundColor: .clear,
                                displayText: "\(insulinnumberFormatter.string(from: (state.data.suggestion?.iob ?? 0) as NSNumber) ?? "0")U",
                                symbolSize: 0,
                                symbol: "syringe",
                                animateProgress: true
                            )

                            Image("iob")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
                        }
                    }
                    .onTapGesture {
                        if state.pumpDisplayState != nil {
                            state.setupPump = true
                        }
                    }
                }
            }
        }

        // InsulinView Ende
        // TopBar Ende

        // DanaBars

        func reservoirLevelColor(for reservoirLevel: Double?) -> Color {
            guard let level = reservoirLevel else { return Color.gray.opacity(0.0) }

            if level < 20 {
                return .red.opacity(0.7)
            } else if level < 50 {
                return .yellow.opacity(0.7)
            } else if level <= 300 {
                return .green.opacity(0.7)
            } else {
                return .gray.opacity(0.7)
            }
        }

        @StateObject private var cannulaPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var batteryPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var reservoirPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var reservoirAgePieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var connectionPieSegmentViewModel = PieSegmentViewModel()

        // Insulin Concentration Badge ->
        struct NonStandardInsulin: View {
            let concentration: Double
            private var formatter: NumberFormatter {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 0
                return formatter
            }

            var body: some View {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(.insulin).opacity(0.5))
                        .frame(width: 37, height: 17)
                        .overlay {
                            Text("U" + (formatter.string(from: concentration * 100 as NSNumber) ?? ""))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white)
                        }
                }
                .offset(x: -25, y: -10)
            }
        }

        // DanaBar 1

        var info: some View {
            if state.danaBar {
                return AnyView(
                    VStack(spacing: 20) {
                        HStack(spacing: 30) {
                            // Reservoir Stand
                            HStack(spacing: 10) {
                                let maxValue = Decimal(300)
                                if let reservoir = state.reservoirLevel {
                                    let reservoirDecimal = Decimal(reservoir)
                                    let fractionDecimal = reservoirDecimal / maxValue
                                    let fraction = CGFloat(NSDecimalNumber(decimal: fractionDecimal).doubleValue)

                                    let fill = max(min(fraction, 1.0), 0.0)

                                    let reservoirColor = reservoirLevelColor(for: reservoir)

                                    let displayText: String = {
                                        if reservoir == 0 {
                                            return "--"
                                        } else {
                                            let concentrationValue = Decimal(concentration.last?.concentration ?? 1.0)
                                            let adjustedReservoir = reservoirDecimal * concentrationValue
                                            return (reservoirFormatter.string(from: adjustedReservoir as NSNumber) ?? "") + "U"
                                        }
                                    }()

                                    ZStack {
                                        SmallFillablePieSegment(
                                            pieSegmentViewModel: reservoirPieSegmentViewModel,
                                            fillFraction: fill,
                                            color: reservoirColor,
                                            backgroundColor: .clear,
                                            displayText: displayText,
                                            symbolSize: 0,
                                            symbol: "cross.vial",
                                            animateProgress: true
                                        )
                                        .frame(width: 45, height: 45)

                                        Image("vial")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)

                                        if state.settingsManager?.settings.insulinBadge == true {
                                            if concentration.last?.concentration == 1 {
                                                NonStandardInsulin(concentration: 1) // Zeigt U100 als Standardwert an
                                            } else if (concentration.last?.concentration ?? 1) != 1 {
                                                NonStandardInsulin(concentration: concentration.last?.concentration ?? 1)
                                            }
                                        }
                                    }
                                }
                            }
                            .onTapGesture {
                                if state.pumpDisplayState != nil {
                                    state.setupPump = true
                                }
                            }

                            // Reservoir Alter

                            HStack(spacing: 10) {
                                let reservoirAge: String = state.reservoirAge ?? "--"

                                let fillFraction: CGFloat = {
                                    if let insulinAgeOption = InsulinAgeOption(rawValue: state.insulinAgeOption),
                                       let maxInsulinAge = Double(insulinAgeOption.displayName),
                                       let reservoirAge = state.reservoirAge
                                    {
                                        let pattern = #"(?:(\d+)d)?(?:(\d+)h)?"#
                                        let regex = try? NSRegularExpression(pattern: pattern)
                                        var totalHours: Int = 0

                                        if let match = regex?.firstMatch(
                                            in: reservoirAge,
                                            range: NSRange(reservoirAge.startIndex..., in: reservoirAge)
                                        ) {
                                            if let dayRange = Range(match.range(at: 1), in: reservoirAge),
                                               let days = Int(reservoirAge[dayRange])
                                            {
                                                totalHours += days * 24
                                            }
                                            if let hourRange = Range(match.range(at: 2), in: reservoirAge),
                                               let hours = Int(reservoirAge[hourRange])
                                            {
                                                totalHours += hours
                                            }
                                        }

                                        if totalHours >= Int(maxInsulinAge) {
                                            return 1.0 // Überschritten: vollständig rot gefüllt
                                        } else {
                                            // Berechnung für verbleibende Zeit
                                            return CGFloat(min(
                                                max((maxInsulinAge - Double(totalHours)) / maxInsulinAge, 0.0),
                                                1.0
                                            ))
                                        }
                                    } else {
                                        return 0.0 // Fallback-Wert
                                    }
                                }()

                                let insulinColor: Color = {
                                    if let reservoirAge = state.reservoirAge {
                                        let pattern = #"(?:(\d+)d)?(?:(\d+)h)?"#
                                        let regex = try? NSRegularExpression(pattern: pattern)
                                        var totalHours: Int = 0

                                        if let match = regex?.firstMatch(
                                            in: reservoirAge,
                                            range: NSRange(reservoirAge.startIndex..., in: reservoirAge)
                                        ) {
                                            if let dayRange = Range(match.range(at: 1), in: reservoirAge),
                                               let days = Int(reservoirAge[dayRange])
                                            {
                                                totalHours += days * 24
                                            }
                                            if let hourRange = Range(match.range(at: 2), in: reservoirAge),
                                               let hours = Int(reservoirAge[hourRange])
                                            {
                                                totalHours += hours
                                            }
                                        }

                                        if let insulinAgeOption = InsulinAgeOption(rawValue: state.insulinAgeOption),
                                           let maxInsulinAge = Double(insulinAgeOption.displayName)
                                        {
                                            if CGFloat(totalHours) >= CGFloat(maxInsulinAge) {
                                                return .red.opacity(1.0) // Überschritten: Rot
                                            }

                                            let warningThreshold = maxInsulinAge * 0.75
                                            let dangerThreshold = maxInsulinAge

                                            switch CGFloat(totalHours) {
                                            case dangerThreshold...:
                                                return .red.opacity(1.0)
                                            case warningThreshold ..< dangerThreshold:
                                                return .yellow.opacity(0.7)
                                            default:
                                                return .green.opacity(0.7)
                                            }
                                        }
                                    }
                                    return .clear // Fallback-Farbe
                                }()

                                ZStack {
                                    SmallFillablePieSegment(
                                        pieSegmentViewModel: reservoirAgePieSegmentViewModel,
                                        fillFraction: fillFraction,
                                        color: insulinColor,
                                        backgroundColor: .clear,
                                        displayText: reservoirAge,
                                        symbolSize: 0,
                                        symbol: "timer",
                                        animateProgress: true
                                    )
                                    .frame(width: 45, height: 45)

                                    Image("vial_timer")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 45, height: 45)
                                }
                            }

                            // Kanülenalter
                            HStack(spacing: 10) {
                                let cannulaDisplayText: String = {
                                    if let cannulaHours = state.cannulaHours {
                                        let days = Int(cannulaHours) / 24
                                        let hours = Int(cannulaHours) % 24
                                        return "\(days)d\(hours)h"
                                    } else {
                                        return "--"
                                    }
                                }()

                                let cannulaFraction: CGFloat = {
                                    if let cannulaHours = state.cannulaHours,
                                       let cannulaAgeOption = CannulaAgeOption(
                                           rawValue: state
                                               .cannulaAgeOption
                                       )
                                    {
                                        let remainingHours = cannulaAgeOption
                                            .maxCannulaAge - cannulaHours
                                        if remainingHours <= 0 {
                                            return 1.0 // Vollständig gefüllt bei Überschreitung
                                        } else {
                                            return CGFloat(min(max(
                                                remainingHours / cannulaAgeOption.maxCannulaAge,
                                                0.0
                                            ), 1.0))
                                        }
                                    } else {
                                        return 0.0 // Leer, wenn keine Werte vorhanden sind
                                    }
                                }()

                                let cannulaColor: Color = {
                                    if let cannulaHours = state.cannulaHours,
                                       let cannulaAgeOption = CannulaAgeOption(
                                           rawValue: state
                                               .cannulaAgeOption
                                       )
                                    {
                                        let maxCannulaAge = cannulaAgeOption.maxCannulaAge
                                        let warningThreshold = maxCannulaAge * 0.75
                                        let dangerThreshold = maxCannulaAge

                                        if cannulaHours >= maxCannulaAge {
                                            return .red.opacity(1.0) // Überschritten: Rot
                                        }

                                        switch CGFloat(cannulaHours) {
                                        case dangerThreshold...:
                                            return .red.opacity(1.0)
                                        case warningThreshold ..< dangerThreshold:
                                            return .yellow.opacity(0.7)
                                        default:
                                            return .green.opacity(0.7)
                                        }
                                    } else {
                                        return .clear // Fallback-Farbe für unbekanntes Alter
                                    }
                                }()

                                ZStack {
                                    SmallFillablePieSegment(
                                        pieSegmentViewModel: cannulaPieSegmentViewModel,
                                        fillFraction: cannulaFraction,
                                        color: cannulaColor,
                                        backgroundColor: .clear,
                                        displayText: cannulaDisplayText,
                                        symbolSize: 0,
                                        symbol: "cross.vial",
                                        animateProgress: true
                                    )
                                    .frame(width: 45, height: 45)

                                    Image("infusion")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
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
                                            return .red.opacity(0.7)
                                        case ...50:
                                            return .yellow.opacity(0.7)
                                        default:
                                            return .green.opacity(0.7)
                                        }
                                    } else {
                                        return Color.gray.opacity(0.3)
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

                                    ZStack {
                                        SmallFillablePieSegment(
                                            pieSegmentViewModel: batteryPieSegmentViewModel,
                                            fillFraction: batteryFraction,
                                            color: batteryColor,
                                            backgroundColor: .clear,
                                            displayText: batteryText,
                                            symbolSize: 0,
                                            symbol: "cross.vial",
                                            animateProgress: true
                                        )
                                        .frame(width: 45, height: 45)

                                        Image("battery")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                    }
                                } else {
                                    ZStack {
                                        Circle()
                                            // .fill(Color.clear)
                                            // .opacity(0.3)
                                            .fill(Color.darkGray.opacity(0.5))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 0)
                                            )

                                        Image("battery")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                    }
                                    .padding(.bottom, 1)
                                }
                            }

                            /* HStack(spacing: 10) {
                                 sageView
                             }*/

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
                                        symbolSize: 0,
                                        symbol: "cross.vial",
                                        animateProgress: true
                                    )
                                    .frame(width: 45, height: 45)

                                    Image("bluetooth")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                    .onReceive(timer) { _ in
                        state.specialDanaKitFunction()
                    }

                    .onChange(of: state.insulinConcentration) { _, newValue in
                        if newValue != 1.0, state.settingsManager?.settings.insulinBadge == true {}
                    }.dynamicTypeSize(...DynamicTypeSize.xxLarge)
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        var infoPanel3: some View {
            if state.danaBar {
                return AnyView(
                    ZStack {
                        // backgroundColor
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(maxWidth: .infinity, maxHeight: 0)

                        info3
                    }
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        // DanaBar 2

        var info3: some View {
            if state.danaBar {
                return AnyView(
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            // Reservoir Stand
                            HStack(spacing: 10) {
                                let maxValue = Decimal(300)
                                if let reservoir = state.reservoirLevel {
                                    let reservoirDecimal = Decimal(reservoir)
                                    let fractionDecimal = reservoirDecimal / maxValue
                                    let fraction = CGFloat(NSDecimalNumber(decimal: fractionDecimal).doubleValue)

                                    let fill = max(min(fraction, 1.0), 0.0)
                                    let reservoirColor = reservoirLevelColor(for: reservoir)

                                    let displayText: String = {
                                        if reservoir == 0 {
                                            return "--"
                                        } else {
                                            let concentrationValue = Decimal(concentration.last?.concentration ?? 1.0)
                                            let adjustedReservoir = reservoirDecimal * concentrationValue
                                            return (reservoirFormatter.string(from: adjustedReservoir as NSNumber) ?? "") + "U"
                                        }
                                    }()

                                    ZStack {
                                        SmallFillablePieSegment(
                                            pieSegmentViewModel: reservoirPieSegmentViewModel,
                                            fillFraction: fill,
                                            color: reservoirColor,
                                            backgroundColor: .clear,
                                            displayText: displayText,
                                            symbolSize: 0,
                                            symbol: "cross.vial",
                                            animateProgress: true
                                        )
                                        .frame(width: 40, height: 40)

                                        Image("vial")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)

                                        if state.settingsManager?.settings.insulinBadge == true {
                                            if concentration.last?.concentration == 1 {
                                                NonStandardInsulin(concentration: 1) // Zeigt U100 als Standardwert an
                                            } else if (concentration.last?.concentration ?? 1) != 1 {
                                                NonStandardInsulin(concentration: concentration.last?.concentration ?? 1)
                                            }
                                        }
                                    }
                                }
                            }
                            .onTapGesture {
                                if state.pumpDisplayState != nil {
                                    state.setupPump = true
                                }
                            }

                            // Kanülenalter
                            HStack(spacing: 10) {
                                let cannulaDisplayText: String = {
                                    if let cannulaHours = state.cannulaHours {
                                        let days = Int(cannulaHours) / 24
                                        let hours = Int(cannulaHours) % 24
                                        return "\(days)d\(hours)h"
                                    } else {
                                        return "--"
                                    }
                                }()

                                let cannulaFraction: CGFloat = {
                                    if let cannulaHours = state.cannulaHours,
                                       let cannulaAgeOption = CannulaAgeOption(
                                           rawValue: state
                                               .cannulaAgeOption
                                       )
                                    {
                                        let remainingHours = cannulaAgeOption
                                            .maxCannulaAge - cannulaHours
                                        if remainingHours <= 0 {
                                            return 1.0
                                        } else {
                                            return CGFloat(min(max(
                                                remainingHours / cannulaAgeOption.maxCannulaAge,
                                                0.0
                                            ), 1.0))
                                        }
                                    } else {
                                        return 0.0
                                    }
                                }()

                                let cannulaColor: Color = {
                                    if let cannulaHours = state.cannulaHours,
                                       let cannulaAgeOption = CannulaAgeOption(
                                           rawValue: state
                                               .cannulaAgeOption
                                       )
                                    {
                                        let maxCannulaAge = cannulaAgeOption.maxCannulaAge
                                        let warningThreshold = maxCannulaAge * 0.75
                                        let dangerThreshold = maxCannulaAge

                                        if cannulaHours >= maxCannulaAge {
                                            return .red.opacity(1.0) // Überschritten: Rot
                                        }

                                        switch CGFloat(cannulaHours) {
                                        case dangerThreshold...:
                                            return .red.opacity(1.0)
                                        case warningThreshold ..< dangerThreshold:
                                            return .yellow.opacity(0.7)
                                        default:
                                            return .green.opacity(0.7)
                                        }
                                    } else {
                                        return .clear // Fallback-Farbe für unbekanntes Alter
                                    }
                                }()

                                ZStack {
                                    SmallFillablePieSegment(
                                        pieSegmentViewModel: cannulaPieSegmentViewModel,
                                        fillFraction: cannulaFraction,
                                        color: cannulaColor,
                                        backgroundColor: .clear,
                                        displayText: cannulaDisplayText,
                                        symbolSize: 0,
                                        symbol: "cross.vial",
                                        animateProgress: true
                                    )
                                    .frame(width: 45, height: 45)

                                    Image("infusion")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                }
                            }

                            // Der Pie füllt sich
                            /*    let cannulaFraction: CGFloat = {
                                 if let cannulaHours = state.cannulaHours,
                                    let cannulaAgeOption = CannulaAgeOption(rawValue: state.cannulaAgeOption)
                                 {
                                     if cannulaHours >= cannulaAgeOption.maxCannulaAge {
                                         return 1.0
                                     } else {
                                         return CGFloat(min(max(cannulaHours / cannulaAgeOption.maxCannulaAge, 0.0), 1.0))
                                     }
                                 } else {
                                     return 0.0
                                 }
                             }()*/

                            // Dana Symbol
                            HStack(spacing: 10) {
                                Text("⇠")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.white)
                                    .padding(.trailing, 5)

                                ZStack {
                                    Image(
                                        state.danaIconOption
                                            .rawValue
                                    )
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 75, height: 50)
                                }

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
                            // PumpenBatterie
                            HStack(spacing: 10) {
                                var batteryColor: Color {
                                    if let batteryChargeString = state.pumpBatteryChargeRemaining,
                                       let batteryCharge = Double(batteryChargeString)
                                    {
                                        switch batteryCharge {
                                        case ...25:
                                            return .red.opacity(0.7)
                                        case ...50:
                                            return .yellow.opacity(0.7)
                                        default:
                                            return .green.opacity(0.7)
                                        }
                                    } else {
                                        return Color.gray.opacity(0.3)
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

                                    ZStack {
                                        SmallFillablePieSegment(
                                            pieSegmentViewModel: batteryPieSegmentViewModel,
                                            fillFraction: batteryFraction,
                                            color: batteryColor,
                                            backgroundColor: .clear,
                                            displayText: batteryText,
                                            symbolSize: 0,
                                            symbol: "cross.vial",
                                            animateProgress: true
                                        )
                                        .frame(width: 45, height: 45)

                                        Image("battery")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                    }
                                } else {
                                    ZStack {
                                        Circle()
                                            // .fill(Color.clear)
                                            // .opacity(0.3)
                                            .fill(Color.darkGray.opacity(0.5))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 0)
                                            )

                                        Image("battery")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                    }
                                    .padding(.bottom, 1)
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
                                        symbolSize: 0,
                                        symbol: "cross.vial",
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
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                    .onReceive(timer) { _ in
                        state.specialDanaKitFunction()
                    }
                    .onChange(of: state.insulinConcentration) { _, newValue in
                        if newValue != 1.0, state.settingsManager?.settings.insulinBadge == true {}
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        var timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect() // Aktualisiert alle 2 Sekunden

        var mainChart: some View {
            let isChartBackgroundColored: Bool = state.settingsManager?.settings.chartBackgroundColored ?? false

            return Group {
                if isChartBackgroundColored {
                    ZStack {
                        ColouredBackground()

                        if state.animatedBackground {
                            SpriteView(scene: spriteScene, options: [.allowsTransparency])
                                .ignoresSafeArea()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        }
                        MainChartView(data: state.data, triggerUpdate: $triggerUpdate)
                    }
                } else {
                    ZStack {
                        ColouredBackground2()

                        if state.animatedBackground {
                            SpriteView(scene: spriteScene, options: [.allowsTransparency])
                                .ignoresSafeArea()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        }
                        MainChartView(data: state.data, triggerUpdate: $triggerUpdate)
                    }
                }
            }
            .padding(.bottom, 5)
            .padding(.leading, 15)
            .padding(.trailing, 15)
            .modal(for: .dataTable, from: self)
        }

        var chart: some View {
            VStack(spacing: 0) {
                if state.carbInsulinLoopViewOption {
                    HStack {
                        Spacer()
                        carbsView
                            .frame(height: 50)
                            .padding(.top, 10)

                        Spacer()

                        loopViewSelector()
                            .frame(height: 50)

                        Spacer()

                        insulinView
                            .frame(height: 50)
                            .padding(.top, 10)

                        Spacer()
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }

                Group {
                    if state.danaBarViewOption == "view1" {
                        info
                    } else {
                        info3
                    }
                    mainChart.padding(.top, 15)
                    legendPanel.padding(.top, 15)
                    tempTargetbar.padding(.top, 20)
                    infoPanel.padding(.top, 20).padding(.bottom, 10)
                        .frame(width: UIScreen.main.bounds.width)
                }
            }
            // .frame(minHeight: UIScreen.main.bounds.height / 1.44) // Je größer der Wert, je kleiner der Chart // ORIGINAL
            .frame(minHeight: UIScreen.main.bounds.height / 1.5) // Je größer der Wert, je kleiner der Chart
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
                    }
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        var tempTargetbar: some View {
            ZStack {
                if state.tempTargetbar {
                    Targetbar
                } else {}
            }
            .frame(maxWidth: .infinity, maxHeight: state.tempTargetbar ? 25 : 0)
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

                if state.closedLoop, state.maxIOB == 0 {
                    Text("Check Max IOB Setting")
                        .font(.extraSmall)
                        .foregroundColor(.orange)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.3, alignment: .trailing)
                }
            }
        }

        // BottomInfoBar mit TimeButtons

        var infoPanel: some View {
            ZStack {
                info2
            }
            .frame(maxWidth: .infinity)
        }

        var timeSetting: some View {
            let string = "\(state.hours) " + NSLocalizedString("hours", comment: "") + "   "
            return Menu(string) {
                Button("3 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 3 })
                Button("6 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 6 })
                Button("9 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 9 })
                Button("12 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 12 })
                Button("24 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 24 })
                Button("UI/UX Settings", action: { state.showModal(for: .statisticsConfig) })
            }
            .foregroundStyle(Color.white)
            .font(.timeSettingFont)
            .padding(.vertical, 15)
            .background(TimeEllipse(characters: string.count))
        }

        var info2: some View {
            if state.timeSettings {
                return AnyView(
                    HStack(spacing: 15) {
                        // Linker Stack
                        Spacer()

                        HStack {
                            isfView
                                .foregroundColor(.white)
                        }.padding(.leading, 0)
                            .frame(maxWidth: 100, alignment: .leading)

                        Spacer()

                        // Mittlerer Stack

                        HStack(spacing: 0) {
                            timeSetting
                        }
                        Spacer()

                        // Rechter Stack - TDD

                        HStack {
                            tddView
                                .foregroundColor(.white)
                        }.padding(.trailing, 25)
                            .frame(maxWidth: 100, alignment: .trailing)

                        Spacer()
                    }
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        /*   private var isfView: some View {
             ZStack {
                 HStack {
                     Image(systemName: "divide").font(.system(size: 16)).foregroundStyle(.white)
                     Text("\(state.data.suggestion?.sensitivityRatio ?? 1)").foregroundStyle(.white)
                 }
                 .font(.timeSettingFont)
                 .background(TimeEllipse(characters: 10))
                 .onTapGesture {
                     if state.autoisf {
                         displayAutoHistory.toggle()
                     }
                 }
             }.offset(x: 30)
         }

         private var tddView: some View {
             ZStack {
                 HStack {
                     Image(systemName: "circle.slash").font(.system(size: 14)).foregroundStyle(.white)
                     Text("\(targetFormatter.string(from: state.tddActualAverage as NSNumber) ?? "0")").foregroundStyle(.white)
                 }
                 .font(.timeSettingFont)
                 .background(TimeEllipse(characters: 10))
             }.offset(x: 0)
         }*/

        private var sensitivityPercentage: String {
            let sensitivityValue = (state.data.suggestion?.sensitivityRatio ?? 1) as NSDecimalNumber
            return percentageFormatter.string(from: NSNumber(value: sensitivityValue.doubleValue * 100)) ?? "0"
        }

        private var isfView: some View {
            ZStack {
                HStack {
                    HStack {
                        // Image(systemName: "divide")
                        Text("ISF")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)

                        Text("\(sensitivityPercentage)%")
                            .foregroundStyle(.white)
                            .font(.timeSettingFont)
                    }
                    .background(TimeEllipse(characters: 12))
                    .onTapGesture {
                        if state.autoisf {
                            displayAutoHistory.toggle()
                        }
                    }
                }
                .offset(x: 30)
            }
        }

        private var tddView: some View {
            ZStack {
                HStack {
                    Image(systemName: "circle.slash").font(.system(size: 13)).foregroundStyle(.white)
                    /* Text("\(targetFormatter.string(from: state.tddActualAverage as NSNumber) ?? "0")").foregroundStyle(.white)*/

                    Text("\(targetFormatter.string(from: state.tddActualAverage as NSNumber) ?? "0") U")
                        .foregroundStyle(.white)
                }
                .font(.timeSettingFont)
                .background(TimeEllipse(characters: 12))
            }.offset(x: 0)
        }

        @State private var didLongPress = false
        // buttonPanel line.diagonal circle.slash circle.and.line.horizontal

        @ViewBuilder private func buttonPanel(_ geo: GeometryProxy) -> some View {
            ZStack {
                backgroundColor
                    /* LinearGradient(
                         gradient: Gradient(colors: [.clear, .clear]),
                         startPoint: .top,
                         endPoint: .bottom
                     )*/
                    .frame(height: 50 + geo.safeAreaInsets.bottom)

                let isOverride = fetchedPercent.first?.enabled ?? false
                let isTarget = (state.tempTarget != nil)
                HStack {
                    ZStack {
                        buttonWithCircle(iconName: "carbs3", circleColor: Color.darkGray.opacity(0.5)) {
                            state.showModal(for: .addCarbs(editMode: false, override: false))
                        }
                        if let carbsReq = state.carbsRequired {
                            Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Capsule().fill(Color.red))
                                .offset(x: 20, y: 10)
                        }
                    }
                    Spacer()

                    buttonWithCircle(iconName: "iob", circleColor: Color.darkGray.opacity(0.5)) {
                        (state.bolusProgress != nil) ? showBolusActiveAlert = true :
                            state.showModal(for: .bolus(
                                waitForSuggestion: state.useCalc ? true : false,
                                fetch: false
                            ))
                    }
                    Spacer()

                    if state.allowManualTemp {
                        buttonWithCircle(iconName: "insulin", circleColor: Color.darkGray.opacity(0.5)) {
                            state.showModal(for: .manualTempBasal)
                        }
                        Spacer()
                    }

                    buttonWithCircle(
                        iconName: isOverride ? "profilefill" : "profile",
                        circleColor: Color.darkGray.opacity(0.5)
                    ) {
                        if isOverride {
                            showCancelAlert.toggle()
                        } else {
                            state.showModal(for: .overrideProfilesConfig)
                        }
                    }
                    Spacer()

                    if state.useTargetButton {
                        buttonWithCircle(
                            iconName: isTarget ? "temptargetactive" : "temptarget",
                            circleColor: Color.darkGray.opacity(0.5)
                        ) {
                            if isTarget {
                                showCancelTTAlert.toggle()
                            } else {
                                state.showModal(for: .addTempTarget)
                            }
                        }
                        Spacer()
                    }

                    buttonWithCircle(iconName: "ux", circleColor: Color.darkGray.opacity(0.5)) {
                        state.showModal(for: .statisticsConfig)
                    }
                    Spacer()

                    /* buttonWithCircle(iconName: "settings2", circleColor: Color.darkGray.opacity(0.5)) {
                         state.showModal(for: .settings)
                     }*/

                    buttonWithCircle(iconName: "settings2", circleColor: Color.darkGray.opacity(0.5)) {
                        if !didLongPress {
                            state.showModal(for: .settings)
                        }
                        didLongPress = false
                    }
                    .simultaneousGesture(
                        LongPressGesture().onEnded { _ in
                            let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                            impactHeavy.impactOccurred()
                            state.isStatusPopupPresented.toggle()
                            didLongPress = true
                        }
                    )
                }
                .padding(.horizontal, state.allowManualTemp ? 5 : 24)
                // .padding(.bottom, geo.safeAreaInsets.bottom)
                .padding(.bottom, 15)
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

        @ViewBuilder private func buttonWithCircle(
            iconName: String,
            circleColor: Color,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 50, height: 50)
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white)
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

        var DayView: some View {
            let isChartBackgroundColored: Bool = state.settingsManager?.settings.chartBackgroundColored ?? false
            let backgroundView = isChartBackgroundColored ? AnyView(ColouredBackground()) : AnyView(ColouredBackground2())

            return Group {
                ZStack {
                    if !state.skipGlucoseChart {
                        backgroundView
                        glucoseHeaderView().padding(.top, 8).padding(.bottom, 10)
                    } else {
                        EmptyView()
                    }
                }

                ZStack {
                    backgroundView
                    preview.padding(.top, 15)
                }

                ZStack {
                    backgroundView
                    loopPreview
                }

                if state.iobData.count >= 0 {
                    ZStack {
                        backgroundView
                        activeCOBView.padding(.bottom, 20)
                    }

                    ZStack {
                        backgroundView
                        activeIOBView.padding(.bottom, 20)
                    }
                }
            }
            .padding(.horizontal, 15)
        }

        @ViewBuilder private func glucoseHeaderView() -> some View {
            ColouredBackground2()
                .frame(maxHeight: 200)

            VStack {
                glucosePreview
            }
            .clipShape(Rectangle())
            .foregroundStyle(Color.white)
        }

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
                    (($0.glucose ?? 0) > veryHigh || Decimal($0.glucose ?? 0) < low) ? Color.red : Decimal($0.glucose ?? 0) >
                        high ? Color.yellow : Color.green
                )
                .symbolSize(5)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.white)
                    AxisTick().foregroundStyle(Color.white)
                    AxisValueLabel().foregroundStyle(Color.white)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine().foregroundStyle(Color.white)
                    AxisTick().foregroundStyle(Color.white)
                    AxisValueLabel().foregroundStyle(Color.white)
                }
            }
            .chartYScale(
                domain: minimumRange * (state.data.units == .mmolL ? 0.0555 : 1.0) ... maximum *
                    (state.data.units == .mmolL ? 0.0555 : 1.0)
            )
            .chartXScale(
                domain: Date.now.addingTimeInterval(-1.days.timeInterval) ... Date.now
            )
            .frame(height: 100)
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.large)
        }

        var preview: some View {
            VStack {
                Text("Time In Range")
                    .font(.previewHeadline)
                    .foregroundColor(.white)

                ZStack {
                    VStack {
                        PreviewChart(
                            readings: $state.readings,
                            lowLimit: $state.data.lowGlucose,
                            highLimit: $state.data.highGlucose
                        )
                        .padding()
                    }
                }
                .padding(.vertical, 5)
            }
            .onTapGesture {
                state.showModal(for: .statistics)
            }
        }

        var loopPreview: some View {
            ColouredBackground2()
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

        var activeIOBView: some View {
            ColouredBackground2()
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
            ColouredBackground2()
                .frame(minHeight: 230)
                .overlay {
                    ActiveCOBView(data: $state.iobData)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
        }

        var backgroundColor: Color {
            BackgroundColorOption(rawValue: state.backgroundColorOptionRawValue)?.color ?? .black
        }

        var body: some View {
            GeometryReader { geo in
                if onboarded.first?.firstRun ?? true, let openAPSSettings = state.openAPSSettings {
                    importResetSettingsView(settings: openAPSSettings)
                } else {
                    VStack(spacing: 0) {
                        headerView(geo)
                        ScrollView {
                            ScrollViewReader { _ in
                                LazyVStack {
                                    chart.padding(.top, 10)
                                    /* if !state.skipGlucoseChart {
                                         glucoseHeaderView().padding(.top, 10)
                                     }
                                       preview.padding(.top, 30)
                                      loopPreview.padding(.top, 10).padding(.bottom, 25)
                                      if state.iobData.count >= 0 {
                                          activeCOBView.padding(.bottom, 25)
                                          activeIOBView.padding(.bottom, 25)
                                      }*/
                                    DayView.padding(.bottom, 30).padding(.top, 30)
                                }
                                .background(GeometryReader { geo in
                                    let offset = -geo.frame(in: .named(scrollSpace)).minY
                                    backgroundColor // Background für den scrollview Bereich
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
                    .background(backgroundColor) // Das ist der Hintergrund für alles!!!!
                    .ignoresSafeArea(edges: .vertical)
                    .onAppear(perform: startProgress)
                    .navigationTitle("Home")
                    .navigationBarHidden(true)
                    .ignoresSafeArea(.keyboard) // Ignoriert die Tastatur bei Safe Area
                    .sheet(isPresented: $displayAutoHistory) {
                        AutoISFHistoryView(units: state.data.units)
                    }

                    // Popup für Statusanzeige
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
                    .onAppear {
                        if onboarded.first?.firstRun ?? true {
                            state.fetchPreferences()
                        }
                        configureView()
                    }
                }
            }
        }

        var popup: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusTitle).font(.suggestionHeadline).foregroundStyle(Color.white)
                    .padding(.bottom, 4)
                if let suggestion = state.data.suggestion {
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
                } else if let suggestion = state.data.suggestion, (suggestion.bg ?? 100) == 400 {
                    Text("Invalid CGM reading (HIGH).").font(.suggestionError).bold().foregroundColor(.loopRed)
                        .padding(.top, 8)
                    Text("SMBs and High Temps Disabled.").font(.suggestionParts).foregroundStyle(Color.white)
                        .padding(.bottom, 4)
                }
            }
            .padding()
            .background(backgroundColor) // Für das Popup mit den Loop Informationen
            .cornerRadius(10)
            .shadow(radius: 2)
        }

        private func importResetSettingsView(settings: Preferences) -> some View {
            Restore.RootView(
                resolver: resolver,
                openAPS: settings
            )
        }
    }
}
