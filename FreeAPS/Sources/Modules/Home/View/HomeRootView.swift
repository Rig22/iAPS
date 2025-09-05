// HomeRootView Design by Rig22
import Charts
import Combine
import CoreData
import DanaKit
import SpriteKit
import SwiftDate
import SwiftUI
import Swinject
import UIKit

extension Home {
    struct RootView: BaseView {
        let resolver: Resolver
        // State
        @StateObject var state = StateModel()
        @State var isStatusPopupPresented = false
        @State var showCancelAlert = false
        @State var showCancelTTAlert = false
        @State var triggerUpdate = false
        @State var scrollOffset = CGFloat.zero
        @State var display = false
        @State var displayGlucose = false
        @State var showBolusActiveAlert = false
        @State var displayAutoHistory = false
        @State var displayDynamicHistory = false
        @State private var isSensorBlinking = false
        @State private var progress: Double = 0.0
        @State private var animatedFill: CGFloat = 0.0
        @State private var animatedInsulinFill: CGFloat = 0.0
        @State private var sensorAgeText: String = ""
        @State private var didLongPress = false
        @State private var timer: Timer? = nil

        // StateObject
        @StateObject private var bolusPieSegmentViewModel2 = PieSegmentViewModel()
        @StateObject private var carbsPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var insulinPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var cannulaPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var reservoirPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var reservoirAgePieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var connectionPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var insulinAgePieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var batteryAgePieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var sensorAgeSegmentViewModel = PieSegmentViewModel()
        @State private var timerInterval: TimeInterval = 2 // Startet nach 2 Sekunden

        @Namespace var scrollSpace

        let scrollAmount: CGFloat = 290
        let buttonFont = Font.custom("TimeButtonFont", size: 14)

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

        private var remainingTimeFormatter: DateComponentsFormatter {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day, .hour]
            formatter.unitsStyle = .abbreviated
            return formatter
        }

