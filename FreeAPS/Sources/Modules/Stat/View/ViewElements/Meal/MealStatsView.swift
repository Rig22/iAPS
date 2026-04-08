import Charts
import SwiftUI

struct MealStatsView: View {
    @Binding var selectedInterval: StatsTimeInterval
    let mealStats: [MealStats]

    @State private var scrollPosition: Date = StatChartUtils.getInitialScrollPosition(for: .day)
    @State private var selectedDate: Date?

    private var selectable: Bool { true }

    private var selectedStat: MealStats? {
        guard let selectedDate else { return nil }
        let cal = Calendar.current
        if selectedInterval == .day {
            return mealStats.first {
                cal.compare($0.date, to: selectedDate, toGranularity: .hour) == .orderedSame
            }
        }
        return mealStats.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        let avgCarbs = mealStats.isEmpty ? 0 : mealStats.map(\.carbs).reduce(0, +) / Double(mealStats.count)
        let avgFat = mealStats.isEmpty ? 0 : mealStats.map(\.fat).reduce(0, +) / Double(mealStats.count)
        let avgProtein = mealStats.isEmpty ? 0 : mealStats.map(\.protein).reduce(0, +) / Double(mealStats.count)
        let hasFatProtein = mealStats.contains { $0.fat > 0 || $0.protein > 0 }
        let isHourly = selectedInterval == .day
        let suffix = isHourly ? "/h" : "/d"

        VStack(spacing: 16) {
            // Stats row
            HStack {
                StatChartUtils.statView(
                    title: "Ø Carbs" + suffix,
                    value: avgCarbs.formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) + " g"
                )
                Spacer()
                if hasFatProtein {
                    StatChartUtils.statView(
                        title: "Ø Fat" + suffix,
                        value: avgFat.formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) + " g"
                    )
                    Spacer()
                    StatChartUtils.statView(
                        title: "Ø Protein" + suffix,
                        value: avgProtein.formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) + " g"
                    )
                }
            }
            .padding(.horizontal)

            Divider()

            // Legend
            HStack(spacing: 16) {
                StatChartUtils.legendItem(label: NSLocalizedString("Carbs", comment: ""), color: .orange)
                if hasFatProtein {
                    StatChartUtils.legendItem(label: NSLocalizedString("Fat", comment: ""), color: .red)
                    StatChartUtils.legendItem(label: NSLocalizedString("Protein", comment: ""), color: .yellow)
                }
            }

            // Chart
            Chart {
                ForEach(mealStats) { stat in
                    let dimmed = selectable && selectedStat != nil && selectedStat?.id != stat.id

                    BarMark(
                        x: .value("Date", stat.date, unit: selectedInterval == .day ? .hour : .day),
                        y: .value("Carbs", stat.carbs)
                    )
                    .foregroundStyle(.orange)
                    .cornerRadius(3)
                    .opacity(dimmed ? 0.35 : 1.0)

                    if hasFatProtein {
                        BarMark(
                            x: .value("Date", stat.date, unit: selectedInterval == .day ? .hour : .day),
                            y: .value("Fat", stat.fat)
                        )
                        .foregroundStyle(.red)
                        .cornerRadius(3)
                        .opacity(dimmed ? 0.35 : 1.0)

                        BarMark(
                            x: .value("Date", stat.date, unit: selectedInterval == .day ? .hour : .day),
                            y: .value("Protein", stat.protein)
                        )
                        .foregroundStyle(.yellow)
                        .cornerRadius(3)
                        .opacity(dimmed ? 0.35 : 1.0)
                    }
                }

                if selectable, let sel = selectedStat {
                    RuleMark(x: .value("Selected", sel.date, unit: selectedInterval == .day ? .hour : .day))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel(format: StatChartUtils.dateFormat(for: selectedInterval))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: StatChartUtils.visibleDomainLength(for: selectedInterval))
            .chartScrollPosition(x: $scrollPosition)
            .frame(height: 200)
            .padding(.horizontal)
            .overlay(alignment: .top) {
                if selectable, let sel = selectedStat {
                    let title = selectedInterval == .day
                        ? sel.date.formatted(.dateTime.hour().minute())
                        : sel.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
                    InsulinBarDetailPopover(
                        title: title,
                        color: .orange,
                        items: mealPopoverItems(for: sel)
                    )
                    .transition(.scale.combined(with: .opacity))
                    .padding(.top, 4)
                }
            }
        }
        .onChange(of: selectedInterval) { _, newValue in
            scrollPosition = StatChartUtils.getInitialScrollPosition(for: newValue)
            selectedDate = nil
        }
    }

    private func mealPopoverItems(for sel: MealStats) -> [(label: String, value: String)] {
        func fmt(_ v: Double) -> String {
            v.formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) + " g"
        }
        var items: [(String, String)] = [
            (NSLocalizedString("Carbs", comment: ""), fmt(sel.carbs))
        ]
        if sel.fat > 0 || sel.protein > 0 {
            items.append((NSLocalizedString("Fat", comment: ""), fmt(sel.fat)))
            items.append((NSLocalizedString("Protein", comment: ""), fmt(sel.protein)))
            let kcal = sel.carbs * 4 + sel.protein * 4 + sel.fat * 9
            items.append((
                NSLocalizedString("Calories", comment: ""),
                kcal.formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) + " kcal"
            ))
        }
        return items
    }
}

