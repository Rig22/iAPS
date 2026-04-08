import Charts
import SwiftUI

struct BolusStatsView: View {
    @Binding var selectedInterval: StatsTimeInterval
    let bolusStats: [BolusStats]

    @State private var scrollPosition: Date = StatChartUtils.getInitialScrollPosition(for: .day)
    @State private var selectedDate: Date?

    private var selectable: Bool { true }

    private var selectedStat: BolusStats? {
        guard let selectedDate else { return nil }
        let cal = Calendar.current
        if selectedInterval == .day {
            return bolusStats.first {
                cal.compare($0.date, to: selectedDate, toGranularity: .hour) == .orderedSame
            }
        }
        return bolusStats.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        let avgBolus = bolusStats.isEmpty ? 0 : bolusStats.map(\.manualBolus).reduce(0, +) / Double(bolusStats.count)
        let avgBasal = bolusStats.isEmpty ? 0 : bolusStats.map(\.external).reduce(0, +) / Double(bolusStats.count)
        let totalBolus = bolusStats.map(\.manualBolus).reduce(0, +)
        let totalBasal = bolusStats.map(\.external).reduce(0, +)
        let isHourly = selectedInterval == .day

        VStack(spacing: 16) {
            // Stats row
            HStack {
                if isHourly {
                    // For "Day" view: show today's actual totals (not per-hour averages)
                    StatChartUtils.statView(
                        title: NSLocalizedString("Bolus Today", comment: "Bolus delivered today"),
                        value: totalBolus.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                    )
                    Spacer()
                    StatChartUtils.statView(
                        title: NSLocalizedString("Basal Today", comment: "Basal delivered today"),
                        value: totalBasal.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                    )
                    Spacer()
                    StatChartUtils.statView(
                        title: NSLocalizedString("Total", comment: ""),
                        value: (totalBolus + totalBasal)
                            .formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                    )
                } else {
                    StatChartUtils.statView(
                        title: NSLocalizedString("Ø Bolus/d", comment: "Average bolus per day"),
                        value: avgBolus.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                    )
                    Spacer()
                    StatChartUtils.statView(
                        title: NSLocalizedString("Ø Basal/d", comment: "Average basal per day"),
                        value: avgBasal.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                    )
                    Spacer()
                    StatChartUtils.statView(
                        title: NSLocalizedString("Total", comment: ""),
                        value: (totalBolus + totalBasal)
                            .formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                    )
                }
            }
            .padding(.horizontal)

            Divider()

            // Legend
            HStack(spacing: 16) {
                StatChartUtils.legendItem(label: NSLocalizedString("Bolus", comment: ""), color: .blue)
                StatChartUtils.legendItem(label: NSLocalizedString("Basal", comment: ""), color: .cyan)
            }

            // Chart
            Chart {
                ForEach(bolusStats) { stat in
                    let dimmed = selectable && selectedStat != nil && selectedStat?.id != stat.id
                    BarMark(
                        x: .value("Date", stat.date, unit: selectedInterval == .day ? .hour : .day),
                        y: .value("Bolus", stat.manualBolus)
                    )
                    .foregroundStyle(.blue)
                    .cornerRadius(3)
                    .opacity(dimmed ? 0.35 : 1.0)

                    BarMark(
                        x: .value("Date", stat.date, unit: selectedInterval == .day ? .hour : .day),
                        y: .value("Basal", stat.external)
                    )
                    .foregroundStyle(.cyan)
                    .cornerRadius(3)
                    .opacity(dimmed ? 0.35 : 1.0)
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
                AxisMarks { value in
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text("\(Int(val))U").font(.caption)
                        }
                    }
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
                    let total = sel.manualBolus + sel.external
                    let title = selectedInterval == .day
                        ? sel.date.formatted(.dateTime.hour().minute())
                        : sel.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
                    InsulinBarDetailPopover(
                        title: title,
                        color: .blue,
                        items: [
                            (
                                NSLocalizedString("Bolus", comment: ""),
                                sel.manualBolus.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                            ),
                            (
                                NSLocalizedString("Basal", comment: ""),
                                sel.external.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                            ),
                            (
                                NSLocalizedString("Total", comment: ""),
                                total.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " U"
                            )
                        ]
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
}