        private var remainingTimeFormatterDays: DateComponentsFormatter {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day]
            formatter.unitsStyle = .short
            return formatter
        }

        var bolusProgressFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimum = 0
            formatter.maximumFractionDigits = state.settingsManager.preferences.bolusIncrement > 0.05 ? 1 : 2
            formatter.minimumFractionDigits = state.settingsManager.preferences.bolusIncrement > 0.05 ? 1 : 2
            formatter.allowsFloats = true
            formatter.roundingIncrement = Double(state.settingsManager.preferences.bolusIncrement) as NSNumber
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

        // Preference Key zur Breitenmessung
        struct TextWidthKey: PreferenceKey {
            static var defaultValue: CGFloat = 0
            static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
                value = nextValue()
            }
        }

        struct TimeEllipse: View {
            var button3D: Bool = false

            var body: some View {
                GeometryReader { geometry in
                    ZStack {
                        let ellipseWidth = max(geometry.size.width + 10, 80) // Mindestbreite 80

                        if button3D {
                            // Immer gefüllte Hintergrundfarbe
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.dynamicIconBackground)
                                .frame(width: ellipseWidth, height: 25)

                            // 3D-Rand-Glow
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .dynamicTopGlow.opacity(0.5),
                                            .dynamicTopGlow.opacity(0.3),
                                            Color.clear,
                                            .dynamicBottomShadow.opacity(0.3),
                                            .dynamicBottomShadow
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: ellipseWidth, height: 25)
                                .shadow(color: .dynamicTopGlow.opacity(0.3), radius: 1, x: -1, y: -1)
                                .shadow(color: .dynamicBottomShadow.opacity(0.6), radius: 1, x: 1, y: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.dynamicIconBackground)
                                .frame(width: ellipseWidth, height: 25)
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.dynamicIconForeground, lineWidth: 0)
                                .frame(width: ellipseWidth, height: 25)
                        }
                    }
                    .frame(width: geometry.size.width, height: 25, alignment: .center)
                }
                .frame(height: 25)
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

        // Fillable PieSegments Anfang
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

            var color: Color
            var backgroundColor: Color
            var displayText: String
            var symbolSize: CGFloat
            var symbol: String
            var animateProgress: Bool
            var button3D: Bool
            var fillFraction: CGFloat
            var symbolRotation: Double = 0
            var symbolBackgroundColor: Color = .clear
            var symbolColor: Color? = nil

            var body: some View {
                VStack {
                    ZStack {
                        if button3D {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .dynamicTopGlow.opacity(0.9),
                                            .dynamicTopGlow.opacity(0.4),
                                            .dynamicBottomShadow.opacity(0.3),
                                            .dynamicBottomShadow
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 50, height: 50)
                                .shadow(color: .dynamicTopGlow.opacity(0.6), radius: 2, x: -1, y: -1)
                                .shadow(color: .dynamicBottomShadow.opacity(0.8), radius: 2, x: 1, y: 1)
                        }

                        // Fortschrittsanzeige
                        PieSliceView(
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                        )
                        .fill(color.opacity(0.0))
                        .frame(width: 50, height: 50)
                        .opacity(0.5)

                        // Symbol-Hintergrund
                        if symbolBackgroundColor != .clear {
                            Circle()
                                // .fill(symbolBackgroundColor)
                                .fill(Color.dynamicIconBackground)

                                .frame(width: 50, height: 50)
                        }

                        // Symbol
                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: symbolSize, height: symbolSize)
                            .foregroundColor(symbolColor ?? .dynamicIconForeground)
                            .rotationEffect(.degrees(symbolRotation))
                    }

                    // Text
                    Text(displayText)
                        .font(.system(size: 15))
                        .foregroundColor(.dynamicSecondaryText)
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
            var backgroundColor: Color?
            var color: Color
            var animateProgress: Bool
            var button3D: Bool

            var body: some View {
                ZStack {
                    if button3D {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .dynamicTopGlow.opacity(0.9),
                                        .dynamicTopGlow.opacity(0.6),
                                        .clear,
                                        .dynamicBottomShadow.opacity(0.3),
                                        .dynamicBottomShadow
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .shadow(color: .dynamicTopGlow.opacity(0.6), radius: 2, x: -1, y: -1)
                            .shadow(color: .dynamicBottomShadow.opacity(0.8), radius: 2, x: 1, y: 1)
                    }

                    // Fortschrittsanzeige
                    PieSliceView(
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                    )
                    .fill(color)
                    .frame(width: 120, height: 120)
                    .opacity(1.0)
                }
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { _, newValue in
                    pieSegmentViewModel.updateProgress(to: newValue, animate: true)
                }
            }
        }

        // Fillable PieSegments Ende

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

        struct SageView: View {
            let recentGlucose: BloodGlucose?
            let displayExpiration: Bool
            let displaySAGE: Bool
            let sensordays: Double
            let button3D: Bool

            @State private var animatedFill: CGFloat = 0.0

            var body: some View {
                HStack {
                    if let date = recentGlucose?.sessionStartDate {
                        let sensorAge: TimeInterval = (-1 * date.timeIntervalSinceNow)
                        let expiration = sensordays - sensorAge
                        let secondsOfDay = 8.64E4

                        // Farbe abhängig vom Alter
                        let lineColour: Color = {
                            if sensorAge >= sensordays - secondsOfDay * 1 {
                                return .red.opacity(0.9)
                            } else if sensorAge >= sensordays - secondsOfDay * 2 {
                                return .orange
                            } else {
                                return .dynamicIconForeground
                            }
                        }()

                        // Füllgrad = aktuelles Alter / Gesamtdauer
                        let targetFill = CGFloat(sensorAge / sensordays)

                        ZStack {
                            FillablePieSegment(
                                pieSegmentViewModel: PieSegmentViewModel(),
                                color: lineColour,
                                backgroundColor: .clear,
                                displayText: {
                                    let minutesAndHours = (displayExpiration && expiration < 1 * secondsOfDay) ||
                                        (displaySAGE && sensorAge < 1 * secondsOfDay)

                                    return !minutesAndHours ?
                                        (
                                            remainingTimeFormatterDays
                                                .string(from: displayExpiration ? expiration : sensorAge) ?? ""
                                        )
                                        .replacingOccurrences(of: ",", with: " ")
                                        :
                                        (
                                            remainingTimeFormatter
                                                .string(from: displayExpiration ? expiration : sensorAge) ?? ""
                                        )
                                        .replacingOccurrences(of: ",", with: " ")
                                }(),
                                symbolSize: 0,
                                symbol: "sensor.tag.radiowaves.forward.fill",
                                animateProgress: true,
                                button3D: button3D,
                                fillFraction: animatedFill,
                                symbolBackgroundColor: .dynamicIconBackground
                            )

                            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 27, height: 27)
                                .foregroundColor(.dynamicIconForeground)
                                .verticalFillMask(
                                    fillFraction: animatedFill,
                                    gradient: LinearGradient(
                                        gradient: Gradient(colors: [.dynamicIconBackground, lineColour]),
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .offset(y: -1.5)
                        }
                        .onAppear {
                            withAnimation(.easeOut(duration: 5.6)) {
                                animatedFill = max(min(targetFill, 1.0), 0.0)
                            }
                        }
                        .onChange(of: targetFill) { _, newValue in
                            withAnimation(.easeInOut(duration: 10.6)) {
                                animatedFill = max(min(newValue, 1.0), 0.0)
                            }
                        }
                    }
                }
                .frame(width: 50, height: 50)
            }

            private var remainingTimeFormatter: DateComponentsFormatter {
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.day, .hour]
                formatter.unitsStyle = .abbreviated
                return formatter
            }

            private var remainingTimeFormatterDays: DateComponentsFormatter {
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.day]
                formatter.unitsStyle = .short
                return formatter
            }
        }

        var glucoseView: some View {
            let doubleBolusProgress = Binding<Double?> {
                state.bolusProgress.map { Double(truncating: $0 as NSNumber) }
            } set: { newValue in
                if let newDecimalValue = newValue.map({ Decimal($0) }) {
                    state.bolusProgress = newDecimalValue
                }
            }

            return ZStack(alignment: .center) {
                if state.button3D {
                    Circle()
                        .fill(Color.dynamicIconBackground)
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.dynamicBottomShadow.opacity(0.3), radius: 5, x: 3, y: 3)

                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .dynamicTopGlow.opacity(0.9),
                                    .dynamicTopGlow.opacity(0.4),
                                    .dynamicBottomShadow.opacity(0.3),
                                    .dynamicBottomShadow
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 120, height: 120)
                } else {
                    Circle()
                        .fill(Color.dynamicIconBackground)
                        .frame(width: 120, height: 120)
                }

                // Glucose-Anzeige
                CurrentGlucoseView(
                    recentGlucose: $state.recentGlucose,
                    timerDate: $state.data.timerDate,
                    delta: $state.glucoseDelta,
                    units: $state.data.units,
                    alarm: $state.alarm,
                    lowGlucose: $state.data.lowGlucose,
                    highGlucose: $state.data.highGlucose,
                    bolusProgress: doubleBolusProgress,
                    displayDelta: $state.displayDelta,
                    alwaysUseColors: $state.alwaysUseColors,
                    scrolling: $displayGlucose,
                    displaySAGE: $state.displaySAGE,
                    displayExpiration: $state.displayExpiration,
                    cgm: $state.cgm,
                    sensordays: $state.sensorDays
                )
                .zIndex(2)
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

        // Progressbar by Rig22
        public struct CircularProgressViewStyle: ProgressViewStyle {
            public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
                let progress = CGFloat(configuration.fractionCompleted ?? 0)

                ZStack {
                    Circle()
                        .trim(from: 0.0, to: progress)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.5)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: 270))
                        .animation(.linear(duration: 0.25), value: progress)
                }
                .frame(width: 120, height: 120)
            }
        }

        @ViewBuilder private func bolusProgressView() -> some View {
            if let progress = state.bolusProgress, let amount = state.bolusAmount {
                let fillFraction = max(min(CGFloat(progress), 1.0), 0.0)
                let bolused = bolusProgressFormatter.string(from: (amount * progress) as NSNumber) ?? ""

                ZStack(alignment: .center) {
                    BigFillablePieSegment(
                        pieSegmentViewModel: bolusPieSegmentViewModel2,
                        fillFraction: fillFraction,
                        backgroundColor: backgroundColor,
                        color: .blue,
                        animateProgress: true,
                        button3D: state.button3D
                    )
                    .frame(width: 120, height: 120)

                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Circle()
                        .fill(Color.dynamicIconBackground)
                        .frame(width: 100, height: 100)

                    ZStack {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 25, height: 25)
                            .overlay(
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.dynamicIconForeground)
                            )
                    }
                    .contentShape(Rectangle()) // Tappbare Fläche vergrößern
                    .allowsHitTesting(true)
                    .onTapGesture {
                        state.cancelBolus()
                    }

                    Text(
                        bolused + " " + NSLocalizedString("of", comment: "") + " " +
                            amount.formatted(.number.precision(.fractionLength(2))) +
                            NSLocalizedString(" U", comment: " ")
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dynamicSecondaryText)
                    .offset(y: -80)
                }
                .frame(width: 120, height: 120)
                .compositingGroup() // Verhindert Überlagerungsprobleme
            }
        }

        // HEADERVIEW Anfang

        private var pumpIconView: some View {
            state.showPumpIcon ? AnyView(pumpIconContent) : AnyView(EmptyView())
        }

        @ViewBuilder private var pumpIconContent: some View {
            ZStack {
                FillablePieSegment(
                    pieSegmentViewModel: connectionPieSegmentViewModel,
                    color: Color.white.opacity(0.5),
                    backgroundColor: .clear,
                    displayText: "",
                    symbolSize: 0,
                    symbol: "cross.vial",
                    animateProgress: false,
                    button3D: state.button3D,
                    fillFraction: 0.0,
                    symbolBackgroundColor: .dynamicIconBackground
                )
                .frame(width: 60, height: 60)

                Image(state.pumpIconRawValue)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .offset(y: 3)
                    .foregroundColor(.dynamicIconForeground)
                    .loopingGradientMask(isActive: state.isLooping)

                    .onTapGesture {
                        if state.pumpDisplayState != nil {
                            state.setupPump = true
                        }
                    }
            }
        }

        private var stackedLeftTopView: some View {
            VStack(spacing: 25) {
                tempRateView
                carbsView
                insulinView
            }
        }

        private var stackedRightTopView: some View {
            VStack(spacing: 0) {
                eventualBGView
                if state.showPumpIcon {
                    Spacer().frame(height: 32)
                    pumpIconContent
                    Spacer().frame(height: 32)
                } else {
                    Spacer().frame(height: 122)
                }
                loopView
            }
        }

        // Temp Basal Anfang
        private var tempRateView: some View {
            ZStack {
                VStack {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dynamicIconForeground)

                        if let tempRate = state.tempRate {
                            let rateString = tempRatenumberFormatter.string(from: tempRate as NSNumber) ?? "0"
                            let manualBasalString = state.apsManager.isManualTempBasal
                                ? NSLocalizedString(" Manual", comment: "Manual Temp basal")
                                : ""

                            HStack(spacing: 0) {
                                Text(rateString)
                                    .font(.system(size: 16))
                                    .foregroundColor(.dynamicSecondaryText)

                                Text("\u{00A0}U/hr") // Ein geschütztes Leerzeichen
                                    .font(.system(size: 14))
                                    .foregroundColor(.dynamicSecondaryText) +
                                    Text(manualBasalString)
                                    .font(.system(size: 14))
                                    .foregroundColor(.dynamicSecondaryText) }
                        } else {
                            Text("---")
                                .font(.system(size: 16))
                                .foregroundColor(.dynamicSecondaryText) }
                    }
                    .font(.timeSettingFont)
                    .background(
                        TimeEllipse(
                            button3D: state.button3D
                        )
                    )
                }
            }
        }

        // Temp Basal Ende

        // eventualBG Anfang

        private var eventualBGView: some View {
            ZStack {
                VStack {
                    HStack {
                        if let eventualBG = state.eventualBG {
                            HStack(spacing: 4) {
                                Text("⇢")
                                    .font(.system(size: 14))
                                    .foregroundColor(.dynamicSecondaryText)

                                let eventualBGValue = state.data.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)

                                if let formattedBG = fetchedTargetFormatter
                                    .string(from: eventualBGValue as NSNumber)
                                {
                                    Text(formattedBG)
                                        .font(.system(size: 16))
                                        .foregroundColor(.dynamicSecondaryText)
                                }

                                Text(state.data.units.rawValue)
                                    .font(.system(size: 14))
                                    .foregroundColor(.dynamicSecondaryText)
                                    .padding(.leading, -1)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Text("⇢")
                                    .font(.system(size: 16))
                                    .foregroundColor(.dynamicSecondaryText)

                                Text("---")
                                    .font(.system(size: 16))
                                    .foregroundColor(.dynamicSecondaryText)
                            }
                        }
                    }
                    .font(.timeSettingFont)
                    .background(
                        TimeEllipse(
                            button3D: state.button3D
                        )
                    )
                }
            }
        }

        // eventualBG Ende

        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
            // Basis-Höhe zentral definieren
            let baseHeight: CGFloat = display ? 170 : 233
            let safeTop = geo.safeAreaInsets.top

            // Gesamthöhe berechnen (inkl. Font-Größe)
            let totalHeight: CGFloat = fontSize < .extraExtraLarge
                ? baseHeight + safeTop
                : baseHeight + 10 + safeTop

            ZStack(alignment: .top) {
                HStack {
                    if !display {
                        stackedLeftTopView
                            .transition(.opacity)
                            .fixedSize()
                            .padding(.leading, 20)
                    }

                    VStack(spacing: 20) {
                        Group {
                            if let progress = state.bolusProgress, progress > 0 {
                                bolusProgressView()
                            } else {
                                glucoseView
                            }
                        }

                        if !display {
                            pumpView
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if !display {
                        stackedRightTopView
                            .transition(.opacity)
                            .fixedSize()
                            .padding(.trailing, 20)
                    }
                }
                .padding(.top, safeTop)

                // SageView
                if !display && (state.displayExpiration || state.displaySAGE) {
                    SageView(
                        recentGlucose: state.recentGlucose,
                        displayExpiration: state.displayExpiration,
                        displaySAGE: state.displaySAGE,
                        sensordays: state.sensorDays,
                        button3D: state.button3D
                    )
                    .position(x: geo.size.width - 63, y: safeTop + 85)
                    .transition(.opacity)
                }
            }
            .frame(height: totalHeight)
            .background(Color.dynamicBackground)
            .animation(.easeInOut(duration: 1.2), value: display)
        }

        // Head Ende

        // CarbView Anfang

        var carbsView: some View {
            HStack {
                if let settings = state.settingsManager {
                    let substance = Double(state.data.suggestion?.cob ?? 0)
                    let maxValue = max(Double(settings.preferences.maxCOB), 1)
                    let targetFill = CGFloat(substance / maxValue)

                    ZStack {
                        FillablePieSegment(
                            pieSegmentViewModel: carbsPieSegmentViewModel,
                            color: .orange,
                            backgroundColor: .clear,
                            displayText: {
                                if let loop = state.data.suggestion,
                                   let cob = loop.cob,
                                   let formatted = numberFormatter.string(from: cob as NSNumber)
                                {
                                    return "\(formatted)g"
                                } else {
                                    return "0g"
                                }
                            }(),
                            symbolSize: 0,
                            symbol: "cross.vial",
                            animateProgress: true,
                            button3D: state.button3D,
                            fillFraction: animatedFill,
                            symbolBackgroundColor: .dynamicIconBackground
                        )

                        Image(systemName: "apple.logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .foregroundColor(.dynamicIconForeground)
                            .verticalFillMask(
                                fillFraction: animatedFill,
                                gradient: LinearGradient(
                                    gradient: Gradient(colors: [.green, .orange, .yellow]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .offset(y: -1.5)
                    }
                    .onAppear {
                        withAnimation(.easeOut(duration: 5.6)) {
                            animatedFill = max(min(targetFill, 1.0), 0.0)
                        }
                    }
                    .onChange(of: targetFill) { _, newValue in
                        withAnimation(.easeInOut(duration: 10.6)) {
                            animatedFill = max(min(newValue, 1.0), 0.0)
                        }
                    }
                }
            }
        }

        // CarbView Ende

        // InsulinView Anfang

        var insulinView: some View {
            let substance = Double(state.data.suggestion?.iob ?? 0)
            // let substance = Double(state.data.iob ?? 0)
            let maxValue = max(Double(state.settingsManager?.preferences.maxIOB ?? 1), 1)
            let fraction = CGFloat(abs(substance) / maxValue)
            let fill = min(fraction, 1.0)
            let isNegative = substance < 0
            let pieColor: Color = isNegative ? .red : .blue

            return HStack {
                if let _ = state.settingsManager {
                    HStack {
                        ZStack {
                            FillablePieSegment(
                                pieSegmentViewModel: insulinPieSegmentViewModel,
                                color: pieColor,
                                backgroundColor: .clear,
                                displayText: "\(insulinnumberFormatter.string(from: (state.data.suggestion?.iob ?? 0) as NSNumber) ?? "0")U",
                                symbolSize: 0,
                                symbol: "cross.vial",
                                animateProgress: true,
                                button3D: state.button3D,
                                fillFraction: animatedInsulinFill,
                                symbolBackgroundColor: .dynamicIconBackground
                            )

                            Image(systemName: "drop.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 27, height: 27)
                                .foregroundColor(.dynamicIconForeground)
                                .verticalFillMask(
                                    fillFraction: animatedInsulinFill,
                                    gradient: isNegative
                                        ? LinearGradient(colors: [pieColor, pieColor], startPoint: .bottom, endPoint: .top)
                                        : LinearGradient(colors: [.blue, .blue], startPoint: .bottom, endPoint: .top)
                                )
                                .offset(y: -1.5)
                        }
                    }
                    .onAppear {
                        withAnimation(.easeOut(duration: 5.6)) {
                            animatedInsulinFill = fill
                        }
                    }
                    .onChange(of: state.data.suggestion?.iob) { _, _ in
                        let newSubstance = Double(state.data.suggestion?.iob ?? 0)
                        let newMax = max(Double(state.settingsManager?.preferences.maxIOB ?? 1), 1)
                        let newFraction = CGFloat(abs(newSubstance) / newMax)
                        let newFill = min(newFraction, 1.0)

                        withAnimation(.easeOut(duration: 10.6)) {
                            animatedInsulinFill = newFill
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

        // LoopView

        var loopView: some View {
            ZStack {
                if state.button3D {
                    Circle()
                        .fill(Color.dynamicIconBackground)
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.dynamicBottomShadow.opacity(0.3), radius: 5, x: 3, y: 3)

                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .dynamicTopGlow.opacity(0.9),
                                    .dynamicTopGlow.opacity(0.6),
                                    Color.clear,
                                    .dynamicBottomShadow.opacity(0.3),
                                    .dynamicBottomShadow
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 50, height: 50)
                } else {
                    Circle()
                        .fill(Color.dynamicIconBackground)
                        .frame(width: 50, height: 50)
                }

                LoopView(
                    suggestion: $state.data.suggestion,
                    enactedSuggestion: $state.enactedSuggestion,
                    closedLoop: $state.closedLoop,
                    timerDate: $state.data.timerDate,
                    isLooping: $state.isLooping,
                    lastLoopDate: $state.lastLoopDate,
                    manualTempBasal: $state.manualTempBasal,
                    backgroundColor: backgroundColor
                )
                .onTapGesture {
                    state.isStatusPopupPresented.toggle()
                }
                .onLongPressGesture {
                    let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                    impactHeavy.impactOccurred()
                    state.runLoop()
                }
            }
        }

        // Top Bars

        // danaBarMax

        @ViewBuilder var danaBarMax: some View {
            if state.danaBar {
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        insulinAgeView.frame(width: 60)
                        cannulaAgeView.frame(width: 60)
                        batteryAgeView.frame(width: 60)
                        BluetoothConnectionView.frame(width: 60)
                    }
                }
            } else {
                EmptyView()
            }
        }

        // Top Bar Modules Start

        private var reservoirView: some View {
            Group {
                if let reservoir = state.reservoirLevel {
                    let maxValue = Decimal(300)
                    let reservoirDecimal = Decimal(reservoir)
                    let fractionDecimal = reservoirDecimal / maxValue
                    let fill = max(min(CGFloat(NSDecimalNumber(decimal: fractionDecimal).doubleValue), 1.0), 0.0)

                    let reservoirColor: Color = {
                        if reservoir < 20 {
                            return .dynamicColorRed
                        } else if reservoir < 50 {
                            return .dynamicColorYellow
                        } else {
                            return .dynamicIconForeground.opacity(0.5)
                        }
                    }()

                    let displayText: String = {
                        if reservoir == 0 {
                            return "--"
                        } else {
                            let concentrationValue = Decimal(concentration.last?.concentration ?? 1.0)
                            let adjustedReservoir = reservoirDecimal * concentrationValue
                            return (reservoirFormatter.string(from: adjustedReservoir as NSNumber) ?? "") + "U"
                        }
                    }()

                    // let shouldBlink = reservoirColor == .red
                    ZStack {
                        FillablePieSegment(
                            pieSegmentViewModel: reservoirPieSegmentViewModel,
                            color: reservoirColor,
                            backgroundColor: .clear,
                            displayText: displayText,
                            symbolSize: 21,
                            symbol: "cross.vial.fill",
                            animateProgress: false,
                            button3D: state.button3D,
                            fillFraction: fill,
                            symbolColor: reservoirColor
                        )
                        .frame(width: 60, height: 60)
                        // .modifier(BlinkingModifier(shouldBlink: shouldBlink))
                    }
                }
            }
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
        }

        private var insulinAgeView: some View {
            Group {
                let insulinDisplayText: String = {
                    guard let insulinHours = state.insulinHours,
                          let insulinAgeOption = InsulinAgeOption(rawValue: state.insulinAgeOption)
                    else {
                        return "--"
                    }

                    let remainingHours = max(insulinAgeOption.maxInsulinAge - insulinHours, 0)
                    let totalRemainingMinutes = Int(remainingHours * 60)
                    let days = totalRemainingMinutes / (24 * 60)
                    let hours = (totalRemainingMinutes % (24 * 60)) / 60
                    let minutes = totalRemainingMinutes % 60

                    if days >= 1 {
                        return "\(days)d\(hours)h"
                    } else if hours >= 1 {
                        return "\(hours)h\(minutes)m"
                    } else {
                        return "\(minutes)m"
                    }
                }()

                let insulinFraction: CGFloat = {
                    guard let insulinHours = state.insulinHours,
                          let insulinAgeOption = InsulinAgeOption(rawValue: state.insulinAgeOption)
                    else {
                        return 0.0
                    }
                    let remainingHours = insulinAgeOption.maxInsulinAge - insulinHours
                    return remainingHours <= 1 ? 1.0 : CGFloat(min(max(
                        remainingHours / insulinAgeOption.maxInsulinAge,
                        0.0
                    ), 1.0))
                }()

                let insulinColor: Color = {
                    guard let insulinHours = state.insulinHours,
                          let insulinAgeOption = InsulinAgeOption(rawValue: state.insulinAgeOption)
                    else {
                        return .clear
                    }

                    let maxInsulinAge = insulinAgeOption.maxInsulinAge
                    let remainingHours = maxInsulinAge - CGFloat(insulinHours)

                    return colorForRemainingHours(remainingHours)
                }()

                // let shouldBlink = insulinColor == .red

                ZStack {
                    FillablePieSegment(
                        pieSegmentViewModel: insulinAgePieSegmentViewModel,
                        color: .white,
                        backgroundColor: .clear,
                        displayText: insulinDisplayText,
                        symbolSize: 25,
                        symbol: "cross.vial",
                        animateProgress: true,
                        button3D: state.button3D,
                        fillFraction: insulinFraction,
                        symbolBackgroundColor: Color.dynamicIconBackground,
                        symbolColor: insulinColor
                    )
                    .frame(width: 60, height: 60)
                    // .modifier(BlinkingModifier(shouldBlink: shouldBlink))
                }
            }
        }

        struct InsulinCatheterSymbol: View {
            var color: Color // Farbe von außen übergeben
            var baseSize: CGFloat = 40 // Basisgröße

            var body: some View {
                ZStack {
                    Image(systemName: "hockey.puck")
                        .resizable()
                        .foregroundStyle(color)
                        .frame(width: 22, height: 12)
                        .offset(x: 0, y: -1)

                    Rectangle()
                        .frame(width: 2, height: 7)
                        .foregroundStyle(color)
                        .offset(x: 0, y: 8)
                }
                .frame(width: baseSize, height: baseSize)
            }
        }

        private var cannulaAgeView: some View {
            Group {
                let cannulaDisplayText: String = {
                    guard let cannulaHours = state.cannulaHours,
                          let cannulaAgeOption = CannulaAgeOption(rawValue: state.cannulaAgeOption)
                    else {
                        return "--"
                    }

                    let remainingHours = max(cannulaAgeOption.maxCannulaAge - cannulaHours, 0)
                    let totalRemainingMinutes = Int(remainingHours * 60)
                    let days = totalRemainingMinutes / (24 * 60)
                    let hours = (totalRemainingMinutes % (24 * 60)) / 60
                    let minutes = totalRemainingMinutes % 60

                    if days >= 1 {
                        return "\(days)d\(hours)h"
                    } else if hours >= 1 {
                        return "\(hours)h\(minutes)m"
                    } else {
                        return "\(minutes)m"
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
                        if remainingHours <= 1 {
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
                       let cannulaAgeOption = CannulaAgeOption(rawValue: state.cannulaAgeOption)
                    {
                        let maxCannulaAge = cannulaAgeOption.maxCannulaAge
                        let remainingHours = maxCannulaAge - CGFloat(cannulaHours)
                        return colorForRemainingHours(remainingHours)
                    } else {
                        return .clear
                    }

                }()

                // let shouldBlink = cannulaColor == .red

                ZStack {
                    FillablePieSegment(
                        pieSegmentViewModel: cannulaPieSegmentViewModel,
                        color: .white,
                        backgroundColor: .clear,
                        displayText: cannulaDisplayText,
                        symbolSize: 0,
                        symbol: "cross.vial",
                        animateProgress: true,
                        button3D: state.button3D,
                        fillFraction: cannulaFraction,
                        symbolBackgroundColor: Color.dynamicIconBackground,
                        symbolColor: cannulaColor
                    )
                    .frame(width: 60, height: 60)

                    InsulinCatheterSymbol(color: cannulaColor)
                        .offset(y: -1.5)
                    // .modifier(BlinkingModifier(shouldBlink: shouldBlink))
                }
            }
        }

        private var batteryAgeView: some View {
            Group {
                var batteryAgeColor: Color {
                    if let batteryHours = state.batteryHours {
                        switch batteryHours {
                        case 192...: // >8 Tage = Rot
                            return Color.dynamicIconForeground.opacity(0.5)
                        case 168 ..< 192: // 7-8 Tage = Gelb
                            return Color.dynamicIconForeground.opacity(0.5)
                        default: // <7 Tage = Weiß/Transparent
                            return Color.dynamicIconForeground.opacity(0.5)
                        }
                    } else {
                        return .dynamicIconForeground.opacity(0.5)
                    }
                }

                let batteryAgeText: String = {
                    if let batteryHours = state.batteryHours {
                        let totalMinutes = Int(batteryHours * 60)
                        if totalMinutes < 60 {
                            return "\(totalMinutes)min"
                        } else {
                            let days = totalMinutes / (24 * 60)
                            let hours = (totalMinutes % (24 * 60)) / 60
                            return days > 0 ? "\(days)d\(hours)h" : "\(hours)h"
                        }
                    } else {
                        return "--"
                    }
                }()

                ZStack {
                    FillablePieSegment(
                        pieSegmentViewModel: batteryAgePieSegmentViewModel,
                        color: batteryAgeColor,
                        backgroundColor: .clear,
                        displayText: batteryAgeText,
                        symbolSize: 25,
                        symbol: "battery.50percent",
                        animateProgress: false,
                        button3D: state.button3D,
                        fillFraction: 1.0,
                        symbolRotation: -90,
                        symbolBackgroundColor: Color.dynamicIconBackground,
                        symbolColor: Color.dynamicIconForeground
                    )
                    .frame(width: 60, height: 60)

                    Image(systemName: "clock.fill")
                        .resizable()
                        // .rotationEffect(.degrees(-50))
                        .foregroundColor(Color.dynamicIconForeground)
                        .frame(width: 15, height: 15)
                        .offset(x: 13, y: -17)
                }
            }
        }

        private var BluetoothConnectionView: some View {
            Group {
                let connectionFraction: CGFloat = state.isConnected ? 1.0 : 0.0
                let displayText: String = state.isConnected ? "ON" : "OFF"

                HStack {
                    ZStack {
                        FillablePieSegment(
                            pieSegmentViewModel: connectionPieSegmentViewModel,
                            color: Color.dynamicColorBlue,
                            backgroundColor: .clear,
                            displayText: displayText,
                            symbolSize: 25,
                            symbol: "dot.radiowaves.left.and.right",
                            animateProgress: true,
                            button3D: state.button3D,
                            fillFraction: connectionFraction,
                            symbolBackgroundColor: Color.dynamicIconBackground,
                            symbolColor: Color.dynamicIconForeground
                        )
                        .frame(width: 60, height: 60)
                    }
                    .offset(y: -2)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: state.isConnected)
        }

        // TopBar Max Modules Ende

        // MARK: - Helper-Views for Standard 1 und DanaBar Anfang

        private func formatTime(_ hours: Double) -> String {
            let totalMinutes = Int(hours * 60)
            let days = totalMinutes / (24 * 60)
            let hours = (totalMinutes % (24 * 60)) / 60
            let minutes = totalMinutes % 60

            if days >= 1 {
                return "\(days)d\(hours)h"
            } else if hours >= 1 {
                return "\(hours)h"
            } else {
                return "\(minutes)m"
            }
        }

        func colorForRemainingHours(_ remainingHours: CGFloat) -> Color {
            switch remainingHours {
            case ..<2:
                return Color.dynamicColorRed
            case ..<6:
                return Color.dynamicColorYellow
            default:
                return Color.dynamicIconForeground
            }
        }

        func colorForRemainingMinutes(_ remainingMinutes: CGFloat) -> Color {
            switch remainingMinutes {
            case ..<120:
                return Color.dynamicColorRed
            case ..<360:
                return Color.dynamicColorYellow
            default:
                return Color.dynamicIconForeground
            }
        }

        func startTimer() {
            timer?.invalidate() // Falls ein vorheriger Timer existiert, wird er gestoppt
            timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
                state.specialDanaKitFunction()
                // Nach 15 Sekunden auf 60 Sekunden Intervall wechseln
                if timerInterval == 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                        timerInterval = 60
                        startTimer()
                    }
                }
            }
        }

        // MARK: - Helper-Views for DanaBar Ende

        // TopBars Ende

        var mainChart: some View {
            Group {
                ZStack {
                    if state.button3D {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicIconBackground)
                            .shadow(color: .dynamicBottomShadow, radius: 3, x: 2, y: 3)
                    }

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicIconBackground)

                    ZStack {
                        if state.animatedBackground {
                            SpriteView(scene: spriteScene, options: [.allowsTransparency])
                                .ignoresSafeArea()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        }
                        MainChartView(data: state.data, triggerUpdate: $triggerUpdate)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 5)
            }
            .modal(for: .dataTable, from: self)
        }

        var chart: some View {
            VStack(spacing: 0) {
                if state.danaBar {
                    danaBarMax
                        .padding(.vertical, 10)
                        .padding(.top, 10)
                }
                mainChart
                    .padding(.top, 35)
                bottomBar
                    .padding(.top, 20)
                    .frame(width: UIScreen.main.bounds.width)
            }
            .frame(minHeight: UIScreen.main.bounds.height / 1.81) // Je größer der Wert, desto kleiner der mainChart
        }

        // BottomInfoBar Start
        var bottomBar: some View {
            Group {
                if state.timeSettings {
                    HStack(spacing: 15) {
                        // Linker Stack
                        Spacer()
                        HStack {
                            isfView
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 0)
                        .frame(maxWidth: 100, alignment: .leading)

                        Spacer()

                        // Mittlerer Stack
                        HStack(spacing: 0) {
                            timeSetting
                            // timeIntervalButtons
                        }

                        Spacer()

                        // Rechter Stack - TDD
                        HStack {
                            tddView
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, 25)
                        .frame(maxWidth: 100, alignment: .trailing)

                        Spacer()
                    }
                    .padding(.top, 10)

                } else {
                    EmptyView()
                }
            }
        }

        private var sensitivityPercentage: String {
            let sensitivityValue = (state.data.suggestion?.sensitivityRatio ?? 1) as NSDecimalNumber
            return percentageFormatter.string(from: NSNumber(value: sensitivityValue.doubleValue * 100)) ?? "0"
        }

        private var isfView: some View {
            ZStack {
                HStack {
                    HStack {
                        Text("ISF")
                            .font(.system(size: 14))
                            .foregroundColor(.dynamicSecondaryText)

                        Text("\(sensitivityPercentage)%")
                            .foregroundColor(.dynamicSecondaryText)
                            .font(.timeSettingFont)
                    }
                    .background(
                        TimeEllipse(
                            button3D: state.button3D
                        )
                    )
                    .onTapGesture {
                        if state.autoisf {
                            displayAutoHistory.toggle()
                        } else {
                            displayDynamicHistory.toggle()
                        }
                    }
                }
                .offset(x: 30)
            }
        }

        var timeSetting: some View {
            let string = "\(state.hours) " + NSLocalizedString("hours", comment: "") + "   "
            return Menu(string) {
                Button("3 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 3 })
                Button("6 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 6 })
                Button("9 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 9 })
                Button("12 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 12 })
                Button("24 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 24 })
            }
            .foregroundColor(.dynamicSecondaryText)
            .font(.timeSettingFont)
            .padding(.vertical, 15)
            .background(
                TimeEllipse(
                    button3D: state.button3D
                )
            ) }

        private var tddView: some View {
            HStack(spacing: 4) {
                Image(systemName: "circle.slash")
                    .font(.system(size: 13))
                    .foregroundColor(.dynamicSecondaryText)

                Text("\(targetFormatter.string(from: state.tddActualAverage as NSNumber) ?? "0") U")
                    .foregroundColor(.dynamicSecondaryText)
                    .lineLimit(1)
                    .fixedSize()
            }
            .font(.timeSettingFont)
            .foregroundColor(.dynamicSecondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                TimeEllipse(
                    button3D: state.button3D
                )
            )
            .overlay(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: TextWidthKey.self, value: geometry.size.width)
                }
            )
            .onPreferenceChange(TextWidthKey.self) { _ in
                // Möglichkeit die Breite für weitere Anpassungen  zu verwenden
            }
        }

        // BottomInfoBar End

        // ButtonPanel Start
        private static let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)

        // buttonWithCircle Funktion

        // buttonWithCircle Funktion
        @ViewBuilder private func buttonWithCircle(
            iconName: String,
            isSFSymbol: Bool = true,
            symbolRenderingMode: SymbolRenderingMode? = .hierarchical,
            colors: [Color] = [.white],
            circleColor _: Color,
            gradient: LinearGradient? = nil,
            feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
                generator.impactOccurred()
                action()
            }) {
                ZStack {
                    if state.button3D {
                        Circle()
                            .fill(Color.dynamicIconBackground)
                            .frame(width: 50, height: 50)
                            .shadow(color: Color.dynamicBottomShadow.opacity(0.3), radius: 5, x: 3, y: 3)

                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .dynamicTopGlow.opacity(0.9),
                                        .dynamicTopGlow.opacity(0.6),
                                        Color.clear,
                                        .dynamicBottomShadow.opacity(0.3),
                                        .dynamicBottomShadow
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .frame(width: 50, height: 50)
                    } else {
                        Circle()
                            .fill(Color.dynamicIconBackground)
                            .frame(width: 50, height: 50)
                    }

                    // SF Symbol Darstellung mit direkter Farbanwendung
                    if isSFSymbol {
                        Group {
                            let symbolImage = Image(systemName: iconName)
                                .symbolRenderingMode(symbolRenderingMode)
                                .font(.system(size: 25, weight: .medium))
                                .frame(width: 40, height: 40)

                            if let gradient = gradient {
                                symbolImage
                                    .foregroundColor(.white.opacity(0.0)) // Basis transparent
                                    .overlay(
                                        gradient
                                            .mask(symbolImage)
                                    )
                            } else {
                                switch colors.count {
                                case 1:
                                    symbolImage.foregroundStyle(colors[0])
                                case 2:
                                    symbolImage.foregroundStyle(colors[0], colors[1])
                                case 3:
                                    symbolImage.foregroundStyle(colors[0], colors[1], colors[2])
                                default:
                                    symbolImage.foregroundStyle(colors.first ?? .white)
                                }
                            }
                        }
                        .font(.system(size: 25, weight: .medium))
                        .frame(width: 40, height: 40)
                    }
                    // Fallback für Asset-Icons
                    else {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    }
                }
            }
            .buttonStyle(.borderless)
            .contentShape(Circle())
        }

        struct bubbleView<Content: View>: View {
            let content: Content

            init(@ViewBuilder content: () -> Content) {
                self.content = content()
            }

            var body: some View {
                VStack(spacing: 0) {
                    content
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.dynamicIconBackground)
                        )
                        .foregroundColor(.dynamicIconForeground)
                        .font(.caption)

                    Triangle()
                        .fill(Color.dynamicIconBackground)
                        .frame(width: 20, height: 12)
                        .offset(y: 2)
                }
            }
        }

        struct Triangle: Shape {
            func path(in rect: CGRect) -> Path {
                var path = Path()

                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY),
                    control: CGPoint(x: rect.midX, y: rect.maxY - 3)
                )

                path.closeSubpath()
                return path
            }
        }

        @State private var showProfileBubble = false
        @State private var showTargetBubble = false

        @ViewBuilder private func buttonPanel(_ geo: GeometryProxy) -> some View {
            ZStack {
                /*  backgroundColor
                 .frame(height: 60 + geo.safeAreaInsets.bottom)*/

                let isOverride = fetchedPercent.first?.enabled ?? false
                let isTarget = (state.tempTarget != nil)
                let buttonsPresence: [Bool] = [
                    state.carbButton,
                    true, // IOB Button immer da
                    state.allowManualTemp,
                    state.profileButton,
                    state.useTargetButton,
                    true, // UI/UX Button immer da
                    true // Settings Button immer da
                ]

                let totalButtons = buttonsPresence.filter { $0 }.count
                // sichere Indizes (0-basierend unter den sichtbaren Buttons)
                let indexOfProfileButton = max(0, buttonsPresence.prefix(4).filter { $0 }.count - 1)
                let indexOfTargetButton = max(0, buttonsPresence.prefix(5).filter { $0 }.count - 1)

                ZStack {
                    HStack {
                        // Carb Button
                        if state.carbButton {
                            ZStack {
                                buttonWithCircle(
                                    iconName: "apple.logo",
                                    symbolRenderingMode: .palette,
                                    colors: [.dynamicIconForeground],
                                    circleColor: Color.black.opacity(1.0)
                                    /*  gradient: LinearGradient(
                                         gradient: Gradient(colors: [
                                             .green.opacity(0.7),
                                             .yellow.opacity(0.7),
                                             .orange.opacity(0.7)
                                         ]),
                                         startPoint: .bottom,
                                         endPoint: .top
                                     )*/
                                ) {
                                    state.showModal(for: .addCarbs(editMode: false, override: false))
                                }

                                if let carbsReq = state.carbsRequired {
                                    Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(4)
                                        .background(Capsule().fill(Color.red.opacity(0.7)))
                                        .offset(x: 20, y: 10)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // IOB Button
                        buttonWithCircle(
                            iconName: "drop.fill",
                            colors: [.dynamicIconForeground],
                            circleColor: Color.black.opacity(1.0)
                        ) {
                            (state.bolusProgress != nil) ? showBolusActiveAlert = true :
                                state.showModal(for: .bolus(
                                    waitForSuggestion: state.useCalc ? true : false,
                                    fetch: false
                                ))
                        }
                        .frame(maxWidth: .infinity)

                        // Manual Temp Basal Button
                        if state.allowManualTemp {
                            buttonWithCircle(
                                iconName: "speedometer",
                                symbolRenderingMode: .monochrome,
                                colors: [.dynamicIconForeground],
                                circleColor: Color.black.opacity(1.0)
                            ) {
                                state.showModal(for: .manualTempBasal)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Profile Button
                        if state.profileButton {
                            buttonWithCircle(
                                iconName: isOverride ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle",
                                symbolRenderingMode: .palette,
                                // colors: [.purple.opacity(0.7), isOverride ? .green.opacity(0.7) : .gray.opacity(0.7)],
                                colors: [.dynamicIconForeground, isOverride ? .red.opacity(0.7) : .clear],
                                circleColor: Color.black.opacity(1.0)
                            )
                                {
                                    // Leere Aktion: Tap / LongPress werden per Gesten gesteuert
                                }
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.5)
                                        .onEnded { _ in
                                            withAnimation {
                                                showProfileBubble = true
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                withAnimation {
                                                    showProfileBubble = false
                                                }
                                            }
                                        }
                                )
                                .simultaneousGesture(
                                    TapGesture()
                                        .onEnded {
                                            if isOverride {
                                                showCancelAlert.toggle()
                                            } else {
                                                state.showModal(for: .overrideProfilesConfig)
                                            }
                                        }
                                )
                                .frame(maxWidth: .infinity)
                        }

                        // Target Button
                        if state.useTargetButton {
                            buttonWithCircle(
                                iconName: "scope",
                                symbolRenderingMode: .palette,
                                /* colors: [isTarget ? .red.opacity(0.7) : .white.opacity(0.7), .clear], */
                                colors: [isTarget ? .red.opacity(0.7) : .dynamicIconForeground, .clear],
                                circleColor: Color.black.opacity(1.0)
                            ) {
                                // Leere Aktion: Tap / LongPress werden per Gesten gesteuert
                            }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        withAnimation {
                                            showTargetBubble = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation {
                                                showTargetBubble = false
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded {
                                        if isTarget {
                                            showCancelTTAlert.toggle()
                                        } else {
                                            state.showModal(for: .addTempTarget)
                                        }
                                    }
                            )
                            .frame(maxWidth: .infinity)
                        }

                        // UI/UX Button
                        buttonWithCircle(
                            iconName: "square.3.layers.3d",
                            symbolRenderingMode: .palette,
                            /* colors: [.purple.opacity(0.7), .blue.opacity(0.7)],*/
                            colors: [.dynamicIconForeground],
                            circleColor: Color.black.opacity(1.0)
                        ) {
                            state.showModal(for: .statisticsConfig)
                        }
                        .frame(maxWidth: .infinity)

                        // Settings Button
                        buttonWithCircle(
                            iconName: "gearshape.fill",
                            symbolRenderingMode: .hierarchical,
                            colors: [.dynamicIconForeground],
                            circleColor: Color.black.opacity(1.0)
                        ) {
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
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 5)
                    .padding(.bottom, 15)

                    // Profile Bubble Anzeige
                    if showProfileBubble && state.profileButton {
                        bubbleView {
                            if let overrideString = overrideString {
                                Text(overrideString)
                                    .foregroundStyle(Color.dynamicPrimaryText)
                            } else {
                                Text("No Profile Override")
                                    .foregroundStyle(Color.dynamicPrimaryText)
                            }
                        }
                        .frame(width: 350)
                        .offset(
                            x: -geo.size.width / 2 +
                                (geo.size.width / CGFloat(totalButtons)) * CGFloat(indexOfProfileButton) +
                                (geo.size.width / CGFloat(totalButtons) / 2),
                            y: -55
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Target Bubble Anzeige
                    if showTargetBubble && state.useTargetButton {
                        bubbleView {
                            if let tempTargetString = tempTargetString {
                                Text(tempTargetString)
                                    .foregroundStyle(Color.dynamicPrimaryText)
                            } else {
                                Text("No Temp Target")
                                    .foregroundStyle(Color.dynamicPrimaryText)
                            }
                        }
                        .frame(width: 350)
                        .offset(
                            x: -geo.size.width / 2 +
                                (geo.size.width / CGFloat(totalButtons)) * CGFloat(indexOfTargetButton) +
                                (geo.size.width / CGFloat(totalButtons) / 2),
                            y: -55
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
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

        var overrideString: String? {
            guard let override = fetchedPercent.first, override.enabled else {
                return nil
            }

            if override.isPreset {
                let profile = fetchedProfiles.first(where: { $0.id == override.id })
                if let currentProfile = profile {
                    if let name = currentProfile.name, name != "EMPTY", name.nonEmpty != nil, name != "",
                       name != "\u{0022}\u{0022}"
                    {
                        if name.count > 15 {
                            let shortened = name.prefix(15)
                            return String(shortened)
                        } else {
                            return name
                        }
                    }
                }
                return "📉" // Fallback wenn kein Profilname gefunden wird
            } else if override.percentage != 100 {
                return "\(override.percentage.formatted()) %"
            } else if override.smbIsOff, !override.smbIsAlwaysOff {
                return "No SMB"
            } else if override.smbIsOff {
                return "SMB Paused"
            } else {
                return "Override"
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
                            } // else { Text("📉") }
                            else {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .foregroundColor(.red)
                                    .offset(y: -1)
                            }
                        } else if override.percentage != 100 {
                            Text((tirFormatter.string(from: override.percentage as NSNumber) ?? "") + " %").font(.statusFont)
                                .foregroundStyle(.secondary)
                        } else if override.smbIsOff, !override.smbIsAlwaysOff {
                            Text("No ").font(.statusFont).foregroundStyle(.secondary)
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

        // ButtonPanel End

        var DayView: some View {
            Group {
                // Glucose Chart Header
                if !state.skipGlucoseChart {
                    ZStack {
                        if state.button3D {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicIconBackground)
                                .shadow(color: .dynamicBottomShadow, radius: 3, x: 2, y: 3)
                        }
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicIconBackground)

                        glucoseHeaderView()
                            .padding(.top, 8)
                            .padding(.bottom, 10)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 10)
                }

                // Preview
                ZStack {
                    if state.button3D {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicIconBackground)
                            .shadow(color: .dynamicBottomShadow, radius: 3, x: 2, y: 3) }
                    preview
                        .padding(10)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 10)

                // Loop Preview
                ZStack {
                    if state.button3D {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicIconBackground)
                            .shadow(color: .dynamicBottomShadow, radius: 3, x: 2, y: 3) }
                    loopPreview
                        .padding(10)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 10)

                if !state.iobData.isEmpty {
                    ZStack {
                        if state.button3D {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicIconBackground)
                                .shadow(color: .dynamicBottomShadow, radius: 3, x: 2, y: 3) }
                        activeCOBView
                            .padding(.bottom, 20)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 10)

                    ZStack {
                        if state.button3D {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicIconBackground)
                                .shadow(color: .dynamicBottomShadow, radius: 3, x: 2, y: 3) }
                        activeIOBView
                            .padding(.bottom, 20)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 10)
                }
            }
            .padding(.horizontal, 15)
        }

        @ViewBuilder private func glucoseHeaderView() -> some View {
            VStack {
                glucosePreview
            }
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
                    AxisGridLine().foregroundStyle(Color.dynamicSecondaryText)
                    AxisTick().foregroundStyle(Color.dynamicSecondaryText)
                    AxisValueLabel().foregroundStyle(Color.dynamicSecondaryText)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine().foregroundStyle(Color.dynamicSecondaryText)
                    AxisTick().foregroundStyle(Color.dynamicSecondaryText)
                    AxisValueLabel().foregroundStyle(Color.dynamicSecondaryText)
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
            .padding(.horizontal, 0)
            .padding(.top, 15)
            .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.large)
        }

        var preview: some View {
            Rectangle()
                .fill(Color.dynamicIconBackground)
                .frame(minHeight: 200)
                .overlay {
                    PreviewChart(
                        readings: $state.readings,
                        lowLimit: $state.data.lowGlucose,
                        highLimit: $state.data.highGlucose
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 10)
                .onTapGesture {
                    state.showModal(for: .statistics)
                }
        }

        var loopPreview: some View {
            Rectangle()
                .fill(Color.dynamicIconBackground)
                .frame(minHeight: 160)
                .overlay {
                    LoopsView(loopStatistics: $state.loopStatistics)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 10)
                .onTapGesture {
                    state.showModal(for: .statistics)
                }
        }

        var activeIOBView: some View {
            Rectangle()
                .fill(Color.dynamicIconBackground)
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
                .foregroundStyle(Color.dynamicSecondaryText)
        }

        var activeCOBView: some View {
            Rectangle()
                .fill(Color.dynamicIconBackground)
                .frame(minHeight: 230)
                .overlay {
                    ActiveCOBView(data: $state.iobData)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .foregroundStyle(Color.dynamicSecondaryText)
                .padding(.horizontal, 10)
        }

        var body: some View {
            GeometryReader { geo in
                if onboarded.first?.firstRun ?? true, let openAPSSettings = state.openAPSSettings {
                    importResetSettingsView(settings: openAPSSettings)
                } else {
                    VStack(spacing: 0) {
                        headerView(geo).padding(.top, 10)
                        ScrollView {
                            ScrollViewReader { _ in
                                LazyVStack {
                                    chart.padding(.top, 10).padding(.bottom, 30)
                                    DayView.padding(.bottom, 30).padding(.top, 30)
                                }
                                .background(
                                    GeometryReader { proxy in
                                        let scrollPosition = proxy.frame(in: .named("HomeScrollView")).minY
                                        Color.clear
                                            .onChange(of: scrollPosition) { _, newValue in
                                                let yThreshold: CGFloat = -550
                                                if newValue < yThreshold {
                                                    withAnimation(.easeOut(duration: 0.1)) { display = true }
                                                } else {
                                                    withAnimation(.easeOut(duration: 0.1)) { display = false }
                                                }
                                            }
                                    }
                                )
                            }
                        }
                        .coordinateSpace(name: "HomeScrollView")
                        buttonPanel(geo)
                            .frame(height: 60)
                    }
                    .background(Color.dynamicBackground)
                    .ignoresSafeArea(edges: .vertical)
                    .onAppear {
                        startProgress()
                        startTimer() // Timer starten
                    }
                    .onDisappear {
                        timer?.invalidate() // Timer stoppen
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
                        RootView.heavyFeedback.prepare()
                    }
                }
            }
        }

        var popup: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusTitle).font(.suggestionHeadline).foregroundStyle(Color.dynamicPrimaryText)
                    .padding(.bottom, 4)
                if let suggestion = state.data.suggestion {
                    TagCloudView(tags: suggestion.reasonParts).animation(.none, value: false)

                    Text(suggestion.reasonConclusion.capitalizingFirstLetter()).font(.suggestionSmallParts)
                        .foregroundStyle(Color.dynamicPrimaryText)
                } else {
                    Text("No sugestion found").font(.suggestionHeadline).foregroundStyle(Color.dynamicPrimaryText)
                }
                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    Text(NSLocalizedString("Error at", comment: "") + " " + dateFormatter.string(from: date))
                        .foregroundStyle(Color.dynamicPrimaryText)
                        .font(.suggestionError)
                        .padding(.bottom, 4)
                        .padding(.top, 8)
                    Text(errorMessage).font(.suggestionError).fontWeight(.semibold).foregroundColor(.orange)
                } else if let suggestion = state.data.suggestion, (suggestion.bg ?? 100) == 400 {
                    Text("Invalid CGM reading (HIGH).").font(.suggestionError).bold().foregroundColor(.loopRed)
                        .padding(.top, 8)
                    Text("SMBs and High Temps Disabled.").font(.suggestionParts).foregroundStyle(Color.dynamicPrimaryText)
                        .padding(.bottom, 4)
                }
            }
            .padding()
            .background(Color.dynamicBackground)
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
