import ActivityKit
import Charts
import SwiftUI
import WidgetKit

private enum Size {
    case minimal
    case compact
    case expanded
}

struct LiveActivity: Widget {
    private let dateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private let minuteFormatter: NumberFormatter = {
        var formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    @Environment(\.dynamicTypeSize) private var fontSize

    @ViewBuilder private func changeLabel(context: ActivityViewContext<LiveActivityAttributes>) -> some View {
        if !context.state.change.isEmpty {
            if !context.isStale {
                Text(context.state.change)
            } else {
                Text("old").foregroundStyle(.secondary)
            }
        } else {
            Text("--")
        }
    }

    private func updatedLabel(context: ActivityViewContext<LiveActivityAttributes>) -> Text {
        let text = Text("\(dateFormatter.string(from: context.state.loopDate))")
        return text
    }

    private func bgAndTrend(context: ActivityViewContext<LiveActivityAttributes>, size: Size) -> (some View, Int) {
        var characters = 0

        let bgText = context.state.bg
        characters += bgText.count

        // narrow mode is for the minimal dynamic island view
        // there is not enough space to show all three arrow there
        // and everything has to be squeezed together to some degree
        // only display the first arrow character and make it red in case there were more characters
        var directionText: String?
        var warnColor: Color?
        if let direction = context.state.direction {
            if size == .compact {
                directionText = String(direction[direction.startIndex ... direction.startIndex])

                if direction.count > 1 {
                    warnColor = Color.red
                }
            } else {
                directionText = direction
            }

            characters += directionText!.count
        }

        let spacing: CGFloat
        switch size {
        case .minimal: spacing = -1
        case .compact: spacing = 0
        case .expanded: spacing = 3
        }

        let stack = HStack(spacing: spacing) {
            Text(bgText)

            if let direction = directionText {
                let text = Text(direction)
                switch size {
                case .minimal:
                    let scaledText = text.scaleEffect(x: 0.7, y: 0.7, anchor: .leading)
                    if let warnColor {
                        scaledText.foregroundStyle(warnColor)
                    } else {
                        scaledText
                    }
                case .compact:
                    text.scaleEffect(x: 0.8, y: 0.8, anchor: .leading).padding(.trailing, -3)

                case .expanded:
                    text.scaleEffect(x: 0.7, y: 0.7, anchor: .center).padding(.trailing, -5)
                }
            }
        }
        .foregroundStyle(context.isStale ? .secondary : Color.primary)

        return (stack, characters)
    }

    private func iob(context: ActivityViewContext<LiveActivityAttributes>, size _: Size) -> some View {
        HStack(spacing: 0) {
            Text(context.state.iob)
            Text(" U").opacity(0.7).scaleEffect(0.8)
        }
        .foregroundStyle(Color.blue)
    }

    private func cob(context: ActivityViewContext<LiveActivityAttributes>, size _: Size) -> some View {
        HStack(spacing: 0) {
            Text(context.state.cob)
            Text(" g").opacity(0.7).scaleEffect(0.8)
        }
        .foregroundStyle(Color.yellow)
    }

    private func loop(context: ActivityViewContext<LiveActivityAttributes>, size: CGFloat) -> some View {
        let timeAgo = abs(context.state.loopDate.timeIntervalSinceNow) / 60
        let color: Color = timeAgo > 8 ? Color.yellow : timeAgo > 12 ? Color.red : Color.green
        return LoopActivity(stroke: color, compact: size == 12).frame(width: size)
    }

    private var emptyText: some View {
        Text(" ").font(.caption).offset(x: 0, y: -5)
    }

    private static let eventualSymbol = "⇢"
//    private static let eventualSymbol = "⌖"
//    private static let eventualSymbol = "◎"
//    private static let eventualSymbol = "⊙"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack(spacing: 2) {
                if !context.state.showChart {
                    ZStack {
                        updatedLabel(context: context).font(.caption).foregroundStyle(.primary.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                HStack {
                    /*   let loopCircle =
                         VStack {
                             loop(context: context, size: 22)
                             if !context.state.showChart {
                                 emptyText
                             }
                         }
                     if !context.state.showChart {
                         loopCircle.offset(x: 0, y: 2)
                     } else {
                         loopCircle
                     }
                     Spacer()*/
                    /*     VStack {
                         bgAndTrend(context: context, size: .expanded).0.font(.title)
                         if !context.state.showChart {
                             changeLabel(context: context).font(.caption).foregroundStyle(.primary.opacity(0.7))
                                 .offset(x: -12, y: -5)
                         }
                     }
                     Spacer()*/
                    VStack {
                        iob(context: context, size: .expanded).font(.title)
                        if !context.state.showChart {
                            emptyText
                        }
                    }
                    Spacer()
                    VStack {
                        cob(context: context, size: .expanded).font(.title)
                        if !context.state.showChart {
                            emptyText
                        }
                    }
                    Spacer()
                    VStack {
                        let loopCircle =
                            VStack {
                                loop(context: context, size: 22)
                                if !context.state.showChart {
                                    emptyText
                                }
                            }
                        if !context.state.showChart {
                            loopCircle.offset(x: 0, y: 2)
                        } else {
                            loopCircle
                        }
                    }
                    Spacer()
                    VStack {
                        bgAndTrend(context: context, size: .expanded).0.font(.title)
                        if !context.state.showChart {
                            changeLabel(context: context).font(.caption).foregroundStyle(.primary.opacity(0.7))
                                .offset(x: -12, y: -5)
                        }
                    }
                }

                if context.state.showChart {
                    HStack(alignment: .top) {
                        chartView(for: context.state)
                        Spacer()
                        VStack(spacing: -2) {
                            Text(LiveActivity.eventualSymbol)
                                .foregroundStyle(.secondary)
                                //                            .opacity(0.7)
                                .font(.system(size: UIFont.systemFontSize * 1.5))
                            Text(context.state.eventual)
                            Spacer()
                            updatedLabel(context: context).font(.caption).foregroundStyle(.primary.opacity(0.7))
                        }
                    }
                }
                if !context.state.showChart {
                    HStack {
                        Spacer()
                        if context.state.eventualText {
                            Text(NSLocalizedString("Eventual Glucose", comment: ""))
                            Spacer()
                        } else {
                            Text("⇢").foregroundStyle(.secondary).font(.system(size: UIFont.systemFontSize * 1.8))
                        }
                        Text(context.state.eventual)
                        Text(context.state.mmol ? NSLocalizedString(
                            "mmol/L",
                            comment: "The short unit display string for millimoles of glucose per liter"
                        ) : NSLocalizedString(
                            "mg/dL",
                            comment: "The short unit display string for milligrams of glucose per decilter"
                        ))
                            .foregroundStyle(.secondary)
                    }

                    .padding(.top, context.state.showChart ? 0 : 10)
                }
            }
            .privacySensitive()
            .padding(.vertical, 10).padding(.horizontal, 15)
            // Semantic BackgroundStyle and Color values work here. They adapt to the given interface style (light mode, dark mode)
            // Semantic UIColors do NOT (as of iOS 17.1.1). Like UIColor.systemBackgroundColor (it does not adapt to changes of the interface style)
            // The colorScheme environment varaible that is usually used to detect dark mode does NOT work here (it reports false values)
            .foregroundStyle(Color.primary)
            .background(BackgroundStyle.background.opacity(0.4))
            .activityBackgroundTint(Color.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        loop(context: context, size: 23)
                    }.padding(10)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        HStack {
                            iob(context: context, size: .expanded).font(.title2).padding(.leading, 10)
                            Spacer()
                            cob(context: context, size: .expanded).font(.title2).padding(10)
                        }
                        HStack {
                            bgAndTrend(context: context, size: .expanded).0.font(.title2).padding(.leading, 10)
                            Spacer()
                            changeLabel(context: context).font(.title2).padding(10)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    updatedLabel(context: context).font(.caption).foregroundStyle(Color.secondary)
                        .padding(.trailing, 10)
                }
                DynamicIslandExpandedRegion(.bottom) {}
            } compactLeading: {
                HStack {
                    loop(context: context, size: 12)
                    bgAndTrend(context: context, size: .compact).0.padding(.leading, 4)
                }
            } compactTrailing: {
                changeLabel(context: context).padding(.trailing, 4)
            } minimal: {
                let (_label, characterCount) = bgAndTrend(context: context, size: .minimal)

                let label = _label.padding(.leading, 7).padding(.trailing, 3)

                if characterCount < 4 {
                    label
                } else if characterCount < 5 {
                    label.fontWidth(.condensed)
                } else {
                    label.fontWidth(.compressed)
                }
            }
            .widgetURL(URL(string: "freeaps-x://"))
            // .keylineTint(Color.purple)
            .contentMargins(.horizontal, 0, for: .minimal)
            .contentMargins(.trailing, 0, for: .compactLeading)
            .contentMargins(.leading, 0, for: .compactTrailing)
        }
    }

