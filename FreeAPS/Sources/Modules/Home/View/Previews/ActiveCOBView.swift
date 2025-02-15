import Charts
import SwiftUI

struct ActiveCOBView: View {
    @Binding var data: [IOBData]

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.negativePrefix = formatter.minusSign
        return formatter
    }

    var body: some View {
        VStack {
            Text("Active Carbohydrates")
                .font(.previewHeadline)
                .foregroundColor(.white) // Textfarbe auf Weiß setzen
                .padding(.top, 20)
                .padding(.bottom, 15)

            cobView()
                .frame(maxHeight: 200)
                .padding(.bottom, 10)
                .padding(.top, 10)
                .padding(.horizontal, 20)
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    @ViewBuilder private func cobView() -> some View {
        let maximum = max(0, (data.map(\.cob).max() ?? 0) * 1.1)

        Chart(data) {
            AreaMark(
                x: .value("Time", $0.date),
                y: .value("COB", $0.cob)
            )
            .foregroundStyle(Color(.loopYellow).gradient)
            .opacity(0.8)
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.white) // Y-Achsenbeschriftung auf Weiß
                AxisGridLine()
                    .foregroundStyle(Color.white) // Gitterlinien auf Weiß setzen
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisValueLabel(
                    format: .dateTime.hour(.defaultDigits(amPM: .omitted))
                        .locale(Locale(identifier: "sv")) // 24h-Format
                )
                .foregroundStyle(Color.white) // X-Achsenbeschriftung auf Weiß
                AxisGridLine()
                    .foregroundStyle(Color.white) // Gitterlinien auf Weiß setzen
            }
        }
        .chartYScale(
            domain: 0 ... maximum
        )
        .chartXScale(
            domain: Date.now.addingTimeInterval(-1.days.timeInterval) ... Date.now
        )
        .chartLegend(.hidden)
        .foregroundStyle(Color.white) // Allgemeiner Stil auf Weiß setzen
    }
}
