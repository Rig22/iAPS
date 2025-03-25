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
            formatter.allowsFloats = true
            if let increment = state.settingsManager?.preferences.bolusIncrement {
                formatter.maximumFractionDigits = increment > 0.05 ? 1 : 2
                formatter.minimumFractionDigits = increment > 0.05 ? 1 : 2
                formatter.roundingIncrement = Double(increment) as NSNumber
            } else {
                formatter.maximumFractionDigits = 2
                formatter.minimumFractionDigits = 2
                formatter.roundingIncrement = 0.05
            }
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

        struct TimeEllipse: View {
            let characters: Int
            var button3D: Bool = false

            var body: some View {
                ZStack {
                    if button3D {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.darkGray.opacity(0.5))
                            .frame(width: CGFloat(characters * 7), height: 25)
                            .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)

                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1),
                                        Color.gray.opacity(0.1),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.black.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: CGFloat(characters * 7), height: 25)
                    } else {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.darkGray.opacity(0.5))
                            .frame(width: CGFloat(characters * 7), height: 25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white, lineWidth: 0)
                            )
                    }
                }
            }
        }

        struct TimeEllipseLegend: View {
            let characters: Int
            var button3D: Bool = false

            var body: some View {
                ZStack {
                    if button3D {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.darkGray.opacity(0.5))
                            .frame(width: CGFloat(characters * 14), height: 30)
                            .shadow(color: Color.black.opacity(0.4), radius: 3, x: 3, y: 3)

                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1),
                                        Color.gray.opacity(0.1),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.2),
                                        Color.black.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: CGFloat(characters * 14), height: 30)
                    } else {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.darkGray.opacity(0.5))
                            .frame(width: CGFloat(characters * 14), height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white, lineWidth: 0)
                            )
                    }
                }
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

            return ZStack {
                if state.button3D {
                    Circle()
                        .fill(Color.darkGray.opacity(0.5))
                        .frame(width: 110, height: 110)
                        .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)

                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.4),
                                    Color.clear,
                                    Color.black.opacity(0.3),
                                    Color.black.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 110, height: 110)
                } else {
                    Circle()
                        .fill(Color.darkGray.opacity(0.5))
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 0)
                        )
                }

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
                    displayExpiration: $state.displayExpiration, cgm: $state.cgm, sensordays: $state.sensorDays
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
        }

        /*  private func startProgress() {
             Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                 withAnimation(Animation.linear(duration: 0.02)) {
                     progress += 0.01
                 }
                 if progress >= 1.0 {
                     timer.invalidate()
                 }
             }
         }*/

        private func startProgress() {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                withAnimation(Animation.interpolatingSpring(stiffness: 50, damping: 10)) {
                    progress = min(progress + 0.02, 1.0) // Fortschritt begrenzen
                }
                if progress >= 1.0 {
                    timer.invalidate()
                }
            }
        }

        @ViewBuilder private func bolusProgressViewSelector() -> some View {
            if let progress = state.bolusProgress, let amount = state.bolusAmount, progress > 0 {
                if let bolusOption = BolusProgressViewOption(rawValue: state.bolusProgressViewOption) {
                    switch bolusOption {
                    case .bolusview1:
                        bolusProgressView(progress: progress, amount: amount)
                    case .bolusview2:
                        bolusProgressView2()
                    }
                } else {
                    glucoseAndLoopView()
                }
            } else {
                glucoseAndLoopView()
            }
        }

        // Progressbar by Rig22
        public struct CircularProgressViewStyle: ProgressViewStyle {
            public func makeBody(configuration: Configuration) -> some View {
                let progress = CGFloat(configuration.fractionCompleted ?? 0)

                ZStack {
                    Circle()
                        .stroke(lineWidth: 6)
                        .opacity(0.3)
                        .foregroundColor(Color.rig22Background)

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
                .frame(width: 110, height: 110)
            }
        }

        // Bolus Progress View 1

        @ViewBuilder private func bolusProgressView(progress: Decimal, amount: Decimal) -> some View {
            ZStack {
                let bolused = bolusProgressFormatter.string(from: (amount * progress) as NSNumber) ?? ""

                ProgressView(value: Double(truncating: progress as NSNumber))
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 110, height: 110)

                Circle()
                    .fill(Color.red.opacity(1.0))
                    .frame(width: 25, height: 25)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    )
                    .onTapGesture {
                        state.cancelBolus()
                    }

                VStack {
                    Text(
                        bolused + " " + NSLocalizedString("of", comment: "") + " " +
                            amount.formatted(.number.precision(.fractionLength(2))) +
                            NSLocalizedString(" U", comment: " ")
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white)
                    .offset(y: -78)
                }
            }
        }

        // Bolus Progress View 2

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
                            pieSegmentViewModel:
                            bolusPieSegmentViewModel2,
                            fillFraction: fillFraction,
                            backgroundColor: backgroundColor,
                            color: .blue,
                            displayText: displayText,
                            animateProgress: true
                        )

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

        struct MarqueeText: View {
            var text: String
            var fontSize: CGFloat = 15
            var textColor: Color = .white

            @State private var offset: CGFloat = 0
            let animationDuration: Double = 20.0 // Geschwindigkeit des Texts

            var body: some View {
                HStack {
                    Text(text)
                        .font(.system(size: fontSize))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .padding(.leading, 0)
                        .offset(x: offset)
                        .onAppear {
                            // Sobald der View erscheint, starte die Animation
                            withAnimation(
                                Animation.linear(duration: animationDuration)
                                    .repeatForever(autoreverses: false)
                            ) {
                                // Start der Animation: Text wird von rechts nach links verschoben
                                offset = -UIScreen.main.bounds.width - 0
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Text bleibt auf der linken Seite
                .clipped() // Verhindert, dass der Text über den Bildschirmrand hinausgeht
            }
        }

        struct SmallFillablePieSegmentSensorAge: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

            var fillFraction: CGFloat
            var color: Color
            var backgroundColor: Color
            var displayText: String
            var symbolSize: CGFloat
            var symbol: String
            var animateProgress: Bool
            var button3D: Bool

            let angularGradient = AngularGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.3)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )

            var body: some View {
                VStack {
                    ZStack {
                        if button3D {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)

                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.black.opacity(0.3),
                                            Color.black.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 40, height: 40)
                        } else {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0)
                                )
                        }

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
                    // Hier kommt der Lauftext
                    /*  MarqueeText(text: displayText)
                     .padding(.top, 0)
                     .frame(maxWidth: .infinity)
                     .background(Color.clear)*/
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

        struct FillablePieSegment: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

            var fillFraction: CGFloat
            var color: Color
            var backgroundColor: Color
            var displayText: String
            var symbolSize: CGFloat
            var symbol: String
            var animateProgress: Bool
            var button3D: Bool

            let angularGradient = AngularGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.3)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )

            var body: some View {
                VStack {
                    ZStack {
                        if button3D {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 60, height: 60)
                                .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)

                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.black.opacity(0.3),
                                            Color.black.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 60, height: 60)
                        } else {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0)
                                )
                        }

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
            var button3D: Bool

            let angularGradient = AngularGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.3)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )

            var body: some View {
                VStack {
                    ZStack {
                        if button3D {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)

                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.black.opacity(0.3),
                                            Color.black.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 40, height: 40)
                        } else {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0)
                                )
                        }

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

        struct SmallerFillablePieSegmentCarbs: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

            var fillFraction: CGFloat
            var color: Color
            var backgroundColor: Color
            var displayText: String
            var animateProgress: Bool
            var button3D: Bool

            let angularGradient = AngularGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.3)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )

            var body: some View {
                HStack(alignment: .center, spacing: 5) {
                    ZStack {
                        if button3D {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)

                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.black.opacity(0.3),
                                            Color.black.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 40, height: 40)
                        } else {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0)
                                )
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)
                        }

                        PieSliceView(
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                        )
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .opacity(0.6)
                    }
                    .frame(width: 40, height: 40)

                    Text(displayText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading) // Linksbündig ausrichten
                }
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { _, newValue in
                    pieSegmentViewModel.updateProgress(to: newValue, animate: true)
                }
            }
        }

        struct SmallerFillablePieSegmentInsulin: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

            var fillFraction: CGFloat
            var color: Color
            var backgroundColor: Color
            var displayText: String
            var animateProgress: Bool
            var button3D: Bool

            let angularGradient = AngularGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.3)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )

            var body: some View {
                HStack(alignment: .center, spacing: 5) {
                    ZStack {
                        if button3D {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)

                            Circle()
                                .fill(Color.blue)
                                .frame(width: 5, height: 5)

                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.black.opacity(0.3),
                                            Color.black.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 40, height: 40)
                        } else {
                            Circle()
                                .fill(Color.darkGray.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0)
                                )
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 5, height: 5)
                        }

                        PieSliceView(
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                        )
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .opacity(0.6)
                    }
                    .frame(width: 40, height: 40)

                    Text(displayText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading) // Linksbündig ausrichten
                }
                .onAppear {
                    pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
                }
                .onChange(of: fillFraction) { _, newValue in
                    pieSegmentViewModel.updateProgress(to: newValue, animate: true)
                }
            }
        }

        struct BigFillablePieSegment2: View {
            @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

            // private let backgroundColorCircle = Color(red: 0.31, green: 0.42, blue: 0.66)
            private let backgroundColorCircle = Color.blue.opacity(0.5)

            var fillFraction: CGFloat
            var backgroundColor: Color?
            var color: Color
            var displayText: String
            var animateProgress: Bool

            var body: some View {
                ZStack {
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

        // Fillable PieSegments Ende

        private var stackedLeftTopView: some View {
            VStack(spacing: 25) {
                carbsSmallView
                insulinSmallView
            }
        }

        // HEADERVIEW Anfang

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
                    .background(TimeEllipse(characters: 15, button3D: state.button3D))
                }
            }
        }

        // Temp Basal Ende

        private var BluetoothConnectionView: some View {
            Group {
                let connectionFraction: CGFloat = state.isConnected ? 1.0 : 0.0
                let connectionColor: Color = state.isConnected ? .green.opacity(0.8) : .green.opacity(0.8)

                HStack {
                    ZStack {
                        SmallFillablePieSegment(
                            pieSegmentViewModel: connectionPieSegmentViewModel,
                            fillFraction: connectionFraction,
                            color: connectionColor,
                            backgroundColor: .gray,
                            displayText: " ",
                            symbolSize: 0,
                            symbol: "cross.vial",
                            animateProgress: true,
                            button3D: state.button3D
                        )
                        .frame(width: 30, height: 30)

                        Image("bluetooth")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .offset(x: -1, y: -2)
                    }
                }
            }
        }

        // eventualBG Anfang

        private var eventualBGView: some View {
            ZStack {
                VStack {
                    HStack {
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
                    .background(TimeEllipse(characters: 15, button3D: state.button3D))
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
                        .offset(y: -3)
                case .view2:
                    loopView2
                        .frame(maxHeight: .infinity)
                        .offset(y: 10)
                }
            } else {
                // Fallback-Ansicht, falls der String-Wert ungültig ist
                Text("Ungültige Ansichtsauswahl")
                    .foregroundColor(.red)
            }
        }

        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
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
                maxHeight: fontSize < .extraExtraLarge ? 140 + geo.safeAreaInsets.top : 0 + geo.safeAreaInsets.top
            )
            .padding(.top, geo.safeAreaInsets.top)
            .overlay {
                VStack {
                    VStack(alignment: .leading) {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    stackedLeftTopView
                                        .offset(x: 40, y: 65)
                                }
                            }
                            HStack {
                                bolusProgressViewSelector()
                                    .offset(x: -105, y: 63)
                            }

                            loopViewSelector()
                                .offset(x: -50, y: 63)
                        }
                    }
                }
                tempRateSensorAgeeventualBG
                    .frame(maxWidth: .infinity, maxHeight: 24)
                    .offset(y: -geo.safeAreaInsets.top + 20) // Nach oben schieben
            }
            // Schatten oben
            /*  .overlay(
                 LinearGradient(
                     gradient: Gradient(colors: [
                         // backgroundColor.opacity(1),
                         // backgroundColor.opacity(1),
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
                 .offset(y: 60),
                 alignment: .top
             )*/
            // Schatten unten
            /*  .overlay(
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
             )*/
        }

        // Head Ende

        // TopBar Anfang

        // CarbView Anfang
        @StateObject private var carbsPieSegmentViewModel = PieSegmentViewModel()

        var carbsSmallView: some View {
            HStack {
                if let settings = state.settingsManager {
                    HStack {
                        ZStack {
                            let substance = Double(state.data.suggestion?.cob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxCOB), 1)
                            let fraction = CGFloat(substance / maxValue)
                            let fill = max(min(fraction, 1.0), 0.0)

                            SmallerFillablePieSegmentCarbs(
                                pieSegmentViewModel: carbsPieSegmentViewModel,
                                fillFraction: fill,
                                color: .loopYellow,
                                backgroundColor: .clear,
                                displayText: "\(numberFormatter.string(from: (state.data.suggestion?.cob ?? 0) as NSNumber) ?? "0")g",
                                animateProgress: true,
                                button3D: state.button3D
                            )
                        }
                    }
                }
            }
        }

        // CarbView Ende
        var loopView: some View {
            ZStack {
                if state.button3D {
                    Circle()
                        .fill(Color.darkGray.opacity(0.5))
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)

                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.4),
                                    Color.clear,
                                    Color.black.opacity(0.3),
                                    Color.black.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 50, height: 50)
                } else {
                    Circle()
                        .fill(Color.darkGray.opacity(0.5))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 0)
                        )
                }

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
                }
                .onLongPressGesture {
                    let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                    impactHeavy.impactOccurred()
                    state.runLoop()
                }
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

        var insulinSmallView: some View {
            HStack {
                if let settings = state.settingsManager {
                    HStack {
                        ZStack {
                            let substance = Double(state.data.suggestion?.iob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxIOB), 1)

                            let fraction = CGFloat(abs(substance) / maxValue)
                            let fill = min(fraction, 1.0)

                            let isNegative = substance < 0
                            let pieColor: Color = isNegative ? .red : .insulin
                            let _: Double = isNegative ? 90 : -90

                            SmallerFillablePieSegmentInsulin(
                                pieSegmentViewModel: insulinPieSegmentViewModel,
                                fillFraction: fill,
                                color: pieColor,
                                backgroundColor: .clear,
                                displayText: "\(insulinnumberFormatter.string(from: (state.data.suggestion?.iob ?? 0) as NSNumber) ?? "0")U",
                                animateProgress: true,
                                button3D: state.button3D
                            )
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

        var danaBar1: some View {
            if state.danaBar {
                return AnyView(
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            HStack(spacing: 10) {
                                reservoirView
                            }
                            HStack(spacing: 10) {
                                insulinAgeView
                            }
                            HStack(spacing: 10) {
                                cannulaAgeView
                            }
                            HStack(spacing: 10) {
                                batteryView
                            }
                            HStack(spacing: 10) {
                                sensorAgeDays
                            }
                        }
                    }
                    .onChange(of: state.insulinConcentration) { _, newValue in
                        if newValue != 1.0, state.settingsManager?.settings.insulinBadge == true {}
                    }.dynamicTypeSize(...DynamicTypeSize.xxLarge)
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        // DanaBar 2 mit Pumpen Icon

        var danaBar2: some View {
            if state.danaBar {
                return AnyView(
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            HStack(spacing: 10) {
                                pumpIconView
                                    .offset(y: 8)
                            }
                            HStack(spacing: 10) {
                                reservoirView
                            }
                            HStack(spacing: 10) {
                                cannulaAgeView
                            }
                            HStack(spacing: 10) {
                                batteryView
                            }
                            HStack(spacing: 10) {
                                sensorAgeDays
                            }
                        }
                    }
                    .onChange(of: state.insulinConcentration) { _, newValue in
                        if newValue != 1.0, state.settingsManager?.settings.insulinBadge == true {}
                    }.dynamicTypeSize(...DynamicTypeSize.xxLarge)
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        @State private var timerInterval: TimeInterval = 2 // Startet mit 2 Sekunden
        @State private var timer: Timer? = nil

        func startTimer() {
            timer?.invalidate() // Falls ein vorheriger Timer existiert, wird er gestoppt
            timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
                state.specialDanaKitFunction()
                state.updateRemainingSensorDays()
                // Nach 15 Sekunden auf 60 Sekunden Intervall wechseln
                if timerInterval == 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                        timerInterval = 60
                        startTimer()
                    }
                }
            }
        }

        // DanaBar Modules Start

        private var pumpIconView: some View {
            Group {
                HStack(spacing: 10) {
                    /* Text("⇠")
                     .font(.system(size: 20))
                     .foregroundStyle(Color.white)
                     .padding(.trailing, 5)*/

                    ZStack {
                        Image(state.danaIconOption.rawValue)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 50)
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
            }
        }

        private var reservoirView: some View {
            Group {
                if let reservoir = state.reservoirLevel {
                    let maxValue = Decimal(300)
                    let reservoirDecimal = Decimal(reservoir)
                    let fractionDecimal = reservoirDecimal / maxValue
                    let fill = max(min(CGFloat(NSDecimalNumber(decimal: fractionDecimal).doubleValue), 1.0), 0.0)
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

                    VStack(spacing: 5) {
                        ZStack {
                            SmallFillablePieSegment(
                                pieSegmentViewModel: reservoirPieSegmentViewModel,
                                fillFraction: fill,
                                color: reservoirColor,
                                backgroundColor: .clear,
                                displayText: displayText,
                                symbolSize: 0,
                                symbol: "cross.vial",
                                animateProgress: true,
                                button3D: state.button3D
                            )
                            .frame(width: 52, height: 45)

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
            }
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
        }

        private var insulinAgeView: some View {
            Group {
                HStack(spacing: 10) {
                    let remainingReservoirAge: String = {
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

                            let remainingHours = max(0, Int(maxInsulinAge) - totalHours)
                            let remainingDays = remainingHours / 24
                            let remainingHrs = remainingHours % 24

                            return "\(remainingDays)d\(remainingHrs)h"
                        } else {
                            return "--"
                        }
                    }()

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
                                    return .red.opacity(1.0)
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
                            pieSegmentViewModel:
                            reservoirAgePieSegmentViewModel,
                            fillFraction: fillFraction,
                            color: insulinColor,
                            backgroundColor: .clear,
                            displayText: remainingReservoirAge,
                            symbolSize: 0,
                            symbol: "timer",
                            animateProgress: true,
                            button3D: state.button3D
                        )
                        .frame(width: 52, height: 45)

                        Image("vial")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }

        private var cannulaAgeView: some View {
            Group {
                let cannulaDisplayText: String = {
                    if let cannulaHours = state.cannulaHours,
                       let cannulaAgeOption = CannulaAgeOption(rawValue: state.cannulaAgeOption)
                    {
                        let remainingHours = max(cannulaAgeOption.maxCannulaAge - cannulaHours, 0)
                        let totalRemainingMinutes = Int(remainingHours * 60) // Umwandlung in Minuten

                        if totalRemainingMinutes < 60 {
                            return "\(totalRemainingMinutes) min" // Falls unter einer Stunde, nur Minuten anzeigen
                        } else {
                            let days = totalRemainingMinutes / (24 * 60)
                            let hours = (totalRemainingMinutes % (24 * 60)) / 60
                            return "\(days)d\(hours)h"
                        }
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
                        if remainingHours <= 1 { // Test ob es bei unter oder gleich einer Stunde komplett rot wird
                            // if remainingHours <= 0 { Original. Unter 1 Stunde zeigt er immer noch den roten Pie Anteil
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
                        let dangerThreshold = maxCannulaAge * 0.85

                        if cannulaHours >= maxCannulaAge {
                            return .red.opacity(1.0)
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
                        return .clear
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
                        animateProgress: true,
                        button3D: state.button3D
                    )
                    .frame(width: 52, height: 45)

                    Image("infusion")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
            }
        }

        private var batteryView: some View {
            Group {
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

                    VStack(spacing: 5) {
                        ZStack {
                            SmallFillablePieSegment(
                                pieSegmentViewModel: batteryPieSegmentViewModel,
                                fillFraction: batteryFraction,
                                color: batteryColor,
                                backgroundColor: .clear,
                                displayText: batteryText,
                                symbolSize: 0,
                                symbol: "cross.vial",
                                animateProgress: true,
                                button3D: state.button3D
                            )
                            .frame(width: 52, height: 45)

                            Image("battery")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                        }
                    }
                }
            }
        }

        @StateObject private var sensorAgeSegmentViewModel = PieSegmentViewModel()
        @State private var sensorAgeText: String = ""

        private var sensorAgeDays: some View {
            Group {
                if state.displayExpiration {
                    let totalHours = state.sensorAgeDays.asInt() * 24
                    let remainingHours = max(1, totalHours - state.elapsedHours)
                    let fillFraction: CGFloat = remainingHours <= 1 ? 1.0 : CGFloat(remainingHours) / CGFloat(totalHours)
                    let sensorColor: Color = remainingHours < 24 ? .red.opacity(0.8) : {
                        switch remainingHours {
                        case ...24: return .red.opacity(0.7)
                        case ...48: return .yellow.opacity(0.7)
                        default: return .green.opacity(0.7)
                        }
                    }()

                    let sensorAgeText: String = {
                        if let minutes = state.remainingSensorMinutes {
                            return "\(minutes) min"
                        } else {
                            let days = state.remainingSensorDays
                            let hours = state.remainingSensorHours ?? 0
                            return hours >= 1 ? "\(days)d\(hours)h" : "\(days)d\(hours)h"
                        }
                    }()

                    VStack(spacing: 5) {
                        ZStack {
                            SmallFillablePieSegmentSensorAge(
                                pieSegmentViewModel: sensorAgeSegmentViewModel,
                                fillFraction: fillFraction,
                                color: sensorColor,
                                backgroundColor: .clear,
                                displayText: sensorAgeText,
                                symbolSize: 0,
                                symbol: "cross.vial",
                                animateProgress: true,
                                button3D: state.button3D
                            )
                            .frame(width: 52, height: 45)

                            Image(systemName: "sensor.tag.radiowaves.forward")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .offset(x: 1, y: -2)
                        }
                    }
                }
            }
            .onAppear {
                state.settingsDidChange(state.settingsManager.settings)
                state.sensorAgeDays = state.settingsManager.settings.sensorAgeDays
                // state.updateRemainingSensorDays()
            }
        }

        // DanaBar Modules Ende

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
                Group {
                    if state.danaBarViewOption == "view1" {
                        danaBar1
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                    } else {
                        danaBar2
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                    }
                    mainChart.padding(.top, 35)
                    legendPanel.padding(.top, 25)
                    tempTargetbar.padding(.top, 35)
                    bottomBar.padding(.top, 20).padding(.bottom, 10)
                        .frame(width: UIScreen.main.bounds.width)
                }
            }
            .frame(minHeight: UIScreen.main.bounds.height / 1.60) // Je größer der Wert, desto kleiner der Chart
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
                    .background(TimeEllipseLegend(characters: 17, button3D: state.button3D))
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        // tempRateSensorAgeeventualBG Anfang
        var tempRateSensorAgeeventualBG: some View {
            ZStack {
                info4
            }
            .frame(maxWidth: .infinity)
        }

        var info4: some View {
            Group {
                HStack(spacing: 15) {
                    Spacer()
                    HStack {
                        tempRateView
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: 100, alignment: .leading)
                    Spacer()
                    HStack {
                        if state.isConnected {
                            BluetoothConnectionView
                                .foregroundColor(.white)
                                .offset(y: -10)
                        }
                    }
                    Spacer()
                    HStack {
                        eventualBGView
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, -22)
                    .frame(maxWidth: 100, alignment: .trailing)
                    Spacer()
                }
            }
        }

        // tempRateSensorAgeeventualBG Ende

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

            .background(TimeEllipse(characters: 20, button3D: state.button3D))
        }

        // BottomInfoBar mit TimeButtons
        var bottomBar: some View {
            Group {
                if state.timeSettings {
                    HStack(spacing: 15) {
                        // Linker Stack
                        Spacer()
                        HStack {
                            isfView
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 0)
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
                        }
                        .padding(.trailing, 25)
                        .frame(maxWidth: 100, alignment: .trailing)

                        Spacer()
                    }
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
                            .foregroundStyle(.white)

                        Text("\(sensitivityPercentage)%")
                            .foregroundStyle(.white)
                            .font(.timeSettingFont)
                    }
                    .background(TimeEllipse(characters: 12, button3D: state.button3D))
                    .onTapGesture {
                        if state.autoisf {
                            displayAutoHistory.toggle()
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
                Button("UI/UX Settings", action: { state.showModal(for: .statisticsConfig) })
            }
            .foregroundStyle(Color.white)
            .font(.timeSettingFont)
            .padding(.vertical, 15)
            .background(TimeEllipse(characters: string.count, button3D: state.button3D))
        }

        private var tddView: some View {
            ZStack {
                HStack {
                    Image(systemName: "circle.slash").font(.system(size: 13)).foregroundStyle(.white)

                    Text("\(targetFormatter.string(from: state.tddActualAverage as NSNumber) ?? "0") U")
                        .foregroundStyle(.white)
                }
                .font(.timeSettingFont)
                .background(TimeEllipse(characters: 12, button3D: state.button3D))
            }.offset(x: 0)
        }

        @State private var didLongPress = false

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
                        buttonWithCircle(iconName: "carbs3", circleColor: Color.darkGray.opacity(1.0)) {
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

                    buttonWithCircle(iconName: "iob", circleColor: Color.darkGray.opacity(1.0)) {
                        (state.bolusProgress != nil) ? showBolusActiveAlert = true :
                            state.showModal(for: .bolus(
                                waitForSuggestion: state.useCalc ? true : false,
                                fetch: false
                            ))
                    }
                    Spacer()

                    if state.allowManualTemp {
                        buttonWithCircle(iconName: "insulin", circleColor: Color.darkGray.opacity(1.0)) {
                            state.showModal(for: .manualTempBasal)
                        }
                        Spacer()
                    }

                    buttonWithCircle(
                        iconName: isOverride ? "profilefill" : "profile",
                        circleColor: Color.darkGray.opacity(1.0)
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
                            circleColor: Color.darkGray.opacity(1.0)
                        ) {
                            if isTarget {
                                showCancelTTAlert.toggle()
                            } else {
                                state.showModal(for: .addTempTarget)
                            }
                        }
                        Spacer()
                    }

                    buttonWithCircle(iconName: "ux", circleColor: Color.darkGray.opacity(1.0)) {
                        state.showModal(for: .statisticsConfig)
                    }
                    Spacer()

                    buttonWithCircle(iconName: "settings2", circleColor: Color.darkGray.opacity(1.0)) {
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
            circleColor _: Color,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                ZStack {
                    if state.button3D {
                        Circle()
                            .fill(Color.darkGray.opacity(0.5))
                            .frame(width: 50, height: 50)
                            .shadow(color: Color.black.opacity(0.4), radius: 5, x: 3, y: 3)

                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.4),
                                        Color.clear,
                                        Color.black.opacity(0.3),
                                        Color.black.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 50, height: 50)
                    } else {
                        Circle()
                            .fill(Color.darkGray.opacity(0.5))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 0)
                            )
                    }

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
                            } else { Text("📉") }
                        } else if override.percentage != 100 {
                            Text(override.percentage.formatted() + " %").font(.statusFont).foregroundStyle(.secondary)
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

                if !state.iobData.isEmpty {
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
                                    DayView.padding(.bottom, 40).padding(.top, 30)
                                }
                                .background(GeometryReader { geo in
                                    let offset = -geo.frame(in: .named(scrollSpace)).minY
                                    backgroundColor
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
                    .background(backgroundColor)
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