    private func displayValues(_ values: [Int16], mmol: Bool) -> [Double] {
        values.map {
            mmol ?
                Double($0) * 0.0555 :
                Double($0)
        }
    }

    private func createYScale(
        _ state: LiveActivityAttributes.ContentState,
        _ maxValue: Double?,
        _ maxThreshold: Int16?
    ) -> ClosedRange<Double> {
        let minValue = state.mmol ? 54 * 0.0555 : 54
        let maxThresholdDouble = maxThreshold.map { Double($0) } ?? 180
        let maxThresholdDoubleConverted =
            state.mmol ? maxThresholdDouble * 0.0555 : maxThresholdDouble

        let maxDataOrThreshold: Double

        if let maxValue, maxValue > maxThresholdDoubleConverted {
            maxDataOrThreshold = maxValue
        } else {
            maxDataOrThreshold = maxThresholdDoubleConverted
        }

        if let settingsMaxValue = state.chartMaxValue {
            let settingsMaxDouble = Double(settingsMaxValue)
            let settingsMaxDoubleConverted = state.mmol ? settingsMaxDouble * 0.0555 : settingsMaxDouble

            if settingsMaxDoubleConverted > maxDataOrThreshold {
                return Double(minValue) ... Double(settingsMaxDoubleConverted)
            } else {
                return Double(minValue) ... Double(maxDataOrThreshold)
            }
        } else {
            return Double(minValue) ... Double(maxDataOrThreshold)
        }
    }

