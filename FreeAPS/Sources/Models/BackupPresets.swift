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

/// Lossless Codable representation of a single `PresetMicronutrient` Core
/// Data entity (the join row between a meal `Presets` and a shared
/// `Micronutrient` definition). The definition's identifying fields
/// (`name`/`type`/`unit`) are flattened inline so restore can recreate the
/// shared definition via fetch-or-create without a separate top-level
/// entity list.
struct BackupPresetMicronutrient: Codable, Sendable {
    /// Micronutrient definition name (e.g. "Vitamin C"). Matches
    /// `Micronutrient.name` — used as the dedup key on restore.
    var name: String
    /// Micronutrient definition type/category (e.g. "Vitamin").
    var type: String
    /// Unit of measure (e.g. "mg").
    var unit: String
    /// Amount stored on the join row. Interpreted as per-100g or absolute
    /// depending on `per100`.
    var amount: Decimal
    /// Whether `amount` is expressed per 100g (true) or as an absolute
    /// amount for the preset's portion (false).
    var per100: Bool
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
    /// Micronutrient breakdown (Micronutrient + PresetMicronutrient
    /// entities). Optional for backward compatibility: older backups predate
    /// the micronutrient schema and decode with this left nil.
    var micronutrients: [BackupPresetMicronutrient]?
}
