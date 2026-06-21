import Charts
import SwiftUI

struct LoopBarChartView: View {
    let loopStatRecords: FetchedResults<LoopStatRecord>
    let selectedInterval: StatsTimeIntervalWithToday
    let statsData: [LoopStatsProcessedData]

    var body: some View {
        VStack(spacing: 20) {
            Chart(statsData, id: \.category) { data in
                BarMark(
                    x: .value("Percentage", data.percentage),
                    y: .value("Category", data.category.displayName)
                )
                .cornerRadius(5)
                .foregroundStyle(data.category == .successfulLoop ? BreathePalette.flieder : BreathePalette.daemmer)
                .annotation(position: .overlay) {
                    HStack {
                        Text(annotationText(for: data))
                            .font(.callout)
                            .foregroundStyle(.white)
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    if let category = value.as(String.self) {
                        AxisValueLabel {
                            Text(category).font(.footnote)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    if let percentage = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(percentage))%").font(.footnote)
                        }
                        AxisGridLine()
                    }
                }
            }
            .chartXScale(domain: 0 ... 100)
            .frame(height: 200)
            .padding()
        }
    }

    private func annotationText(for data: LoopStatsProcessedData) -> String {
        if data.category == .successfulLoop {
            switch selectedInterval {
            case .day,
                 .today:
                return "\(data.count) " + NSLocalizedString("Loops", comment: "")
            case .month,
                 .total,
                 .week:
                return "\(data.count) " + statT("stat.loopsPerDay")
            }
        } else {
            switch selectedInterval {
            case .day,
                 .today:
                return "\(data.count) " + NSLocalizedString("Readings", comment: "")
            case .month,
                 .total,
                 .week:
                return "\(data.count) " + statT("stat.readingsPerDay")
            }
        }
    }
}
