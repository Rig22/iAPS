import CoreData
import Foundation
import SwiftDate
import SwiftUI
import Swinject

extension Stat {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var settings: SettingsManager!
        @Injected() var pumpHistoryStorage: PumpHistoryStorage!

        // Settings
        @Published var highLimit: Decimal = 10 / 0.0555
        @Published var lowLimit: Decimal = 4 / 0.0555
        @Published var overrideUnit: Bool = false
        @Published var layingChart: Bool = false
        @Published var units: GlucoseUnits = .mmolL

        // Selected view and chart types
        @Published var selectedView: StatisticViewType = .overview
        @Published var selectedGlucoseChartType: GlucoseChartType = .sectorAndMetrics
        @Published var selectedInsulinChartType: InsulinChartType = .totalDailyDose
        @Published var selectedLoopingChartType: LoopingChartType = .loopingPerformance
        @Published var selectedMealChartType: MealChartType = .totalMeals

        // Selected intervals
        @Published var selectedIntervalForGlucoseStats: StatsTimeIntervalWithToday = .today
        @Published var selectedIntervalForInsulinStats: StatsTimeIntervalWithToday = .today
        @Published var selectedIntervalForLoopStats: StatsTimeIntervalWithToday = .today
        @Published var selectedIntervalForMealStats: StatsTimeIntervalWithToday = .today

        // Computed data caches
        @Published var dailyTDDStats: [TDDStats] = []
        @Published var hourlyTDDStats: [TDDStats] = []
        @Published var dailyBolusStats: [BolusStats] = []
        @Published var hourlyBolusStats: [BolusStats] = []
        @Published var dailyMealStats: [MealStats] = []
        @Published var hourlyMealStats: [MealStats] = []
        @Published var last24hHourlyTDDStats: [TDDStats] = []
        @Published var last24hHourlyBolusStats: [BolusStats] = []
        @Published var loopStats: [LoopStatsProcessedData] = []
        @Published var hourlyStats: [HourlyStats] = []

        // Insulin summary (mirrors HomeStateModel for consistency with HomeRootView)
        @Published var neg: Int = 0
        @Published var tddChange: Decimal = 0
        @Published var tddAverage: Decimal = 0
        @Published var tddYesterday: Decimal = 0
        @Published var tdd2DaysAgo: Decimal = 0
        @Published var tdd3DaysAgo: Decimal = 0
        @Published var tddActualAverage: Decimal = 0

        override func subscribe() {
            highLimit = settingsManager.settings.high
            lowLimit = settingsManager.settings.low
            units = settingsManager.settings.units
            overrideUnit = settingsManager.settings.overrideHbA1cUnit
            layingChart = settingsManager.settings.oneDimensionalGraph

            setupInsulinStats()
            setupInsulinSummary()
            setupMealStats()
        }

        // MARK: - Insulin Summary (mirrors HomeStateModel.setupData)

        /// Computes the daily TDD summary values exactly the same way HomeRootView does,
        /// so the values shown in the Stat insulin summary card always match the home view.
        private func setupInsulinSummary() {
            let tdds = CoreDataStorage().fetchTDD(interval: DateFilter().tenDays)
            let yesterday = (tdds.first(where: {
                ($0.timestamp ?? .distantFuture) <= Date().addingTimeInterval(-24.hours.timeInterval)
            })?.tdd ?? 0) as Decimal
            let oneDaysAgo = CoreDataStorage().fetchTDD(interval: DateFilter().today).last

            tddChange = ((tdds.first?.tdd ?? 0) as Decimal) - yesterday
            tddYesterday = (oneDaysAgo?.tdd ?? 0) as Decimal
            tdd2DaysAgo = (tdds.first(where: {
                ($0.timestamp ?? .distantFuture) <= (oneDaysAgo?.timestamp ?? .distantPast)
                    .addingTimeInterval(-1.days.timeInterval)
            })?.tdd ?? 0) as Decimal
            tdd3DaysAgo = (tdds.first(where: {
                ($0.timestamp ?? .distantFuture) <= (oneDaysAgo?.timestamp ?? .distantPast)
                    .addingTimeInterval(-2.days.timeInterval)
            })?.tdd ?? 0) as Decimal

            if let dyn = provider.dynamicVariables {
                tddAverage = ((tdds.first?.tdd ?? 0) as Decimal) - dyn.average_total_data
                tddActualAverage = dyn.average_total_data
            }

            if let iobData = provider.reasons() {
                neg = iobData.filter { $0.iob < 0 }.count * 5
            }
        }

