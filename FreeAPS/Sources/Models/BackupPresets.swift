import Foundation

/// Complete, lossless Codable representation of an `OverridePresets` Core
/// Data entity for inclusion in BackupBundle. Covers every attribute the
/// orbital schema exposes — including the ones missing from
/// `MigratedOverridePresets` (overrideAutoISF, endWIthNewCarbs,
/// glucoseOverrideThreshold*, glucoseOverrideThresholdDown).
///
/// Fields that may be added in future schema versions should be added here
/// as Optional so older backups still decode cleanly.
struct BackupOverridePreset: Codable, Sendable {
    var id: String
    var name: String
    var emoji: String?
    var date: Date?
    var duration: Decimal
    var indefinite: Bool
    var percentage: Double
    var target: Decimal
    var advancedSettings: Bool
    var smbIsOff: Bool
    var smbIsAlwaysOff: Bool
    var smbMinutes: Decimal
    var uamMinutes: Decimal
    var start: Decimal
    var end: Decimal
    var isf: Bool
    var cr: Bool
    var isfAndCr: Bool
    var basal: Bool
    var maxIOB: Decimal
    var overrideMaxIOB: Bool
    // Fields not present in MigratedOverridePresets:
    var overrideAutoISF: Bool?
    var endWIthNewCarbs: Bool?
    var glucoseOverrideThreshold: Decimal?
    var glucoseOverrideThresholdActive: Bool?
    var glucoseOverrideThresholdDown: Decimal?
    var glucoseOverrideThresholdActiveDown: Bool?
}

/// Complete, lossless Codable representation of a `Presets` Core Data
/// entity (meal presets). Covers all attributes including the FoodSearch /
/// nutrition extension fields beyond the base carbs/fat/protein/dish.
struct BackupMealPreset: Codable, Sendable {
    var dish: String
    var carbs: Decimal
    var fat: Decimal
    var protein: Decimal
    // Extended nutrition / food-database fields (orbital):
    var fiber: Decimal?
    var sugars: Decimal?
    var glycemicIndex: Decimal?
    var foodID: UUID?
    var imageURL: String?
    var mealUnits: String?
    var portionSize: Decimal?
    var per100: Bool?
    var standardName: String?
    var standardServing: String?
    var standardServingSize: Decimal?
    var tags: String?
}