    private func makePoints(_ dates: [Date], _ values: [Int16], mmol: Bool) -> [(date: Date, value: Double)] {
        zip(dates, displayValues(values, mmol: mmol)).map { ($0, $1) }
    }

    private func chartView(for state: LiveActivityAttributes.ContentState) -> some View {
        let readings = state.readings ?? LiveActivityAttributes.ValueSeries(dates: [], values: [])
        let dates = readings.dates
        let displayedValues = makePoints(dates, readings.values, mmol: state.mmol)

        var minValue = displayedValues.min { $0.value < $1.value }?.value
        var maxValue = displayedValues.max { $0.value < $1.value }?.value
        let minYMark = minValue
        let maxYMark = maxValue
        let haveReadings = minValue != nil && maxValue != nil

        var glucoseFormatter: FloatingPointFormatStyle<Double> {
            state.mmol ?
                .number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")) :
                .number.precision(.fractionLength(0))
        }

        func updateMinMax(_ values: [(date: Date, value: Double)]) -> [(date: Date, value: Double)] {
            let minHere = values.min { $0.value < $1.value }?.value ?? Double(0)
            let maxHere = values.max { $0.value < $1.value }?.value ?? Double(0)
            if let currMinValue = minValue, minHere < currMinValue { minValue = minHere }
            if let currMaxValue = maxValue, maxHere > currMaxValue { maxValue = maxHere }
            return values
        }

        return Chart {
            ForEach(displayedValues, id: \.date) {
                PointMark(
                    x: .value("Time", $0.date),
                    y: .value("Glucose", $0.value)
                )
                .symbolSize(20)
                .foregroundStyle(Color.green)
                LineMark(
                    x: .value("Time", $0.date),
                    y: .value("Glucose", $0.value)
                )
                .foregroundStyle(.green)
                .opacity(0.7)
                .lineStyle(StrokeStyle(lineWidth: 1.0))
            }

            if haveReadings, let iob = state.predictions?.iob.map({
                updateMinMax(makePoints($0.dates, $0.values, mmol: state.mmol))
            }) {
                ForEach(iob, id: \.date) { point in
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Glucose", point.value)
                    )
                    .symbolSize(10)
                    .foregroundStyle(Color.blue.opacity(0.5))
                }
            }
            if haveReadings, let zt = state.predictions?.zt.map({
                updateMinMax(makePoints($0.dates, $0.values, mmol: state.mmol))
            }) {
                ForEach(zt, id: \.date) { point in
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Glucose", point.value)
                    )
                    .symbolSize(10)
                    .foregroundStyle(Color.zt.opacity(0.5))
                }
            }
            if haveReadings, let cob = state.predictions?.cob.map({
                updateMinMax(makePoints($0.dates, $0.values, mmol: state.mmol))
            }) {
                ForEach(cob, id: \.date) { point in
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Glucose", point.value)
                    )
                    .symbolSize(10)
                    .foregroundStyle(Color.yellow.opacity(0.5))
                }
            }
            if haveReadings, let uam = state.predictions?.uam.map({
                updateMinMax(makePoints($0.dates, $0.values, mmol: state.mmol))
            }) {
                ForEach(uam, id: \.date) { point in
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Glucose", point.value)
                    )
                    .symbolSize(10)
                    .foregroundStyle(Color.uam.opacity(0.5))
                }
            }

            if let chartHighThreshold = state.chartHighThreshold {
                RuleMark(y: .value(
                    "High Threshold",
                    state.mmol ? Double(chartHighThreshold) * 0.0555 : Double(chartHighThreshold)
                ))
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 1]))
            }
            if let chartLowThreshold = state.chartLowThreshold {
                RuleMark(y: .value("Low Threshold", state.mmol ? Double(chartLowThreshold) * 0.0555 : Double(chartLowThreshold)))
                    .foregroundStyle(.red.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 1]))
            }

            RuleMark(x: .value("Now", Date.now))
                .foregroundStyle(.secondary.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 1]))
        }
        .chartYScale(domain: createYScale(state, maxValue, state.chartMaxValue))
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            if let minYMark, let maxYMark {
                AxisMarks(position: .trailing, values: [
                    minYMark,
                    maxYMark
                ]) { _ in
                    AxisGridLine()
                    AxisValueLabel(
                        format: glucoseFormatter
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private extension LiveActivityAttributes {
    static var preview: LiveActivityAttributes {
        LiveActivityAttributes(startDate: Date())
    }
}

private extension LiveActivityAttributes.ContentState {
    // 0 is the widest digit. Use this to get an upper bound on text width.

    // Use mmol/l notation with decimal point as well for the same reason, it uses up to 4 characters, while mg/dl uses up to 3
    static var testWide: LiveActivityAttributes.ContentState {
        let sampleData = SampleData()
        return LiveActivityAttributes.ContentState(
            bg: "10.7",
            direction: "→",
            change: "+0.1",
            date: Date(),
            iob: "1.2",
            cob: "20",
            loopDate: Date.now, eventual: "12.7", mmol: true,
            readings: sampleData.sampleReadings,
            predictions: sampleData.samplePredictions,
            showChart: true,
            chartLowThreshold: 75,
            chartHighThreshold: 200,
            chartMaxValue: 400,
            eventualText: false
        )
    }

    static var testVeryWide: LiveActivityAttributes.ContentState {
        let sampleData = SampleData()
        return LiveActivityAttributes.ContentState(
            bg: "10.7",
            direction: "↑↑",
            change: "+1.4",
            date: Date(),
            iob: "1.2",
            cob: "20",
            loopDate: Date.now, eventual: "12.7", mmol: true,
            readings: sampleData.sampleReadings,
            predictions: nil,
            showChart: true,
            chartLowThreshold: nil,
            chartHighThreshold: nil,
            chartMaxValue: 400,
            eventualText: true
        )
    }

    static var testSuperWide: LiveActivityAttributes.ContentState {
        let sampleData = SampleData()
        return LiveActivityAttributes.ContentState(
            bg: "10.7",
            direction: "↑↑↑",
            change: "+2.1",
            date: Date(),
            iob: "1.2",
            cob: "20",
            loopDate: Date.now, eventual: "12.7", mmol: true,
            readings: sampleData.sampleReadings,
            predictions: sampleData.samplePredictions,
            showChart: true,
            chartLowThreshold: 75,
            chartHighThreshold: 200,
            chartMaxValue: nil,
            eventualText: false
        )
    }

    // 2 characters for BG, 1 character for change is the minimum that will be shown
    static var testNarrow: LiveActivityAttributes.ContentState {
        let sampleData = SampleData()
        return LiveActivityAttributes.ContentState(
            bg: "10.7",
            direction: "↑",
            change: "+0.7",
            date: Date(),
            iob: "1.2",
            cob: "20",
            loopDate: Date.now, eventual: "12.7", mmol: true,
            readings: sampleData.sampleReadings,
            predictions: nil,
            showChart: false,
            chartLowThreshold: nil,
            chartHighThreshold: nil,
            chartMaxValue: nil,
            eventualText: true
        )
    }

    static var testMedium: LiveActivityAttributes.ContentState {
        let sampleData = SampleData()
        return LiveActivityAttributes.ContentState(
            bg: "10.7",
            direction: "↗︎",
            change: "+0.8",
            date: Date(),
            iob: "1.2",
            cob: "20",
            loopDate: Date.now, eventual: "12.7", mmol: true,
            readings: sampleData.sampleReadings,
            predictions: nil,
            showChart: true,
            chartLowThreshold: nil,
            chartHighThreshold: nil,
            chartMaxValue: nil,
            eventualText: true
        )
    }
}

struct SampleData {
    let sampleReadings: LiveActivityAttributes.ValueSeries = {
        let calendar = Calendar.current
        let now = Date()

        let dates = Array((0 ..< 2 * 12).map { minutesAgoX5 in
            calendar.date(byAdding: .minute, value: -minutesAgoX5 * 5, to: now)!
        }.reversed())

        var current: Int = 100 + Int.random(in: 0 ... 100)
        let values: [Int16] = Array((0 ..< 2 * 12).map { _ in
            current = current + Int.random(in: 10 ... 20) * Int.random(in: -50 ... 50).signum()
            if current < 100 {
                current = 100 + Int.random(in: 0 ... 10)
            }
            return Int16(clamping: current)
        }.reversed())

        return LiveActivityAttributes.ValueSeries(dates: dates, values: values)
    }()

    var samplePredictions: LiveActivityAttributes.ActivityPredictions {
        let lastGlucose = Double(sampleReadings.values.last!)
        let lastDate = sampleReadings.dates.last!

        let numberOfPoints = 2 * 60 / 5 // 2 hours with 5-minute steps

        // Helper function to generate a curve with some randomness
        func generateCurve(startValue: Double, pattern: String) -> LiveActivityAttributes.ValueSeries {
            var values: [Double] = []
            var currentValue = startValue

            let midpoint = Double(numberOfPoints) / 2

            for i in 0 ..< numberOfPoints {
                let noise = Double.random(in: -5 ... 5)
                switch pattern {
                case "up":
                    currentValue += Double.random(in: 5 ... 15) + noise
                    if currentValue > 400 {
                        currentValue = 400 - Double.random(in: 0 ... 15)
                    }
                case "down":
                    currentValue -= Double.random(in: 5 ... 15) + noise
                    if currentValue < 20 {
                        currentValue = 20 + Double.random(in: 0 ... 15)
                    }
                case "peak":
                    let distance = abs(Double(i) - midpoint)
                    let trend = distance < midpoint / 2 || currentValue > 300 ? -1.0 : 1.0
                    let delta = Double.random(in: 5 ... 20)
                    currentValue += delta * trend + noise
                default:
                    currentValue += noise
                }
                values.append(currentValue)
            }

            let dates = values.enumerated().map { index, _ in
                lastDate.addingTimeInterval(TimeInterval((index + 1) * 5 * 60))
            }

            return LiveActivityAttributes.ValueSeries(dates: dates, values: values.map {
                Int16(clamping: Int(round($0)))
            })
        }

        let iob = generateCurve(startValue: lastGlucose, pattern: "down")
        let zt = generateCurve(startValue: lastGlucose, pattern: "stable")
        let cob = generateCurve(startValue: lastGlucose, pattern: "peak")
        let uam = generateCurve(startValue: lastGlucose, pattern: "up")

        return LiveActivityAttributes.ActivityPredictions(
            iob: iob,
            zt: zt,
            cob: cob,
            uam: uam
        )
    }
}

extension Color {
    static let uam = Color("UAM")
    static let zt = Color("ZT")
}

@available(iOS 17.0, iOSApplicationExtension 17.0, *)
#Preview("Notification", as: .content, using: LiveActivityAttributes.preview) {
    LiveActivity()
} contentStates: {
    LiveActivityAttributes.ContentState.testSuperWide
    LiveActivityAttributes.ContentState.testVeryWide
    LiveActivityAttributes.ContentState.testWide
    LiveActivityAttributes.ContentState.testMedium
    LiveActivityAttributes.ContentState.testNarrow
}

struct LoopActivity: View {
    @Environment(\.colorScheme) var colorScheme
    let stroke: Color
    let compact: Bool
    var body: some View {
        Circle()
            .stroke(stroke, lineWidth: compact ? 1.5 : 3)
    }
}
