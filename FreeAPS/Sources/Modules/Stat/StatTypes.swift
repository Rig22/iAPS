import Foundation
import SwiftUI

// MARK: - View Type Enums

enum StatisticViewType: String, CaseIterable, Identifiable {
    case overview
    case glucose
    case looping
    case insulin
    case meals

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: return StatL10n.t("stat.tab.overview")
        case .glucose: return NSLocalizedString("Glucose", comment: "")
        case .insulin: return NSLocalizedString("Insulin", comment: "")
        case .looping: return StatL10n.t("stat.tab.looping")
        case .meals: return NSLocalizedString("Meals", comment: "")
        }
    }
}

// MARK: - Time Intervals

enum StatsTimeIntervalWithToday: String, CaseIterable, Identifiable {
    case today
    case day = "D"
    case week = "W"
    case month = "M"
    case total = "3 M"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .today: return NSLocalizedString("Today", comment: "")
        case .day: return StatL10n.t("stat.interval.d")
        case .week: return StatL10n.t("stat.interval.w")
        case .month: return StatL10n.t("stat.interval.m")
        case .total: return StatL10n.t("stat.interval.3m")
        }
    }
}

extension StatsTimeIntervalWithToday {
    /// Maps to StatsTimeInterval for chart utilities — .today behaves like .day
    var asChartInterval: StatsTimeInterval {
        switch self {
        case .day,
             .today: return .day
        case .week: return .week
        case .month: return .month
        case .total: return .total
        }
    }

    var isHourly: Bool { self == .today || self == .day }
}

enum StatsTimeInterval: String, CaseIterable, Identifiable {
    case day = "D"
    case week = "W"
    case month = "M"
    case total = "3 M"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .day: return StatL10n.t("stat.interval.d")
        case .week: return StatL10n.t("stat.interval.w")
        case .month: return StatL10n.t("stat.interval.m")
        case .total: return StatL10n.t("stat.interval.3m")
        }
    }
}

// MARK: - Chart Type Enums

enum GlucoseChartType: String, CaseIterable {
    case sectorAndMetrics = "Overview"
    case percentileByTime = "Percentile"
    case distribution = "Distribution"

    var displayName: String {
        switch self {
        case .sectorAndMetrics: return StatL10n.t("stat.tab.overview")
        case .percentileByTime: return StatL10n.t("stat.glucoseChart.percentile")
        case .distribution: return StatL10n.t("stat.glucoseChart.distribution")
        }
    }
}

enum InsulinChartType: String, CaseIterable {
    case totalDailyDose = "Total Daily Dose"
    case bolusDistribution = "Bolus Distribution"

    var displayName: String {
        switch self {
        case .totalDailyDose: return StatL10n.t("stat.insulinChart.tdd")
        case .bolusDistribution: return StatL10n.t("stat.insulinChart.bolusDist")
        }
    }
}

enum LoopingChartType: String, CaseIterable {
    case loopingPerformance = "Looping Performance"

    var displayName: String {
        StatL10n.t("stat.loopChart.performance")
    }
}

enum MealChartType: String, CaseIterable {
    case totalMeals = "Total Meals"

    var displayName: String {
        StatL10n.t("stat.mealChart.totalMeals")
    }
}

// MARK: - Data Structs

struct TDDStats: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

struct BolusStats: Identifiable {
    let id = UUID()
    let date: Date
    let manualBolus: Double
    let smb: Double
    let external: Double
}

struct MealStats: Identifiable {
    let id = UUID()
    let date: Date
    let carbs: Double
    let fat: Double
    let protein: Double
}

/// Per-meal micronutrient contribution, kept alongside `MealStats` so the Meal
/// tab can aggregate intake over any selected interval.
struct MicroMealRecord {
    let date: Date
    let micros: [MicroNutrient: Decimal]
}

struct HourlyStats: Equatable {
    let hour: Int
    let median: Double
    let percentile25: Double
    let percentile75: Double
    let percentile10: Double
    let percentile90: Double
}

struct AGPSlot: Identifiable {
    let id: Int // minute of day (0, 30, 60, ...)
    let date: Date // reference date for charting
    let p10: Double
    let p25: Double
    let p50: Double
    let p75: Double
    let p90: Double
}

struct LoopStatsProcessedData: Identifiable {
    var id = UUID()
    let category: LoopStatsDataType
    let count: Int
    let percentage: Double
    let successPercentage: Double
    let medianDuration: Double
    let medianInterval: Double
    let totalDays: Int
}

enum LoopStatsDataType: String {
    case successfulLoop
    case glucoseCount

    var displayName: String {
        switch self {
        case .successfulLoop: return StatL10n.t("stat.loopType.successfulLoops")
        case .glucoseCount: return StatL10n.t("stat.loopType.glucoseCount")
        }
    }
}

struct LoopStatsByPeriod: Identifiable {
    let period: Date
    let successful: Int
    let failed: Int
    let medianDuration: Double
    let glucoseCount: Int
    var total: Int { successful + failed }
    var successPercentage: Double { total > 0 ? Double(successful) / Double(total) * 100 : 0 }
    var id: Date { period }
}

struct GlucoseDistributionSlot: Identifiable {
    let id: Date // calendar day
    let date: Date
    let veryLow: Double // <54 mg/dL (%)
    let low: Double // 54–70 mg/dL (%)
    let inRange: Double // 70–180 mg/dL (%)
    let high: Double // 180–250 mg/dL (%)
    let veryHigh: Double // >250 mg/dL (%)
    let totalReadings: Int
}
