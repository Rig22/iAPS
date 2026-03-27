import Algorithms
import Combine
import SwiftDate
import SwiftUI

enum PredictionType: Hashable {
    case iob
    case cob
    case zt
    case uam
}

struct DotInfo {
    let rect: CGRect
    let value: Decimal
    let text: String?
    let textRect: CGRect?
}

struct AnnouncementDot {
    let rect: CGRect
    let value: Decimal
    let note: String
}

struct OverrideStruct {
    let start: Date
    let end: Date
    let glucose: Int
}

typealias GlucoseYRange = (minValue: Int, minY: CGFloat, maxValue: Int, maxY: CGFloat)

struct GlucosePeak {
    let xStart: CGFloat
    let yStart: CGFloat
    let glucose: Int
    let text: String
    let textRect: CGRect
    let type: ExtremumType
}

enum ChartConfig {
    static let endID = "End"
    static let basalHeight: CGFloat = 20 // 60
    static let topYPadding: CGFloat = 50 // 55
    static let bottomPadding: CGFloat = 30
    static let legendBottomPadding: CGFloat = 0 // without insulin activity: additional legend padding
    static let activityChartHeight: CGFloat = 0 // 80
    static let activityChartTopGap: CGFloat = 0 // 20 gap between main chart and activity chart, with legend inside
    static let mainChartBottomPaddingWithActivity: CGFloat = bottomPadding + activityChartHeight + activityChartTopGap
    static let legendBottomPaddingWithActivity: CGFloat = bottomPadding + activityChartHeight
    static let cobChartHeight: CGFloat = activityChartHeight
    static let cobChartTopGap: CGFloat = activityChartTopGap
    static let minAdditionalWidth: CGFloat = 150
    static let maxGlucose = 270
    static let minGlucose = 0 // 45
    static let yLinesCount = 5
    static let glucoseScale: CGFloat = 2 // default 2
    static let bolusSize: CGFloat = 8 // 8 Minimal Größe Bolus Icons
    static let bolusScale: CGFloat = 2.5 // 2.5 Scaled die Bolus Icons
    static let maxBolusSize: CGFloat = 20
    static let carbsSize: CGFloat = 10 // 6 Minimal Größe fork.knife
    static let maxCarbSize: CGFloat = 25 // Maximale Gr. fork.knife
    static let carbsScale: CGFloat = 0.3 // 0.3 Scaler fork.knife
    static let fpuSize: CGFloat = 4
    static let fpuScale: CGFloat = 0.5
    static let announcementSize: CGFloat = 8
    static let announcementScale: CGFloat = 2.5
    static let owlSeize: CGFloat = 20
    static let glucoseSize: CGFloat = 4
    static let owlOffset: CGFloat = 100
    static let carbOffset: CGFloat = 3 // 13
    static let insulinOffset: CGFloat = 17
    static let pointSizeHeight: Double = 5
    static let pointSizeHeightCarbs: Double = 5
    static let bolusHeight: Decimal = 25 // 45
    static let carbHeight: Decimal = 25 // 45
    static let carbWidth: CGFloat = 5
    static let peakHorizontalPadding: CGFloat = 4
    static let peakVerticalPadding: CGFloat = 2
    static let peakMargin: CGFloat = 6
    static let peakCornerRadius: CGFloat = 2
    static let insulinCarbLabelMargin: CGFloat = 2
}

struct MainChartView: View {
    @State var data: ChartModel
    @Binding var triggerUpdate: Bool

    @State private var geom: CalculatedGeometries? = nil

    private let calculationQueue = DispatchQueue(label: "MainChartView.calculationQueue")

    @State private var latestSize: CGSize = .zero
    @State private var updatesCancellable: AnyCancellable?

    @State private var sizeChanges = PassthroughSubject<Void, Never>()
    @State private var updateRequests = PassthroughSubject<Void, Never>()
    @Environment(\.scenePhase) private var scenePhase