// MARK: - Macro Distribution Donut

struct MacroDistributionDonut: View {
    let carbs: Double
    let fat: Double
    let protein: Double
    var daysCount: Int = 1
    var showAverage: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private struct MacroSlice: Identifiable {
        let id = UUID()
        let label: String
        let grams: Double
        let color: Color
    }

    var body: some View {
        let total = carbs + fat + protein
        let slices: [MacroSlice] = [
            MacroSlice(label: NSLocalizedString("Carbs", comment: ""), grams: carbs, color: .orange),
            MacroSlice(label: NSLocalizedString("Fat", comment: ""), grams: fat, color: .red),
            MacroSlice(label: NSLocalizedString("Protein", comment: ""), grams: protein, color: .yellow)
        ]

        let totalKcal = carbs * 4 + protein * 4 + fat * 9
        let avgKcalPerDay = daysCount > 0 ? totalKcal / Double(daysCount) : 0

        VStack(spacing: 14) {
            HStack(spacing: 20) {
                // Donut chart
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Grams", slice.grams),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(slice.color)
                }
                .frame(width: 110, height: 110)

                // Percentages legend
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slices) { slice in
                        let pct = total > 0 ? (slice.grams / total) * 100 : 0
                        HStack(spacing: 8) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 10, height: 10)
                            Text(slice.label)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(pct.formatted(.number.rounded().precision(.fractionLength(0))) + " %")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().opacity(0.4)

            // Calories tiles
            HStack(spacing: 10) {
                caloriesTile(
                    label: NSLocalizedString("Total", comment: ""),
                    value: totalKcal
                )
                if showAverage {
                    caloriesTile(
                        label: NSLocalizedString("Ø / Day", comment: ""),
                        value: avgKcalPerDay
                    )
                }
            }

            // Kcal reference legend
            HStack(spacing: 12) {
                kcalRefItem(color: .orange, text: "1 g " + NSLocalizedString("Carbs", comment: "") + " = 4 kcal")
                kcalRefItem(color: .yellow, text: "1 g " + NSLocalizedString("Protein", comment: "") + " = 4 kcal")
                kcalRefItem(color: .red, text: "1 g " + NSLocalizedString("Fat", comment: "") + " = 9 kcal")
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
    }

    private func caloriesTile(label: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value.formatted(.number.grouping(.automatic).rounded().precision(.fractionLength(0))) + " kcal")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private func kcalRefItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
        }
    }
}
