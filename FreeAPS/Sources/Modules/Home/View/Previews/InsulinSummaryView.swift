import CoreData
import SwiftUI

struct InsulinSummaryView: View {
    @Binding var neg: Int
    @Binding var tddChange: Decimal
    @Binding var tddAverage: Decimal
    @Binding var tddYesterday: Decimal
    @Binding var tdd2DaysAgo: Decimal
    @Binding var tdd3DaysAgo: Decimal
    @Binding var tddActualAverage: Decimal
    var showHeadline: Bool = true

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.negativePrefix = formatter.minusSign
        formatter.positivePrefix = formatter.plusSign
        return formatter
    }

    private var tddFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }

    private var intFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    var body: some View {
        VStack {
            if showHeadline {
                Text("Insulin").font(.previewHeadline).padding(.top, 20).padding(.bottom, 15)
            }
            sumView()
                .frame(maxHeight: showHeadline ? 250 : .infinity)
                .padding(.bottom, showHeadline ? 10 : 0)
        }.dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    @ViewBuilder private func sumView() -> some View {
        let entries = [
            BolusSummary(
                variable: NSLocalizedString("Time with negative insulin", comment: ""),
                formula: NSLocalizedString(" min", comment: ""),
                insulin: Decimal(neg),
                color: .red
            ),
            BolusSummary(
                variable: NSLocalizedString("Insulin compared to yesterday", comment: ""),
                formula: NSLocalizedString(" U", comment: ""),
                insulin: tddChange,
                color: Color(.insulin)
            ),
            BolusSummary(
                variable: NSLocalizedString("Insulin compared to average", comment: ""),
                formula: NSLocalizedString(" U", comment: ""),
                insulin: tddAverage,
                color: Color(.insulin)
            ),
            BolusSummary(
                variable: "",
                formula: "",
                insulin: .zero,
                color: Color(.clear)
            ),
            BolusSummary(
                variable: NSLocalizedString("Average Insulin 10 days", comment: ""),
                formula: NSLocalizedString(" U", comment: ""),
                insulin: tddActualAverage,
                color: .secondary
            ),
            BolusSummary(
                variable: "",
                formula: "",
                insulin: .zero,
                color: Color(.clear)
            ),
            BolusSummary(
                variable: NSLocalizedString("TDD yesterday", comment: ""),
                formula: NSLocalizedString(" U", comment: ""),
                insulin: tddYesterday,
                color: .secondary
            ),
            BolusSummary(
                variable: NSLocalizedString("TDD 2 days ago", comment: ""),
                formula: NSLocalizedString(" U", comment: ""),
                insulin: tdd2DaysAgo,
                color: .secondary
            ),
            BolusSummary(
                variable: NSLocalizedString("TDD 3 days ago", comment: ""),
                formula: NSLocalizedString(" U", comment: ""),
                insulin: tdd3DaysAgo,
                color: .secondary
            )
        ]

        let insulinData = useData(entries)

        Grid(verticalSpacing: showHeadline ? 8 : 4) {
            ForEach(insulinData) { entry in

                GridRow(alignment: .firstTextBaseline) {
                    Text(entry.variable)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("")
                    if entry.insulin != 0 {
                        Text(
                            ((isTDD(entry.insulin) ? tddFormatter : formatter).string(for: entry.insulin) ?? "") + entry
                                .formula
                        )
                        .bold(entry == entries.first).foregroundStyle(entry.color)
                    } else if entry.variable != "" {
                        Text("0").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(showHeadline ? .body : .system(size: 15))
        .padding(.horizontal, showHeadline ? 20 : 4)
    }

    private func isTDD(_ insulin: Decimal) -> Bool {
        insulin == tddYesterday || insulin == tdd2DaysAgo || insulin == tdd3DaysAgo || insulin == tddActualAverage
    }

    private func useData(_ data: [BolusSummary]) -> [BolusSummary] {
        if neg == 0 {
            return data.dropFirst().map({ a -> BolusSummary in a })
        }
        return data
    }

    private func negIOBdata(_ data: [IOBData]) -> [IOBData] {
        var array = [IOBData]()
        var previous = data.first
        for item in data {
            if item.iob < 0 {
                if previous?.iob ?? 0 >= 0 {
                    array.append(IOBData(date: previous?.date ?? .distantPast, iob: 0, cob: 0))
                }
                array.append(IOBData(date: item.date, iob: item.iob, cob: 0))
            } else if previous?.iob ?? 0 < 0 {
                array.append(IOBData(date: item.date, iob: 0, cob: 0))
            }
            previous = item
        }
        return array
    }
}