    @State private var shouldScrollAfterUpdate = true
    @State private var scrollTrigger = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let geom = self.geom {
                    MainChartCanvas(geom: geom, data: data, scrollTrigger: $scrollTrigger)
                }
            }
            .onAppear {
                latestSize = geo.size
                subscribeToUpdates()
                sizeChanges.send(())
            }
            .onChange(of: geo.size) {
                latestSize = geo.size
                sizeChanges.send(())
            }
            .onChange(of: triggerUpdate) {
                updateRequests.send(())
            }
            .onChange(of: data.screenHours) {
                shouldScrollAfterUpdate = true
            }
            .onChange(of: scenePhase) {
                switch scenePhase {
                case .active:
                    subscribeToUpdates()
                    updateRequests.send(())
                case .background,
                     .inactive:
                    unsubscribeFromUpdates()
                @unknown default:
                    print("unknown scene phase: \(scenePhase)")
                }
            }
        }
    }

    private func triggerScroll() {
        scrollTrigger &+= 1
    }

    private func update(fullSize: CGSize) {
        let started = Date.now

        let geom = CalculatedGeometries.make(fullSize: fullSize, data: data)

        let ended = Date.now
        debug(
            .service,
            "main chart update: \(ended.timeIntervalSince(started) * 1000) milliseconds"
        )

        DispatchQueue.main.async {
            if self.shouldScrollAfterUpdate {
                triggerScroll()
                self.shouldScrollAfterUpdate = false
            }
            self.geom = geom
        }
    }

    private func ping<T: Equatable>(_ p: Published<T>.Publisher) -> AnyPublisher<Void, Never> {
        p.removeDuplicates()
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private func subscribeToUpdates() {
        guard updatesCancellable == nil else { return }
        let debouncedPublishers: [AnyPublisher<Void, Never>] = [
            ping(data.$screenHours),
            ping(data.$showInsulinActivity),
            ping(data.$showCobChart),
            ping(data.$useInsulinBars),
            ping(data.$useCarbBars),
            ping(data.$tempBasals),
            ping(data.$suspensions),
            ping(data.$maxBasal),
            ping(data.$autotunedBasalProfile),
            ping(data.$glucose),
            ping(data.$activity),
            ping(data.$cob),
            ping(data.$isManual),
            ping(data.$announcement),
            ping(data.$boluses),
            ping(data.$carbs),
            ping(data.$tempTargets),
            ping(data.$suggestion),
            ping(data.$latestOverride),
            ping(data.$overrideHistory),
            ping(data.$lowGlucose),
            ping(data.$highGlucose),
            ping(data.$units),
            ping(data.$minimumSMB),
            ping(data.$chartGlucosePeaks),
            ping(data.$yGridLabels),
            ping(data.$thresholdLines),
            ping(data.$displayYgridLines),
            ping(data.$inRangeAreaFill),
            ping(data.$hidePredictions)
        ]

        let immediatePublishers: [AnyPublisher<Void, Never>] = [
            sizeChanges.eraseToAnyPublisher(),
            updateRequests.eraseToAnyPublisher()
        ]

        let debouncedUpdates: AnyPublisher<Void, Never> =
            Publishers.MergeMany(debouncedPublishers)
                .debounce(for: .milliseconds(15), scheduler: calculationQueue)
                .eraseToAnyPublisher()

        let immediateUpdates: AnyPublisher<Void, Never> =
            Publishers.MergeMany(immediatePublishers)
                .eraseToAnyPublisher()

        updatesCancellable =
            Publishers.MergeMany([debouncedUpdates, immediateUpdates])
                .receive(on: calculationQueue)
                .sink { _ in
                    update(fullSize: latestSize)
                }
    }

    private func unsubscribeFromUpdates() {
        updatesCancellable?.cancel()
        updatesCancellable = nil
    }
}

struct MainChartCanvas: View {
    let geom: CalculatedGeometries
    let data: ChartModel
    @Binding var scrollTrigger: Int

    private enum Command {
        static let open = "🔴"
        static let closed = "🟢"
        static let suspend = "❌"
        static let resume = "✅"
        static let tempbasal = "basal"
        static let bolus = "💧"
        static let meal = "🍴"
        static let override = "👤"
    }