        // MARK: - Date Filter

        func filterDate(for interval: StatsTimeIntervalWithToday) -> NSDate {
            switch interval {
            case .today: return Calendar.current.startOfDay(for: Date()) as NSDate
            case .day: return Date().addingTimeInterval(-24 * 3600) as NSDate
            case .week: return Date().addingTimeInterval(-7 * 24 * 3600) as NSDate
            case .month: return Date().addingTimeInterval(-30 * 24 * 3600) as NSDate
            case .total: return Date().addingTimeInterval(-90 * 24 * 3600) as NSDate
            }
        }

        func filterDate(for interval: StatsTimeInterval) -> NSDate {
            switch interval {
            case .day: return Date().addingTimeInterval(-24 * 3600) as NSDate
            case .week: return Date().addingTimeInterval(-7 * 24 * 3600) as NSDate
            case .month: return Date().addingTimeInterval(-30 * 24 * 3600) as NSDate
            case .total: return Date().addingTimeInterval(-90 * 24 * 3600) as NSDate
            }
        }

        // MARK: - Filtered Data Accessors

        /// Filters daily TDD stats to the selected time interval
        var filteredDailyTDDStats: [TDDStats] {
            let cutoff = filterDate(for: selectedIntervalForInsulinStats) as Date
            return dailyTDDStats.filter { $0.date >= cutoff }
        }

        /// Filters daily bolus stats to the selected time interval
        var filteredDailyBolusStats: [BolusStats] {
            let cutoff = filterDate(for: selectedIntervalForInsulinStats) as Date
            return dailyBolusStats.filter { $0.date >= cutoff }
        }

        /// Filters daily meal stats to the selected time interval
        var filteredDailyMealStats: [MealStats] {
            let cutoff = filterDate(for: selectedIntervalForMealStats) as Date
            return dailyMealStats.filter { $0.date >= cutoff }
        }

