import CoreData
import SwiftDate
import SwiftUI

struct LoopingCard: View {
    @FetchRequest var fetchLoopStats: FetchedResults<LoopStatRecord>
    @FetchRequest var fetchReadings: FetchedResults<Readings>

    let selectedInterval: StatsTimeIntervalWithToday

    @State private var showErrorDetails = false

    init(filter: NSDate, selectedInterval: StatsTimeIntervalWithToday = .today) {
        _fetchLoopStats = FetchRequest<LoopStatRecord>(
            sortDescriptors: [NSSortDescriptor(key: "start", ascending: false)],
            predicate: NSPredicate(format: "start > %@", filter)
        )
        _fetchReadings = FetchRequest<Readings>(
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
            predicate: NSPredicate(format: "glucose > 0 AND date > %@", filter)
        )
        self.selectedInterval = selectedInterval
    }

    var body: some View {
        let statsData = computeLoopStats()
        let nonCompleted = computeNonCompleted()
        let errorBreakdown = computeErrorBreakdown()

        if fetchLoopStats.isEmpty {
            StatCard {
                ContentUnavailableView(
                    NSLocalizedString("No Loop Data", comment: ""),
                    systemImage: "clock.arrow.2.circlepath",
                    description: Text("Loop statistics will appear here once data is available.")
                )
            }
        } else {
            StatCard {
                VStack(spacing: 12) {
                    // Header with optional error info button
                    HStack {
                        Text(NSLocalizedString("Loop Performance", comment: "Loop card header"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        if nonCompleted > 0, !errorBreakdown.isEmpty {
                            Button {
                                showErrorDetails.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("\(nonCompleted)")
                                        .monospacedDigit()
                                }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(BreathePalette.kamille)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(BreathePalette.kamille.opacity(0.15))
                                )
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showErrorDetails, arrowEdge: .top) {
                                ErrorDetailsPopover(
                                    nonCompleted: nonCompleted,
                                    errors: errorBreakdown
                                )
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }

                    LoopBarChartView(
                        loopStatRecords: fetchLoopStats,
                        selectedInterval: selectedInterval,
                        statsData: statsData
                    )
                }
            }

            // Second card: detailed loop stats tiles
            StatCard {
                LoopStatsView(statsData: statsData, selectedInterval: selectedInterval)
            }
        }
    }

    private func computeNonCompleted() -> Int {
        let loops = fetchLoopStats
        let loopStatuses = loops.compactMap(\.loopStatus)
        let success = loopStatuses.filter { $0.contains("Success") }.count
        return max(loopStatuses.count - success, 0)
    }

    private func computeErrorBreakdown() -> [LoopErrorEntry] {
        let errors = fetchLoopStats.compactMap(\.error).filter { !$0.isEmpty }
        guard !errors.isEmpty else { return [] }
        return Dictionary(grouping: errors) { $0 }
            .map { LoopErrorEntry(message: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private func computeLoopStats() -> [LoopStatsProcessedData] {
        let loops = fetchLoopStats
        let readings = fetchReadings

        let previous = (loops.last?.start ?? Date.now).addingTimeInterval(-5 * 60)
        let days = max(-1 * previous.timeIntervalSinceNow / 86400, 1)

        let loopCount = loops.compactMap(\.loopStatus).count
        let successCount = loops.compactMap(\.loopStatus).filter { $0.contains("Success") }.count
        let successPercentage = loopCount > 0 ? Double(successCount) / Double(loopCount) * 100 : 0

        let durationArray = loops.compactMap(\.duration)
        let medianDuration = StatChartUtils.medianCalculationDouble(array: durationArray) * 60 // to seconds

        let intervalArray = loops.compactMap(\.interval).filter { $0 > 0 }
        let medianInterval = StatChartUtils.medianCalculationDouble(array: intervalArray) * 60 // to seconds

        let readingsCount = readings.count
        // Use the readings' own time span to avoid dividing by more days than readings actually cover
        let oldestReading = readings.last?.date ?? Date()
        let readingsDays = max(-1 * oldestReading.timeIntervalSinceNow / 86400, 1)
        let readingsPerDay = Double(readingsCount) / readingsDays

        let loopsPerDay = Double(loopCount) / days
        let totalDays = Int(days)

        // Both bars now use the same scale: percentage of expected daily count (288/day, every 5 min)
        // This makes the bars visually comparable when counts are similar.
        let expectedPerDay: Double = 288
        let loopsBarPercentage = min(loopsPerDay / expectedPerDay * 100, 100)
        let readingsBarPercentage = readingsCount > 0 ? min(readingsPerDay / expectedPerDay * 100, 100) : 0

        return [
            LoopStatsProcessedData(
                category: .successfulLoop,
                count: days < 1.5 ? successCount : Int(round(loopsPerDay)),
                percentage: loopsBarPercentage,
                successPercentage: successPercentage,
                medianDuration: medianDuration,
                medianInterval: medianInterval,
                totalDays: totalDays
            ),
            LoopStatsProcessedData(
                category: .glucoseCount,
                count: days < 1.5 ? readingsCount : Int(round(readingsPerDay)),
                percentage: readingsBarPercentage,
                successPercentage: 0,
                medianDuration: 0,
                medianInterval: 0,
                totalDays: totalDays
            )
        ]
    }
}

// MARK: - Error Details Popover

private struct LoopErrorEntry: Identifiable {
    let message: String
    let count: Int
    var id: String { message }
}

private struct ErrorDetailsPopover: View {
    let nonCompleted: Int
    let errors: [LoopErrorEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(BreathePalette.kamille)
                Text(StatL10n.t("loop.errors"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(nonCompleted)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(errors) { error in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(error.count)×")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(BreathePalette.kamille)
                                .frame(minWidth: 28, alignment: .trailing)
                            Text(error.message)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if error.id != errors.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(14)
        .frame(maxWidth: 320)
    }
}
