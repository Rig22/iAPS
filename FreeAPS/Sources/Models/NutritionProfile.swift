import Foundation

extension Sex: Codable {}

/// Self-contained body data used **only** for the Meal tab's RDI calculations
/// (macro + micronutrient progress). Stored independently from the Sharing
/// settings so users who never fill those in still get sensible nutrient targets,
/// and editing it here never touches the share/backup settings.
struct NutritionProfile: Codable, Equatable, Sendable {
    var age: Int
    var sex: Sex
    /// Body weight in kg. `0` means "not set" → all macros fall back to the
    /// weight-independent EFSA / EU reference values.
    var weightKg: Decimal
    /// Macro targets in g per kg body weight per day. When a weight is set, each
    /// macro reference = weightKg × factor.
    /// Protein: EFSA min ~0.83, health/sport ~1.2–2.0 (default 1.5).
    /// Carbs/fat defaults (3.0 / 1.0) roughly match the EU reference intakes at ~85 kg.
    var proteinPerKg: Decimal
    var carbsPerKg: Decimal
    var fatPerKg: Decimal

    static let `default` = NutritionProfile(
        age: 35,
        sex: .woman,
        weightKg: 75,
        proteinPerKg: 1.5,
        carbsPerKg: 3.0,
        fatPerKg: 1.0
    )
}

extension NutritionProfile {
    func perKgFactor(for macro: MacroNutrient) -> Decimal {
        switch macro {
        case .protein: return proteinPerKg
        case .carbs: return carbsPerKg
        case .fat: return fatPerKg
        case .fiber: return 0
        }
    }

    /// Resolved daily target (g/day) for a macro: weight-based when a weight is
    /// set, otherwise the weight-independent EFSA / EU reference value.
    func targetGrams(for macro: MacroNutrient) -> Double {
        if weightKg > 0, macro != .fiber {
            return NSDecimalNumber(decimal: weightKg * perKgFactor(for: macro)).doubleValue
        }
        return EFSAReferenceIntakes.value(for: macro, age: age, sex: sex).value
    }

    /// Resolved protein target (g/day).
    var proteinTargetGrams: Double { targetGrams(for: .protein) }

    var individual: Individual {
        Individual(age: age, sex: sex)
    }
}

extension NutritionProfile: JSON {}

// MARK: - Persistence

/// Stored as its own JSON file (`OpenAPS.FreeAPS.nutritionProfile`) so it is
/// captured by the settings backup (see `BackupBundle.canonicalFiles`) and
/// restored automatically. Independent from the Sharing settings.
enum NutritionProfileStore {
    static let path = OpenAPS.FreeAPS.nutritionProfile
    private static let legacyDefaultsKey = "mealNutritionProfile"

    static func load(_ storage: FileStorage) -> NutritionProfile? {
        storage.retrieve(path, as: NutritionProfile.self)
    }

    static func save(_ profile: NutritionProfile, _ storage: FileStorage) {
        storage.save(profile, as: path)
    }

    /// Returns the stored profile; on first use migrates a value from the previous
    /// UserDefaults store if present, otherwise seeds one from the given fallback
    /// age/sex (typically derived from the Sharing settings) and persists it.
    static func loadOrSeed(_ storage: FileStorage, fallbackAge: Int, fallbackSex: Sex) -> NutritionProfile {
        if let existing = load(storage) { return existing }

        // One-time migration from the previous UserDefaults-backed store.
        if let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
           let migrated = try? JSONDecoder().decode(NutritionProfile.self, from: data)
        {
            save(migrated, storage)
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            return migrated
        }

        var seeded = NutritionProfile.default
        seeded.age = fallbackAge
        seeded.sex = fallbackSex
        save(seeded, storage)
        return seeded
    }
}

// MARK: - Macro RDI helpers (profile-aware)

extension MacroNutrient {
    /// Daily reference value for this macro under the given profile. When a body
    /// weight is set, the target scales with weight (weightKg × per-kg factor);
    /// otherwise the fixed EFSA / EU reference intake is used.
    func referenceValue(profile: NutritionProfile) -> Double {
        profile.targetGrams(for: self)
    }
}

extension MicronutrientProgress {
    /// Macro progress against a (possibly weight-based) profile target.
    static func progress(
        macro: MacroNutrient,
        amount: Double,
        profile: NutritionProfile
    ) -> NutrientProgress {
        let reference = macro.referenceValue(profile: profile)

        guard reference > 0 else {
            return NutrientProgress(percent: 0, color: .secondary)
        }

        let percent = (amount / reference) * 100
        return NutrientProgress(
            percent: percent,
            color: NutrientProgressColor.color(nutrient: macro, percent: percent)
        )
    }
}