        /// Hourly meal stats filtered to today only (from midnight), with all 24h slots filled
        var todayHourlyMealStats: [MealStats] {
            let calendar = Calendar.current
            let midnight = calendar.startOfDay(for: Date())
            let todayData = hourlyMealStats.filter { $0.date >= midnight }

            // Build a full 24h timeline with empty slots
            var hourlyMap: [Date: (carbs: Double, fat: Double, protein: Double)] = [:]
            for h in 0 ..< 24 {
                if let hourDate = calendar.date(byAdding: .hour, value: h, to: midnight) {
                    hourlyMap[hourDate] = (0, 0, 0)
                }
            }
            // Overlay actual data
            for stat in todayData {
                let hour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: stat.date))!
                hourlyMap[hour] = (stat.carbs, stat.fat, stat.protein)
            }
            return hourlyMap
                .map { MealStats(date: $0.key, carbs: $0.value.carbs, fat: $0.value.fat, protein: $0.value.protein) }
                .sorted { $0.date < $1.date }
        }

        // MARK: - Insulin Setup (TDD + Bolus Distribution)

        /// Computes both TDD and Bolus Distribution stats from a single source (InsulinDistribution).
        /// This guarantees that TDD total == Bolus total + Basal total at all times.
        ///
        /// For "today", the values from CoreData represent a rolling 24h window (not calendar-day),
        /// so we override today's entry with the actually-delivered amount since midnight, computed
        /// directly from PumpHistoryStorage.
        private func setupInsulinStats() {
            let context = CoreDataStack.shared.persistentContainer.viewContext
            let request = NSFetchRequest<InsulinDistribution>(entityName: "InsulinDistribution")
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            request.predicate = NSPredicate(format: "date > %@", Date().addingTimeInterval(-90 * 24 * 3600) as NSDate)

            guard let results = try? context.fetch(request) else { return }

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())

            // InsulinDistribution records are saved every loop cycle (~5 min) by saveTDD().
            // Each record stores a CUMULATIVE rolling 24h value of bolus and tempBasal.
            // We take the LATEST record per day (by timestamp) and read both bolus & basal
            // from that SAME record. This guarantees consistency: TDD = bolus + basal.
            var dailyLatest: [Date: (timestamp: Date, bolus: Double, basal: Double)] = [:]
            for record in results {
                guard let date = record.date else { continue }
                let day = calendar.startOfDay(for: date)
                let bolus = Double(truncating: record.bolus ?? 0)
                let basal = Double(truncating: record.tempBasal ?? 0)
                    + Double(truncating: record.scheduledBasal ?? 0)
                if let existing = dailyLatest[day] {
                    if date > existing.timestamp {
                        dailyLatest[day] = (date, bolus, basal)
                    }
                } else {
                    dailyLatest[day] = (date, bolus, basal)
                }
            }

            // Override today's entry with the actually delivered amount since midnight,
            // computed directly from pump history (not the rolling 24h cumulative value).
            let increment = Double(settingsManager.preferences.bolusIncrement)
            let pumpEvents = pumpHistoryStorage?.recent() ?? []
            let todayActual = TotalDailyDose().insulinToday(pumpEvents, increment: increment)
            let todayBolus = Double(truncating: todayActual.bolus as NSDecimalNumber)
            let todayBasal = Double(truncating: todayActual.basal as NSDecimalNumber)
            dailyLatest[todayStart] = (Date(), todayBolus, todayBasal)

            let sortedDaily = dailyLatest.sorted { $0.key < $1.key }
            dailyBolusStats = sortedDaily.map {
                BolusStats(date: $0.key, manualBolus: $0.value.bolus, smb: 0, external: $0.value.basal)
            }
            dailyTDDStats = sortedDaily.map {
                TDDStats(date: $0.key, amount: $0.value.bolus + $0.value.basal)
            }

            // Hourly stats (for "Day" view): build directly from today's pump history events
            // so values reflect actually-delivered amounts per hour (not cumulative deltas).
            var hourlyMap: [Date: (bolus: Double, basal: Double)] = [:]

            // Initialize all 24 hours of today so the chart shows a continuous timeline
            for h in 0 ..< 24 {
                if let hourDate = calendar.date(byAdding: .hour, value: h, to: todayStart) {
                    hourlyMap[hourDate] = (0, 0)
                }
            }

            // Sum boluses per hour from pump events
            let todayEvents = pumpEvents.filter { $0.timestamp >= todayStart }
            for event in todayEvents where event.type == .bolus {
                let hour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: event.timestamp))!
                let amount = Double(truncating: (event.amount ?? 0) as NSDecimalNumber)
                hourlyMap[hour, default: (0, 0)].bolus += amount
            }

            // Distribute today's basal proportionally across hours that have elapsed.
            // (Hour-by-hour temp basal reconstruction is complex; proportional split keeps
            //  the daily total accurate while giving a reasonable per-hour visualization.)
            let now = Date()
            let elapsedHours = max(1, calendar.dateComponents([.hour], from: todayStart, to: now).hour ?? 0) + 1
            if todayBasal > 0, elapsedHours > 0 {
                let perHour = todayBasal / Double(elapsedHours)
                for h in 0 ..< elapsedHours {
                    if let hourDate = calendar.date(byAdding: .hour, value: h, to: todayStart) {
                        hourlyMap[hourDate, default: (0, 0)].basal += perHour
                    }
                }
            }

            let sortedHourly = hourlyMap.sorted { $0.key < $1.key }
            hourlyBolusStats = sortedHourly.map {
                BolusStats(date: $0.key, manualBolus: $0.value.bolus, smb: 0, external: $0.value.basal)
            }
            hourlyTDDStats = sortedHourly.map {
                TDDStats(date: $0.key, amount: $0.value.bolus + $0.value.basal)
            }

            // Last 24h hourly stats (for "Day" picker – covers yesterday evening through now)
            let dayAgoStart = now.addingTimeInterval(-24 * 3600)
            let dayAgoHourStart = calendar.date(from: calendar.dateComponents(
                [.year, .month, .day, .hour], from: dayAgoStart
            ))!

            var last24hMap: [Date: (bolus: Double, basal: Double)] = [:]
            // Initialize all 24 hour-slots
            for h in 0 ..< 24 {
                if let hourDate = calendar.date(byAdding: .hour, value: h, to: dayAgoHourStart) {
                    last24hMap[hourDate] = (0, 0)
                }
            }

            // Sum boluses from pump events in the last 24h
            let last24hEvents = pumpEvents.filter { $0.timestamp >= dayAgoStart }
            for event in last24hEvents where event.type == .bolus {
                let hour = calendar.date(from: calendar.dateComponents(
                    [.year, .month, .day, .hour], from: event.timestamp
                ))!
                let amount = Double(truncating: (event.amount ?? 0) as NSDecimalNumber)
                last24hMap[hour, default: (0, 0)].bolus += amount
            }

            // Distribute basal: use yesterday's daily basal for pre-midnight hours,
            // today's basal for post-midnight hours
            let yesterdayStart = calendar.startOfDay(for: dayAgoStart)
            let yesterdayDaily = dailyLatest[yesterdayStart]
            let yesterdayBasal = yesterdayDaily?.basal ?? 0
            // Hours from yesterday (dayAgoHourStart until midnight)
            let preHourCount = max(1, calendar.dateComponents([.hour], from: dayAgoHourStart, to: todayStart).hour ?? 0)
            if yesterdayBasal > 0 {
                let perHour = yesterdayBasal / 24.0
                for h in 0 ..< preHourCount {
                    if let hourDate = calendar.date(byAdding: .hour, value: h, to: dayAgoHourStart) {
                        last24hMap[hourDate, default: (0, 0)].basal += perHour
                    }
                }
            }
            // Hours from today (midnight until now)
            if todayBasal > 0, elapsedHours > 0 {
                let perHour = todayBasal / Double(elapsedHours)
                for h in 0 ..< elapsedHours {
                    if let hourDate = calendar.date(byAdding: .hour, value: h, to: todayStart) {
                        last24hMap[hourDate, default: (0, 0)].basal += perHour
                    }
                }
            }

            let sortedLast24h = last24hMap.sorted { $0.key < $1.key }
            last24hHourlyBolusStats = sortedLast24h.map {
                BolusStats(date: $0.key, manualBolus: $0.value.bolus, smb: 0, external: $0.value.basal)
            }
            last24hHourlyTDDStats = sortedLast24h.map {
                TDDStats(date: $0.key, amount: $0.value.bolus + $0.value.basal)
            }
        }

        // MARK: - Meal Setup

        private func setupMealStats() {
            let context = CoreDataStack.shared.persistentContainer.viewContext
            let request = NSFetchRequest<Carbohydrates>(entityName: "Carbohydrates")
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            request.predicate = NSPredicate(format: "date > %@", Date().addingTimeInterval(-90 * 24 * 3600) as NSDate)

            guard let results = try? context.fetch(request) else { return }

            let calendar = Calendar.current

            // Daily
            var dailyMap: [Date: (carbs: Double, fat: Double, protein: Double)] = [:]
            for record in results {
                guard let date = record.date else { continue }
                let day = calendar.startOfDay(for: date)
                dailyMap[day, default: (0, 0, 0)].carbs += Double(truncating: record.carbs ?? 0)
                dailyMap[day, default: (0, 0, 0)].fat += Double(truncating: record.fat ?? 0)
                dailyMap[day, default: (0, 0, 0)].protein += Double(truncating: record.protein ?? 0)
            }
            dailyMealStats = dailyMap
                .map { MealStats(date: $0.key, carbs: $0.value.carbs, fat: $0.value.fat, protein: $0.value.protein) }
                .sorted { $0.date < $1.date }

            // Hourly (last 24h with all hour slots filled)
            let now = Date()
            let dayAgo = now.addingTimeInterval(-24 * 3600)
            let dayAgoHourStart = calendar.date(from: calendar.dateComponents(
                [.year, .month, .day, .hour], from: dayAgo
            ))!

            var hourlyMap: [Date: (carbs: Double, fat: Double, protein: Double)] = [:]
            // Initialize all 24 hour slots
            for h in 0 ..< 24 {
                if let hourDate = calendar.date(byAdding: .hour, value: h, to: dayAgoHourStart) {
                    hourlyMap[hourDate] = (0, 0, 0)
                }
            }
            // Overlay actual data
            for record in results {
                guard let date = record.date, date > dayAgo else { continue }
                let hour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: date))!
                hourlyMap[hour, default: (0, 0, 0)].carbs += Double(truncating: record.carbs ?? 0)
                hourlyMap[hour, default: (0, 0, 0)].fat += Double(truncating: record.fat ?? 0)
                hourlyMap[hour, default: (0, 0, 0)].protein += Double(truncating: record.protein ?? 0)
            }
            hourlyMealStats = hourlyMap
                .map { MealStats(date: $0.key, carbs: $0.value.carbs, fat: $0.value.fat, protein: $0.value.protein) }
                .sorted { $0.date < $1.date }
        }
    }
}