    private let date24Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.setLocalizedDateFormatFromTemplate("HH")
        return formatter
    }()

    private let glucoseFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    var body: some View {
        ZStack {
            yGridView
            mainScrollView
            if data.yGridLabels {
                glucoseLabelsView
            }
            if data.showInsulinActivity, data.insulinActivityLabels {
                activityLabelsView
            }
        }
    }

    var legendPanel: some View {
        ZStack {
            HStack {
                if !data.hidePredictions && data.showPredictionsLegend {
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
        }
    }

    private var mainScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { scroll in
                ZStack(alignment: .top) {
                    tempTargetsView.drawingGroup()
                    overridesView.drawingGroup()
                    // basalView.drawingGroup()
                    if data.showInsulinActivity || data.showCobChart {
                        legendPanel.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, 20)
                            .padding(
                                .bottom,
                                ChartConfig.bottomPadding + ChartConfig.legendBottomPadding + ChartConfig.activityChartHeight
                            )
                    } else {
                        legendPanel.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, 20)
                            .padding(.bottom, ChartConfig.bottomPadding + ChartConfig.legendBottomPadding)
                    }
                    mainView.id(ChartConfig.endID)
                        .drawingGroup()
                        /* .onChange(of: data.glucose) { _ in
                             scroll.scrollTo(ChartConfig.endID, anchor: .trailing)
                         }
                         .onChange(of: data.suggestion) { _ in
                             scroll.scrollTo(ChartConfig.endID, anchor: .trailing)
                         }
                         .onChange(of: data.tempBasals) { _ in
                             scroll.scrollTo(ChartConfig.endID, anchor: .trailing)
                         } */
                        .onChange(of: scrollTrigger) {
                            DispatchQueue.main.async {
                                scroll.scrollTo(ChartConfig.endID, anchor: .trailing)
                            }
                        }
                        .onAppear {
                            DispatchQueue.main.async {
                                scroll.scrollTo(ChartConfig.endID, anchor: .trailing)
                            }
                        }
                }
            }
        }
    }

    private var yGridView: some View {
        let useColour = data.displayYgridLines ? Color.secondary : Color.clear
        return ZStack {
            /*  if data.displayYgridLines {
                 Path { path in
                     for (line, _) in geom.horizontalGrid {
                         path.move(to: CGPoint(x: 0, y: line))
                         path.addLine(to: CGPoint(x: geom.fullSize.width, y: line))
                     }
                 }.stroke(useColour, lineWidth: 0.15)
             }*/
            if data.displayYgridLines {
                Path { path in
                    for (line, _) in geom.horizontalGrid {
                        path.move(to: CGPoint(x: 0, y: line))
                        path.addLine(to: CGPoint(x: geom.fullSize.width, y: line))
                    }
                }
                .stroke(
                    Color.secondary,
                    style: StrokeStyle(lineWidth: 0.5, lineCap: .round, dash: [2, 4])
                )
            }
            // In-range highlight mit Gradient
            if data.inRangeAreaFill {
                if let (highLineY, _) = geom.highThresholdLine,
                   let (lowLineY, _) = geom.lowThresholdLine
                {
                    let targetGradient = LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.0),
                            Color.green.opacity(0.15),
                            Color.green.opacity(0.15),
                            Color.green.opacity(0.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Path { path in
                        path.addRect(CGRect(x: 0, y: highLineY, width: geom.fullSize.width, height: lowLineY - highLineY))
                    }
                    .fill(targetGradient)
                }
            }

            // horizontal limits
            if data.thresholdLines {
                if let (highLineY, _) = geom.highThresholdLine {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: highLineY))
                        path.addLine(to: CGPoint(x: geom.fullSize.width, y: highLineY))
                    }.stroke(Color.loopYellow, lineWidth: 0.4).opacity(0.8)
                }
                if let (lowLineY, _) = geom.lowThresholdLine {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: lowLineY))
                        path.addLine(to: CGPoint(x: geom.fullSize.width, y: lowLineY))
                    }.stroke(Color.loopRed, lineWidth: 0.4).opacity(0.8)
                }
            }

            if data.showInsulinActivity || data.showCobChart {
                if data.secondaryChartBackdrop {
                    // background for COB/activity
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geom.fullSize.height - ChartConfig.bottomPadding))
                        path.addLine(to: CGPoint(x: geom.fullSize.width, y: geom.fullSize.height - ChartConfig.bottomPadding))
                        path
                            .addLine(to: CGPoint(
                                x: geom.fullSize.width,
                                y: geom.fullSize.height - ChartConfig.bottomPadding - ChartConfig.activityChartHeight
                            ))
                        path
                            .addLine(to: CGPoint(
                                x: 0,
                                y: geom.fullSize.height - ChartConfig.bottomPadding - ChartConfig.activityChartHeight
                            ))
                        path.addLine(to: CGPoint(x: 0, y: geom.fullSize.height - ChartConfig.bottomPadding))
                    }.fill(IAPSconfig.activityBackground)
                }
            }

            if data.showInsulinActivity, data.insulinActivityGridLines {
                ForEach([(geom.peakActivity_1unit_y, 1), (geom.peakActivity_maxBolus_y, 2)], id: \.1) { yCoord, _ in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yCoord))
                        path.addLine(to: CGPoint(x: geom.fullSize.width, y: yCoord))
                    }.stroke(Color.secondary.opacity(0.0), lineWidth: 0.15)
                }
            }

            // thicker zero guideline for activity/COB
            if data.showInsulinActivity, data.insulinActivityGridLines, let yCoord = geom.activityZeroPointY {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: yCoord))
                    path.addLine(to: CGPoint(x: geom.fullSize.width, y: yCoord))
                }.stroke(Color.secondary.opacity(0.0), lineWidth: 0.4)
            }
        }
    }

    private var glucoseLabelsView: some View {
        ForEach(geom.glucoseLabels, id: \.1) { (lineY, glucose) -> AnyView in
            let value = Double(glucose) *
                (data.units == .mmolL ? Double(GlucoseUnits.exchangeRate) : 1)

            Text(value == 0 ? "" : glucoseFormatter.string(from: value as NSNumber) ?? "")
                .position(CGPoint(x: geom.fullSize.width - 12, y: lineY))
                .font(.bolusDotFont)
                .asAny()
        }
    }

    private var activityLabelsView: some View {
        ForEach(
            [
                (Decimal(1.0), geom.peakActivity_1unit, geom.peakActivity_1unit_y, 1),
                (data.maxBolus, geom.peakActivity_maxBolus, geom.peakActivity_maxBolus_y, 2)
            ],
            id: \.2
        ) { bolus, _, yCoord, _ in
            let value = bolus

            return HStack(spacing: 2) {
                Text(glucoseFormatter.string(from: value as NSNumber) ?? "").font(.bolusDotFont)
                Text("U").font(.bolusDotFont.smallCaps()) // .foregroundStyle(Color.secondary)
            }.foregroundStyle(Color(.insulin).opacity(0.0))
                .position(CGPoint(x: geom.fullSize.width - 12, y: yCoord))
                .asAny()
        }
    }

    private var basalView: some View {
        ZStack {
            // 1. Dynamischer Gletscher-Füllung
            geom.tempBasalPath
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.insulin.opacity(colorScheme == .dark ? 0.5 : 0.35),
                            Color.insulin.opacity(colorScheme == .dark ? 0.2 : 0.1),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: colorScheme == .dark ? 0.3 : 0.5) // Im Dark Mode etwas schärfer

            // 2. Die obere Begrenzungslinie (Leucht-Effekt im Dark Mode)
            geom.tempBasalPath
                .stroke(
                    Color.insulin.opacity(colorScheme == .dark ? 0.8 : 0.4),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                // Ein subtiler Glow-Effekt für den Dark Mode
                .shadow(color: colorScheme == .dark ? Color.insulin.opacity(0.5) : Color.clear, radius: 4)

            // 3. Die Standard-Basal-Linie (Dezenter)
            geom.regularBasalPath
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.15) : Color.insulin.opacity(0.2),
                    style: StrokeStyle(lineWidth: 0.7, dash: [6, 4])
                )

            // 4. Pumpen-Stopps (Suspensions)
            geom.suspensionsPath
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.loopGray.opacity(0.15))
                .scaleEffect(x: 1, y: -1)
        }
        .scaleEffect(x: 1, y: -1)
        .frame(width: geom.fullGlucoseWidth + geom.additionalWidth)
        .frame(maxHeight: ChartConfig.basalHeight)
    }

    private var mainView: some View {
        Group {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    xGridView
                    /*  if data.showCobChart {
                         cobView
                     }*/
                    if data.showInsulinActivity {
                        activityView
                    }
                    if data.showCobChart {
                        cobView
                    }
                    glucoseUpperAreaView // Verlauf über Gluscose Linie
                    glucoseLowerAreaView
                    basalView
                    bolusView
                    carbsView
                    if data.fpus { fpuView }

                    // 5. Glukose-Kurve
                    if data.smooth { unSmoothedGlucoseView }
                    else { connectingGlucoseLinesView }

                    glucoseView
                    lowGlucoseView
                    highGlucoseView
                    if data.chartGlucosePeaks { glucosePeaksView }
                    manualGlucoseView
                    manualGlucoseCenterView
                    announcementView

                    if !data.hidePredictions {
                        predictionsView
                    }
                }
                timeLabelsView
            }
        }
        .frame(
            width: geom.fullGlucoseWidth + geom.additionalWidth
        )
    }

    @Environment(\.colorScheme) var colorScheme

    private var xGridView: some View {
        //   let useColour = data.displayXgridLines ? Color.secondary : Color.clear
        ZStack {
            // Vertikales Zeit-Gitter
            if data.displayXgridLines {
                Path { path in
                    for hour in 0 ..< data.hours + data.hours {
                        // Wir zeigen nur jede 2. Stunde als Linie, um es nicht zu überladen
                        if hour % 2 == 0 {
                            let xPos = geom.firstHourPosition + geom.oneSecondWidth * CGFloat(hour) * CGFloat(3600)
                            path.move(to: CGPoint(x: xPos, y: 0))
                            path.addLine(to: CGPoint(x: xPos, y: geom.fullSize.height - 20))
                        }
                    }
                }
                .stroke(
                    // Color.secondary.opacity(0.15),
                    Color.secondary,

                    style: StrokeStyle(lineWidth: 0.5, dash: [4, 6])
                )

                Path { path in // vertical timeline
                    path.move(to: CGPoint(x: geom.currentTimeX, y: 0))
                    path.addLine(to: CGPoint(x: geom.currentTimeX, y: geom.fullSize.height - 20))
                }
                .stroke(
                    colorScheme == .dark ? IAPSconfig.chartBackgroundLight : IAPSconfig.chartBackgroundDark,
                    style: StrokeStyle(lineWidth: 0.5, dash: [5])
                )
            }
        }
    }

    private var timeLabelsView: some View {
        let format = date24Formatter
        return ZStack {
            ForEach(0 ..< data.hours + data.hours, id: \.hours) { hour in
                if data.screenHours >= 12 && hour % 2 == 1 {
                    // only show every second time label if screenHours is too big
                    EmptyView()
                } else {
                    Text(format.string(from: geom.firstHourDate.addingTimeInterval(hour.hours.timeInterval)))
                        .font(.chartTimeFont)
                        .position(
                            x: geom.firstHourPosition +
                                geom.oneSecondWidth *
                                CGFloat(hour) * CGFloat(1.hours.timeInterval),
                            y: 10.0
                        )
                        .foregroundColor(.secondary)
                }
            }
        }.frame(maxHeight: 20)
    }

    private var lowGlucoseView: some View {
        Path { path in
            for rect in geom.glucoseDots {
                if let glucose = rect.glucose, Decimal(glucose) <= data.lowGlucose {
                    path.addEllipse(in: rect.rect)
                }
            }
        }.fill(Color.red)
    }

    private var glucoseView: some View {
        Path { path in
            for rect in geom.glucoseDots {
                if let glucose = rect.glucose, Decimal(glucose) > data.lowGlucose,
                   Decimal(glucose) < data.highGlucose
                {
                    path.addEllipse(in: rect.rect)
                }
            }
        }.fill(Color(.darkGreen))
    }

    // Güner verlauf unter der GlucoseLinie
    /*  private var glucoseView: some View {
         ZStack {
             Path { path in
                 let points = geom.glucoseDots.compactMap { dot -> CGPoint? in
                     guard dot.glucose != nil else { return nil }
                     return CGPoint(x: dot.rect.midX, y: dot.rect.midY)
                 }

                 if let firstPoint = points.first {
                     let chartBottom = geom.fullSize.height - ChartConfig.bottomPadding

                     // Wir starten am Boden unter dem ersten Punkt
                     path.move(to: CGPoint(x: firstPoint.x, y: chartBottom))

                     // Zeichnen die Linie durch alle Punkte
                     for point in points {
                         path.addLine(to: point)
                     }

                     // Gehen am Ende wieder runter zum Boden
                     if let lastPoint = points.last {
                         path.addLine(to: CGPoint(x: lastPoint.x, y: chartBottom))
                     }
                     path.closeSubpath()
                 }
             }
                .fill(
                  LinearGradient(
                      gradient: Gradient(colors: [
                          Color.loopGreen.opacity(0.35), // Farbe oben
                          Color.loopGreen.opacity(0.0) // Verblasst nach unten
                      ]),
                      startPoint: .top,
                      endPoint: .bottom
                  )
              )
              .blur(radius: 8)

             Path { path in
                 for dot in geom.glucoseDots {
                     if let val = dot.glucose,
                        Decimal(val) >= data.lowGlucose,
                        Decimal(val) <= data.highGlucose
                     {
                         path.addEllipse(in: dot.rect)
                     }
                 }
             }
             .fill(Color.loopGreen) // Kräftiges Grün für die Punkte
         }
     }*/

    private var glucoseGlowColor: Color {
        let type = data.glucose.last?.glucose ?? 120
        if type < Int(data.lowGlucose) { return Color.red.opacity(0.0) }
        if type > Int(data.highGlucose) { return Color.orange.opacity(0.0) }

        // Ein sattes Smaragd-Grün/Türkis leuchtet viel besser als Standard-Grün
        return Color(red: 0.0, green: 0.8, blue: 0.7)
    }

    // Die Fläche ÜBER der Kurve
    private var glucoseUpperAreaView: some View {
        Path { path in
            let dots = geom.glucoseDots
            guard dots.count > 1 else { return }

            // Start oben links (y: 0)
            path.move(to: CGPoint(x: dots[0].rect.midX, y: 0))

            // Linie entlang der Glukosewerte
            for dot in dots {
                path.addLine(to: CGPoint(x: dot.rect.midX, y: dot.rect.midY))
            }

            // Abschluss oben rechts (y: 0)
            if let last = dots.last {
                path.addLine(to: CGPoint(x: last.rect.midX, y: 0))
            }
            path.closeSubpath()
        }
        .fill(upperGlucoseGradient)
    }

    private var upperGlucoseGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [
                Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.2),
                Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.8),
                Color(red: 0.0, green: 0.2, blue: 0.7).opacity(1.0)
            ] : [
                Color(red: 0.7, green: 0.9, blue: 0.5).opacity(0.10),
                Color(red: 0.3, green: 0.8, blue: 0.6).opacity(0.15),
                Color(red: 0.1, green: 0.6, blue: 0.9).opacity(0.20)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Die Fläche UNTER der Kurve
    private var glucoseLowerAreaView: some View {
        Path { path in
            let dots = geom.glucoseDots
            guard dots.count > 1 else { return }

            // Start an der Linie (unten links)
            path.move(to: CGPoint(x: dots[0].rect.midX, y: dots[0].rect.midY))

            for dot in dots {
                path.addLine(to: CGPoint(x: dot.rect.midX, y: dot.rect.midY))
            }

            // Abschluss am unteren Rand des Charts (geom.fullSize.height - 20)
            let bottomY = geom.fullSize.height - 20
            if let last = dots.last {
                path.addLine(to: CGPoint(x: last.rect.midX, y: bottomY))
            }
            path.addLine(to: CGPoint(x: dots[0].rect.midX, y: bottomY))
            path.closeSubpath()
        }
        .fill(glucoseAreaViewGradient)
    }

    private var glucoseAreaViewGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [
                Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.0),
                Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.0),
                Color(red: 0.0, green: 0.2, blue: 0.7).opacity(0.0)
            ] : [
                Color(red: 0.7, green: 0.9, blue: 0.5).opacity(0.20),
                Color(red: 0.3, green: 0.8, blue: 0.6).opacity(0.15),
                Color(red: 0.1, green: 0.6, blue: 0.9).opacity(0.10)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var highGlucoseView: some View {
        Path { path in
            for rect in geom.glucoseDots {
                if let glucose = rect.glucose, Decimal(glucose) >= data.highGlucose {
                    path.addEllipse(in: rect.rect)
                }
            }
        }.fill(.orange)
    }

    private var glucosePeaksView: some View {
        ForEach(geom.glucosePeaks, id: \.xStart) { peak in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: peak.xStart, y: peak.yStart))
                    path.addLine(to: CGPoint(x: peak.textRect.midX, y: peak.textRect.midY))
                }
                .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 3]))

                let glucoseDecimal = Decimal(peak.glucose)
                let fillColour = {
                    if glucoseDecimal < data.lowGlucose {
                        return Color.peakRed
                    }
                    if glucoseDecimal > data.highGlucose {
                        return Color.peakOrange
                    }
                    return Color.peakGreen
                }()

                ZStack {
                    Text(peak.text)
                        .font(geom.peaksFont)
                        .padding(.horizontal, ChartConfig.peakHorizontalPadding)
                        .padding(.vertical, ChartConfig.peakVerticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: ChartConfig.peakCornerRadius)
                                .fill(fillColour)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.primary, lineWidth: 0.5)
                                .opacity(0.9)
                        )
                }
                .position(CGPoint(x: peak.textRect.midX, y: peak.textRect.midY))
            }
            .asAny()
        }
    }

    /* private var activityView: some View {
         ZStack {
             positiveActivityFillPath()
                 .fill(Color.blue.opacity(0.3))

             negativeActivityFillPath()
                 .fill(Color.red.opacity(0.3))

             activityStrokePath()
                 .stroke(
                     colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.5),
                     style: StrokeStyle(lineWidth: 0.5)
                 )
         }
     } */

    // Insulin Activity Wolke

    private var activityView: some View {
        let maxAct = geom.maxActivityInData ?? 0

        return Group {
            if maxAct > 0.001 { // Winziger Schwellenwert für "echte" Aktivität
                ZStack {
                    Path { path in
                        let glucosePoints = geom.glucoseDots
                        let activityPoints = geom.activityDots

                        guard glucosePoints.count >= 2, activityPoints.count >= 2 else { return }

                        let glucoseCenters = glucosePoints.map { CGPoint(x: $0.rect.midX, y: $0.rect.midY) }

                        var topPoints: [CGPoint] = []
                        var bottomPoints: [CGPoint] = []

                        for aPoint in activityPoints {
                            let sortedByX = glucoseCenters.sorted { abs($0.x - aPoint.x) < abs($1.x - aPoint.x) }

                            guard let closest = sortedByX.first else { continue }
                            var glucoseY = closest.y

                            if sortedByX.count >= 2 {
                                let p1 = sortedByX[0]
                                let p2 = sortedByX[1]
                                let totalDist = abs(p2.x - p1.x)
                                if totalDist > 0 {
                                    let weight1 = abs(p2.x - aPoint.x) / totalDist
                                    let weight2 = abs(aPoint.x - p1.x) / totalDist
                                    glucoseY = p1.y * weight1 + p2.y * weight2
                                }
                            }

                            let baselineY = geom.activityZeroPointY ?? 0
                            let activityHeight = max(0, baselineY - aPoint.y)

                            let threshold: CGFloat = 0.2 // Justiere diesen Wert (0.1 bis 0.5), falls nötig
                            let scaledHeight: CGFloat

                            if activityHeight > threshold {
                                scaledHeight = min(activityHeight * 4.0, 40)
                            } else {
                                // Absolut keine Wolke, wenn unter Schwellenwert
                                scaledHeight = 0
                            }

                            topPoints.append(CGPoint(x: aPoint.x, y: glucoseY))
                            bottomPoints.append(CGPoint(x: aPoint.x, y: glucoseY + scaledHeight))
                        }

                        if topPoints.count >= 2 {
                            path.move(to: topPoints[0])

                            for point in topPoints.dropFirst() {
                                path.addLine(to: point)
                            }

                            for point in bottomPoints.reversed() {
                                path.addLine(to: point)
                            }

                            path.closeSubpath()
                        }
                    }
                    .fill(Color.insulin.opacity(0.4))
                    .blur(radius: 5)
                }
            }
        }
    }

    private func positiveActivityFillPath() -> Path {
        Path { path in
            guard geom.activityDots.count >= 2 else { return }
            guard let zeroY = geom.activityZeroPointY else { return }

            var hasPositiveValues = false

            for i in 0 ..< geom.activityDots.count {
                let point = geom.activityDots[i]

                if point.y < zeroY {
                    if !hasPositiveValues {
                        // Start a new positive section
                        path.move(to: CGPoint(x: point.x, y: zeroY))
                        hasPositiveValues = true
                    }
                    path.addLine(to: point)
                } else if hasPositiveValues {
                    // End the positive section
                    path.addLine(to: CGPoint(x: point.x, y: zeroY))
                    path.closeSubpath()
                    hasPositiveValues = false
                }
            }

            // Close final positive section if needed
            if hasPositiveValues {
                let lastPoint = geom.activityDots.last!
                path.addLine(to: CGPoint(x: lastPoint.x, y: zeroY))
                path.closeSubpath()
            }
        }
    }

    private func negativeActivityFillPath() -> Path {
        Path { path in
            guard geom.activityDots.count >= 2 else { return }
            guard let zeroY = geom.activityZeroPointY else { return }

            var hasNegativeValues = false

            for i in 0 ..< geom.activityDots.count {
                let point = geom.activityDots[i]

                if point.y > zeroY {
                    if !hasNegativeValues {
                        // Start a new negative section
                        path.move(to: CGPoint(x: point.x, y: zeroY))
                        hasNegativeValues = true
                    }
                    path.addLine(to: point)
                } else if hasNegativeValues {
                    // End the negative section
                    path.addLine(to: CGPoint(x: point.x, y: zeroY))
                    path.closeSubpath()
                    hasNegativeValues = false
                }
            }

            // Close final negative section if needed
            if hasNegativeValues {
                let lastPoint = geom.activityDots.last!
                path.addLine(to: CGPoint(x: lastPoint.x, y: zeroY))
                path.closeSubpath()
            }
        }
    }

    private func activityStrokePath() -> Path {
        Path { path in
            guard geom.activityDots.count >= 2 else { return }
            path.move(to: geom.activityDots[0])
            for point in geom.activityDots.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    /* private var cobView: some View {
         ZStack {
             cobStrokePath(closed: true)
                 .fill(Color.loopYellow.opacity(0.3))
             cobStrokePath(closed: false)
                 .stroke(
                     colorScheme == .light ? Color.brown : Color.loopYellow,
                     style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                 )
         }
     }*/

    // COB Wolke

    private var cobView: some View {
        ZStack {
            Path { path in
                let dots = geom.glucoseDots
                let cob = geom.cobDots

                // Wir brauchen beide Datensätze
                guard dots.count >= 2, cob.count >= 2 else { return }

                var topPoints: [CGPoint] = []
                var bottomPoints: [CGPoint] = []

                for i in 0 ..< cob.count {
                    let cPoint = cob[i].0 // X/Y Koordinate aus den berechneten Geometrien

                    // Finde den Glukosepunkt, der zeitlich (X-Achse) am nächsten liegt
                    if let closestGlucose = dots.min(by: { abs($0.rect.midX - cPoint.x) < abs($1.rect.midX - cPoint.x) }) {
                        let glucoseY = closestGlucose.rect.midY

                        // Wir berechnen die Stärke (Tiefe) der Wolke
                        let cobValue = cob[i].1.cob
                        let depth = min(CGFloat(cobValue) * 1.5, 40) // Max 40px tief

                        topPoints.append(CGPoint(x: cPoint.x, y: glucoseY))
                        bottomPoints.append(CGPoint(x: cPoint.x, y: glucoseY + depth))
                    }
                }

                if let first = topPoints.first {
                    path.move(to: first)
                    for p in topPoints { path.addLine(to: p) }
                    for p in bottomPoints.reversed() { path.addLine(to: p) }
                    path.closeSubpath()
                }
            }
            .fill(Color.loopYellow.opacity(0.5))
            .blur(radius: 6)
        }
    }

    private func cobStrokePath(closed: Bool) -> Path {
        Path { path in
            guard let cobZeroPointY = geom.cobZeroPointY else { return }
            var isDrawing = false

            for (point, cob) in geom.cobDots.reversed() {
                if cob.cob > 0 {
                    if !isDrawing {
                        if closed {
                            path.move(to: CGPoint(x: point.x, y: cobZeroPointY))
                            path.addLine(to: point)
                        } else {
                            path.move(to: point)
                        }
                        isDrawing = true
                    } else {
                        path.addLine(to: point)
                    }
                } else {
                    if isDrawing {
                        path.addLine(to: point)
                        isDrawing = false
                    }
                }
            }

            if closed {
                if isDrawing, let (latest, _) = geom.cobDots.first {
                    path.addLine(to: CGPoint(x: latest.x, y: cobZeroPointY))
                }
            }
        }
    }

    private var connectingGlucoseLinesView: some View {
        Path { path in
            var lines: [CGPoint] = []
            for rect in geom.glucoseDots {
                lines.append(CGPoint(x: rect.rect.midX, y: rect.rect.midY))
            }
            path.addLines(lines)
        }
        .stroke(Color.primary, lineWidth: 0.25)
    }

    private var manualGlucoseView: some View {
        Path { path in
            for rect in geom.manualGlucoseDots {
                path.addEllipse(in: rect)
            }
        }
        .fill(Color.gray)
    }

    private var announcementView: some View {
        ZStack {
            ForEach(geom.announcementDots, id: \.rect.minX) { info -> AnyView in
                let position = CGPoint(x: info.rect.midX, y: info.rect.maxY - ChartConfig.owlOffset)
                let command = info.note.lowercased()
                let type: String =
                    command.contains("true") ?
                    Command.closed :
                    command.contains("false") ?
                    Command.open :
                    command.contains("suspend") ?
                    Command.suspend :
                    command.contains("resume") ?
                    Command.resume :
                    command.contains("tempbasal") ?
                    Command.tempbasal :
                    command.contains("override") ?
                    Command.override :
                    command.contains("meal") ?
                    Command.meal :
                    command.contains("bolus") ?
                    Command.bolus : ""

                Text(type).font(.announcementSymbolFont).foregroundStyle(.orange)
                    .offset(x: 0, y: -15)
                    .position(position).asAny()
            }
        }
    }

    private var manualGlucoseCenterView: some View {
        Path { path in
            for rect in geom.manualGlucoseDotsCenter {
                path.addEllipse(in: rect)
            }
        }
        .fill(Color.red)
    }

    private var unSmoothedGlucoseView: some View {
        Path { path in
            var lines: [CGPoint] = []
            for rect in geom.unSmoothedGlucoseDots {
                lines.append(CGPoint(x: rect.midX, y: rect.midY))
                path.addEllipse(in: rect)
            }
            path.addLines(lines)
        }
        .stroke(Color.secondary, lineWidth: 0.5)
    }

    // Insulin Tropfen

    /* private var bolusView: some View {
         ZStack {
             ForEach(geom.bolusDots, id: \.rect.minX) { info in
                 //  Minimum von 6 und ein Maximum von 25, damit es lesbar bleibt
                 let dynamicSize = min(max(info.rect.width * 1.5, 6), 25)

                 let position = CGPoint(
                     x: info.rect.midX,
                     y: info.rect.minY - (dynamicSize + 5)
                 ) // Bolus Tropfen über der Glucose Linie

                 VStack(spacing: 2) {
                     if let string = info.text {
                         Text(string)
                             //  .font(.system(size: 10, weight: .bold))
                             .font(.system(size: 14))
                             .foregroundColor(.primary)
                     }
                       Image(systemName: "drop.fill")
                      .font(.system(size: dynamicSize)) // Dynamische Größe
                      .foregroundColor(colorScheme == .dark ? Color.insulin.opacity(0.9) : Color.insulin)
                 }
                 .position(position)
             }
         }
     }*/

    private var bolusView: some View {
        ZStack {
            ForEach(geom.bolusDots, id: \.rect.minX) { info in
                let amount = Double(truncating: info.value as NSNumber)
                let dampedSize = ChartConfig.bolusSize + CGFloat(sqrt(amount)) * ChartConfig.bolusScale * 1.5
                let dynamicSize = min(max(dampedSize, ChartConfig.bolusSize), ChartConfig.maxBolusSize)

                VStack(spacing: 4) {
                    if let string = info.text {
                        Text(string)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Group {
                                    if colorScheme == .light {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(colorScheme == .dark ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 0.5)
                            )
                    }

                    ModernBolusDrop(size: dynamicSize)
                }
                .position(x: info.rect.midX, y: info.rect.minY - (dynamicSize * 0.8 + 10))
            }
        }
    }

    // Messer und Gabel
    private var carbsView: some View {
        ZStack {
            ForEach(geom.carbsDots, id: \.rect.minX) { info in
                let dynamicSize = min(max(info.rect.width * 1.2, 18), 35)
                let abstandZurLinie: CGFloat = 10

                VStack(spacing: 2) {
                    HStack(spacing: 1) {
                        Image(systemName: "fork.knife")
                            .symbolVariant(.fill)
                    }
                    .font(.system(size: dynamicSize, weight: .semibold))
                    .foregroundColor(.orange)

                    if let string = info.text {
                        Text(string)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Group {
                                    if colorScheme == .light {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white)
                                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(colorScheme == .dark ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 0.6)
                            )
                    }
                }
                .frame(width: 50, height: 60, alignment: .top)
                .position(x: info.rect.midX, y: info.rect.minY + abstandZurLinie + 30)
            }
        }
    }

    private var fpuView: some View {
        ZStack {
            let fpuPath = geom.fpuPath
            fpuPath.fill(data.useCarbBars ? .clear : Color.loopYellow)
            fpuPath.stroke(data.useCarbBars ? Color.loopYellow : Color.primary, lineWidth: data.useCarbBars ? 1.5 : 0.3)

            if data.useCarbBars, data.fpuAmounts {
                ForEach(geom.fpuDots, id: \.rect.minX) { info in
                    if let string = info.text, let textRect = info.textRect {
                        let position = textRect.origin
                        Text(string)
                            .rotationEffect(Angle(degrees: -90))
                            .font(geom.bolusFont)
                            .position(position)
                    }
                }
            } else if data.fpuAmounts {
                ForEach(geom.fpuDots, id: \.rect.minX) { info in
                    if let string = info.text, let textRect = info.textRect {
                        let position = textRect.origin
                        Text(string)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .position(position)
                    }
                }
            }
        }
    }

    private var tempTargetsView: some View {
        ZStack {
            geom.tempTargetsPath
                .fill(Color.tempBasal.opacity(0.5))
            geom.tempTargetsPath
                .stroke(Color.basal.opacity(0.5), lineWidth: 1)
        }
    }

    private var overridesView: some View {
        ZStack {
            geom.overridesPath
                .fill(Color.violet.opacity(colorScheme == .light ? 0.3 : 0.6))
            geom.overridesPath
                .stroke(Color.violet.opacity(0.7), lineWidth: 1)
        }
    }

    /*  private var predictionsView: some View {
         Group {
             Path { path in
                 for rect in geom.predictionDotsIOB {
                     path.addEllipse(in: rect)
                 }
             }.fill(Color.insulin.opacity(colorScheme == .dark ? 0.8 : 0.9))

             Path { path in
                 for rect in geom.predictionDotsCOB {
                     path.addEllipse(in: rect)
                 }
             }.fill(Color.loopYellow.opacity(colorScheme == .dark ? 0.8 : 0.9))

             Path { path in
                 for rect in geom.predictionDotsZT {
                     path.addEllipse(in: rect)
                 }
             }.fill(Color.zt.opacity(colorScheme == .dark ? 0.8 : 0.9))

             Path { path in
                 for rect in geom.predictionDotsUAM {
                     path.addEllipse(in: rect)
                 }
             }.fill(Color.uam.opacity(colorScheme == .dark ? 0.8 : 0.9))
         }
     }*/
    @ViewBuilder private func predictionArea(dots: [CGRect], color: Color) -> some View {
        let points = dots.map { CGPoint(x: $0.midX, y: $0.midY) }
        if !points.isEmpty {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                // Wir schließen den Pfad nach unten zum Boden des Charts ab
                if let last = points.last {
                    path.addLine(to: CGPoint(x: last.x, y: geom.fullSize.height - 20))
                    path.addLine(to: CGPoint(x: first.x, y: geom.fullSize.height - 20))
                    path.closeSubpath()
                }
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.15), color.opacity(0.0)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var predictionsView: some View {
        ZStack {
            // 1. Die gefüllten Flächen im Hintergrund
            predictionArea(dots: geom.predictionDotsIOB, color: .insulin)
            predictionArea(dots: geom.predictionDotsCOB, color: .loopYellow)
            predictionArea(dots: geom.predictionDotsZT, color: .zt)
            predictionArea(dots: geom.predictionDotsUAM, color: .uam)

            // 2. Die gestrichelten Linien darüber für die Kontur
            Group {
                predictionLine(dots: geom.predictionDotsIOB, color: .insulin)
                predictionLine(dots: geom.predictionDotsCOB, color: .loopYellow)
                predictionLine(dots: geom.predictionDotsZT, color: .zt)
                predictionLine(dots: geom.predictionDotsUAM, color: .uam)
            }
        }
    }

    // Hilfsfunktion für die Linien (um die predictionsView sauber zu halten)
    @ViewBuilder private func predictionLine(dots: [CGRect], color: Color) -> some View {
        let points = dots.map { CGPoint(x: $0.midX, y: $0.midY) }
        if !points.isEmpty {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 5]))
        }
    }
}
