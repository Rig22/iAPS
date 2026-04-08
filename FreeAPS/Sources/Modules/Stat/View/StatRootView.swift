import Charts
import CoreData
import SwiftDate
import SwiftUI
import Swinject

extension Stat {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel
        @Environment(\.colorScheme) var colorScheme

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var body: some View {
            VStack(spacing: 0) {
                // Top category picker
                Picker("View", selection: $state.selectedView) {
                    ForEach(StatisticViewType.allCases) { viewType in
                        Text(viewType.displayName).tag(viewType)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 6)

                ScrollView {
                    VStack(spacing: 16) {
                        switch state.selectedView {
                        case .glucose:
                            glucoseView
                        case .insulin:
                            insulinView
                        case .looping:
                            loopingView
                        case .meals:
                            mealsView
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .navigationBarTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
        }

        // MARK: - Glucose

        @ViewBuilder var glucoseView: some View {
            // Duration picker
            Picker("Duration", selection: $state.selectedIntervalForGlucoseStats) {
                ForEach(StatsTimeIntervalWithToday.allCases) { interval in
                    Text(interval.displayName)
                }
            }.pickerStyle(.segmented)

            let filter = state.filterDate(for: state.selectedIntervalForGlucoseStats)

            glucoseScatterCard(filter: filter)
            glucoseOverviewCard(filter: filter)
        }

        private func glucoseOverviewCard(filter: NSDate) -> some View {
            GlucoseOverviewCard(
                filter: filter,
                highLimit: state.highLimit,
                lowLimit: state.lowLimit,
                units: state.units,
                overrideUnit: state.overrideUnit
            )
        }

        private func glucoseScatterCard(filter: NSDate) -> some View {
            GlucoseScatterCard(
                filter: filter,
                highLimit: state.highLimit,
                lowLimit: state.lowLimit,
                units: state.units,
                selectedInterval: state.selectedIntervalForGlucoseStats
            )
        }

        // MARK: - Insulin

        @ViewBuilder var insulinView: some View {
            HStack {
                Text("Chart Type")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer()
                Picker("Insulin Chart Type", selection: $state.selectedInsulinChartType) {
                    ForEach(InsulinChartType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }.padding(.horizontal)

            Picker("Duration", selection: $state.selectedIntervalForInsulinStats) {
                ForEach(StatsTimeInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }.pickerStyle(.segmented)

            insulinChartCard
            insulinSummaryCard
        }

        @ViewBuilder private var insulinSummaryCard: some View {
            StatCard {
                InsulinStatsTileView(
                    neg: state.neg,
                    tddChange: state.tddChange,
                    tddAverage: state.tddAverage,
                    tddYesterday: state.tddYesterday,
                    tdd2DaysAgo: state.tdd2DaysAgo,
                    tdd3DaysAgo: state.tdd3DaysAgo,
                    tddActualAverage: state.tddActualAverage
                )
            }
        }

        @ViewBuilder private var insulinChartCard: some View {
            StatCard {
                switch state.selectedInsulinChartType {
                case .totalDailyDose:
                    let tddData = state.selectedIntervalForInsulinStats == .day ?
                        state.hourlyTDDStats : state.filteredDailyTDDStats
                    if tddData.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("No TDD Data", comment: ""),
                            systemImage: "chart.bar.xaxis",
                            description: Text("Total Daily Doses will appear here once data is available.")
                        )
                    } else {
                        TotalDailyDoseChart(
                            selectedInterval: $state.selectedIntervalForInsulinStats,
                            tddStats: tddData
                        )
                    }

                case .bolusDistribution:
                    let bolusData = state.selectedIntervalForInsulinStats == .day ?
                        state.hourlyBolusStats : state.filteredDailyBolusStats
                    let hasData = bolusData.contains { $0.manualBolus > 0 || $0.external > 0 }
                    if bolusData.isEmpty || !hasData {
                        ContentUnavailableView(
                            NSLocalizedString("No Bolus Data", comment: ""),
                            systemImage: "cross.vial",
                            description: Text("Bolus statistics will appear here once data is available.")
                        )
                    } else {
                        BolusStatsView(
                            selectedInterval: $state.selectedIntervalForInsulinStats,
                            bolusStats: bolusData
                        )
                    }
                }
            }
        }

        // MARK: - Looping

        @ViewBuilder var loopingView: some View {
            Picker("Duration", selection: $state.selectedIntervalForLoopStats) {
                ForEach(StatsTimeIntervalWithToday.allCases) { interval in
                    Text(interval.displayName)
                }
            }.pickerStyle(.segmented)

            let filter = state.filterDate(for: state.selectedIntervalForLoopStats)
            LoopingCard(filter: filter, selectedInterval: state.selectedIntervalForLoopStats)
        }

        // MARK: - Meals

        @ViewBuilder var mealsView: some View {
            Picker("Duration", selection: $state.selectedIntervalForMealStats) {
                ForEach(StatsTimeInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }.pickerStyle(.segmented)

            let mealData = state.selectedIntervalForMealStats == .day ?
                state.hourlyMealStats : state.filteredDailyMealStats
            let hasData = mealData.contains { $0.carbs > 0 || $0.fat > 0 || $0.protein > 0 }

            StatCard {
                if mealData.isEmpty || !hasData {
                    ContentUnavailableView(
                        NSLocalizedString("No Meal Data", comment: ""),
                        systemImage: "fork.knife",
                        description: Text("Meal statistics will appear here once data is available.")
                    )
                } else {
                    MealStatsView(
                        selectedInterval: $state.selectedIntervalForMealStats,
                        mealStats: mealData
                    )
                }
            }

            // Macro distribution donut card
            if hasData {
                let totalCarbs = mealData.map(\.carbs).reduce(0, +)
                let totalFat = mealData.map(\.fat).reduce(0, +)
                let totalProtein = mealData.map(\.protein).reduce(0, +)
                let hasFatProtein = totalFat > 0 || totalProtein > 0
                if hasFatProtein, (totalCarbs + totalFat + totalProtein) > 0 {
                    let interval = state.selectedIntervalForMealStats
                    let daysCount: Int = {
                        switch interval {
                        case .day: return 1
                        case .week: return 7
                        case .month: return 30
                        case .total: return 90
                        }
                    }()
                    StatCard {
                        MacroDistributionDonut(
                            carbs: totalCarbs,
                            fat: totalFat,
                            protein: totalProtein,
                            daysCount: daysCount,
                            showAverage: interval != .day
                        )
                    }
                }
            }
        }
    }
}

// MARK: - StatCard Container

struct StatCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .elegantShadow(scheme: colorScheme)
    }
}

// MARK: - Glucose Overview Card (Donut + Metrics)

private struct GlucoseOverviewCard: View {
    @FetchRequest var fetchRequest: FetchedResults<Readings>

    let highLimit: Decimal
    let lowLimit: Decimal
    let units: GlucoseUnits
    let overrideUnit: Bool

    init(filter: NSDate, highLimit: Decimal, lowLimit: Decimal, units: GlucoseUnits, overrideUnit: Bool) {
        _fetchRequest = FetchRequest<Readings>(
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
            predicate: NSPredicate(format: "glucose > 0 AND date > %@", filter)
        )
        self.highLimit = highLimit
        self.lowLimit = lowLimit
        self.units = units
        self.overrideUnit = overrideUnit
    }

    var body: some View {
        if fetchRequest.isEmpty {
            StatCard {
                ContentUnavailableView(
                    NSLocalizedString("No Glucose Data", comment: ""),
                    systemImage: "chart.bar.fill",
                    description: Text("Glucose statistics will appear here once data is available.")
                )
            }
        } else {
            StatCard {
                VStack(spacing: 16) {
                    GlucoseSectorChart(
                        highLimit: highLimit,
                        lowLimit: lowLimit,
                        units: units,
                        glucose: fetchRequest,
                        showChart: true
                    )

                    Divider()

                    GlucoseMetricsView(
                        units: units,
                        overrideUnit: overrideUnit,
                        glucose: fetchRequest
                    )
                }
            }

            // Hint
            HStack {
                Image(systemName: "hand.draw.fill").foregroundStyle(.primary)
                Text("Tap and hold the ring chart to reveal more details.")
                    .foregroundStyle(.secondary)
            }.font(.footnote)
        }
    }
}

// MARK: - Glucose Scatter Card

private struct GlucoseScatterCard: View {
    @FetchRequest var fetchRequest: FetchedResults<Readings>

    let highLimit: Decimal
    let lowLimit: Decimal
    let units: GlucoseUnits
    let selectedInterval: StatsTimeIntervalWithToday

    private let conversionFactor = 0.0555

    init(
        filter: NSDate,
        highLimit: Decimal,
        lowLimit: Decimal,
        units: GlucoseUnits,
        selectedInterval: StatsTimeIntervalWithToday = .today
    ) {
        _fetchRequest = FetchRequest<Readings>(
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
            predicate: NSPredicate(format: "glucose > 0 AND date > %@", filter)
        )
        self.highLimit = highLimit
        self.lowLimit = lowLimit
        self.units = units
        self.selectedInterval = selectedInterval
    }

    private var visibleDomainLength: TimeInterval {
        switch selectedInterval {
        case .day,
             .today: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .total: return 90 * 24 * 3600
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedInterval {
        case .day,
             .today: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day().month(.abbreviated)
        case .total: return .dateTime.day().month(.abbreviated)
        }
    }

    private var scrollWindowLength: TimeInterval {
        switch selectedInterval {
        case .day,
             .today: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 7 * 24 * 3600 // 1 Woche sichtbar, Rest scrollen
        case .total: return 14 * 24 * 3600 // 2 Wochen sichtbar, Rest scrollen
        }
    }

    var body: some View {
        let low = lowLimit * (units == .mmolL ? Decimal(conversionFactor) : 1)
        let high = highLimit * (units == .mmolL ? Decimal(conversionFactor) : 1)
        let readings = fetchRequest
        let count = readings.count
        let sizeOfDataPoints: CGFloat = count < 20 ? 50 : count < 50 ? 35 : count > 2000 ? 5 : 15

        let needsScroll = selectedInterval == .month || selectedInterval == .total

        // Fixed threshold values (180 mg/dL and 70 mg/dL) converted to display units
        let highThreshold: Double = units == .mmolL ? 180 * conversionFactor : 180
        let lowThreshold: Double = units == .mmolL ? 70 * conversionFactor : 70
        let highThresholdLabel = units == .mmolL ? "10.0 mmol/L" : "180 mg/dL"
        let lowThresholdLabel = units == .mmolL ? "3.9 mmol/L" : "70 mg/dL"

        StatCard {
            VStack(spacing: 12) {
                Chart {
                    // Fixed threshold lines
                    RuleMark(y: .value("High Threshold", highThreshold))
                        .foregroundStyle(.yellow)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    RuleMark(y: .value("Low Threshold", lowThreshold))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    ForEach(readings.filter({ $0.glucose > Int(highLimit) }), id: \.date) { item in
                        PointMark(
                            x: .value("Date", item.date ?? Date()),
                            y: .value("High", Double(item.glucose) * (units == .mmolL ? conversionFactor : 1))
                        )
                        .foregroundStyle(.orange)
                        .symbolSize(sizeOfDataPoints)
                    }
                    ForEach(
                        readings.filter({ $0.glucose >= Int(lowLimit) && $0.glucose <= Int(highLimit) }),
                        id: \.date
                    ) { item in
                        PointMark(
                            x: .value("Date", item.date ?? Date()),
                            y: .value("In Range", Double(item.glucose) * (units == .mmolL ? conversionFactor : 1))
                        )
                        .foregroundStyle(.green)
                        .symbolSize(sizeOfDataPoints)
                    }
                    ForEach(readings.filter({ $0.glucose < Int(lowLimit) }), id: \.date) { item in
                        PointMark(
                            x: .value("Date", item.date ?? Date()),
                            y: .value("Low", Double(item.glucose) * (units == .mmolL ? conversionFactor : 1))
                        )
                        .foregroundStyle(.red)
                        .symbolSize(sizeOfDataPoints)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(format: xAxisFormat)
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, low, high, units == .mmolL ? 15 : 270])
                }
                .if(needsScroll) { chart in
                    chart
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: scrollWindowLength)
                }
                .frame(height: 200)

                // Legend
                ScatterLegend(
                    highThresholdLabel: highThresholdLabel,
                    lowThresholdLabel: lowThresholdLabel
                )

                if needsScroll {
                    HStack {
                        Image(systemName: "hand.draw.fill").foregroundStyle(.primary)
                        Text("Swipe to scroll through time.")
                            .foregroundStyle(.secondary)
                    }.font(.footnote)
                }
            }
        }
    }
}

// MARK: - Scatter Legend

private struct ScatterLegend: View {
    let highThresholdLabel: String
    let lowThresholdLabel: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                legendDot(color: .red, label: NSLocalizedString("Low", comment: ""))
                legendDot(color: .green, label: NSLocalizedString("In Range", comment: ""))
                legendDot(color: .orange, label: NSLocalizedString("High", comment: ""))
            }
            HStack(spacing: 14) {
                legendLine(color: .red, label: lowThresholdLabel)
                legendLine(color: .yellow, label: highThresholdLabel)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func legendLine(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 16, height: 2)
            }
            Text(label)
        }
    }
}

// MARK: - Conditional View Modifier

private extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
