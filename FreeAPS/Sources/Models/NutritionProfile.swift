import Foundation

extension Sex: Codable {}

/// Physical activity level → PAL multiplier applied to BMR for the TDEE estimate.
enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var title: String {
        switch self {
        case .sedentary: return statT("stat.activity.sedentary")
        case .light: return statT("stat.activity.light")
        case .moderate: return statT("stat.activity.moderate")
        case .active: return statT("stat.activity.active")
        case .veryActive: return statT("stat.activity.veryActive")
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return statT("stat.activity.sedentary.detail")
        case .light: return statT("stat.activity.light.detail")
        case .moderate: return statT("stat.activity.moderate.detail")
        case .active: return statT("stat.activity.active.detail")
        case .veryActive: return statT("stat.activity.veryActive.detail")
        }
    }
}

/// Self-contained body data used **only** for the Meal tab's RDI calculations
/// (macro + micronutrient progress). Stored independently from the Sharing
/// settings so users who never fill those in still get sensible nutrient targets,
/// and editing it here never touches the share/backup settings.
struct NutritionProfile: Codable, Equatable, Sendable {
    var age: Int
    var sex: Sex
    /// Body weight in kg. `0` means "not set" → macros fall back to the fixed
    /// EFSA / EU reference values.
    var weightKg: Decimal
    /// Body height in cm, used for the Mifflin-St Jeor BMR.
    var heightCm: Decimal
    var activityLevel: ActivityLevel
    /// Protein target in g per kg body weight per day (EFSA min ~0.83, sport ~1.2–2.0).
    var proteinPerKg: Decimal
    /// Fat target as a percentage of daily energy (TDEE).
    var fatPercent: Decimal

    static let `default` = NutritionProfile(
        age: 35,
        sex: .woman,
        weightKg: 75,
        heightCm: 175,
        activityLevel: .moderate,
        proteinPerKg: 1.5,
        fatPercent: 30
    )

    init(
        age: Int,
        sex: Sex,
        weightKg: Decimal,
        heightCm: Decimal,
        activityLevel: ActivityLevel,
        proteinPerKg: Decimal,
        fatPercent: Decimal
    ) {
        self.age = age
        self.sex = sex
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.activityLevel = activityLevel
        self.proteinPerKg = proteinPerKg
        self.fatPercent = fatPercent
    }

    enum CodingKeys: String, CodingKey {
        case age
        case sex
        case weightKg
        case heightCm
        case activityLevel
        case proteinPerKg
        case fatPercent
    }

    /// Tolerant decode so older stored profiles (without height/activity/fatPercent,
    /// or with the previous carbs/fat per-kg factors) still load; missing fields
    /// fall back to the defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NutritionProfile.default
        age = try c.decodeIfPresent(Int.self, forKey: .age) ?? d.age
        sex = try c.decodeIfPresent(Sex.self, forKey: .sex) ?? d.sex
        weightKg = try c.decodeIfPresent(Decimal.self, forKey: .weightKg) ?? d.weightKg
        heightCm = try c.decodeIfPresent(Decimal.self, forKey: .heightCm) ?? d.heightCm
        activityLevel = try c.decodeIfPresent(ActivityLevel.self, forKey: .activityLevel) ?? d.activityLevel
        proteinPerKg = try c.decodeIfPresent(Decimal.self, forKey: .proteinPerKg) ?? d.proteinPerKg
        fatPercent = try c.decodeIfPresent(Decimal.self, forKey: .fatPercent) ?? d.fatPercent
    }
}

extension NutritionProfile {
    private var weight: Double { NSDecimalNumber(decimal: weightKg).doubleValue }
    private var height: Double { NSDecimalNumber(decimal: heightCm).doubleValue }

    /// Whether weight + height are set so a TDEE-based target can be computed.
    var hasBodyData: Bool { weightKg > 0 && heightCm > 0 }

    /// Basal metabolic rate (kcal/day), Mifflin-St Jeor.
    var bmr: Double {
        let base = 10 * weight + 6.25 * height - 5 * Double(age)
        return sex == .man ? base + 5 : base - 161
    }

    /// Total daily energy expenditure (kcal/day) = BMR × activity factor.
    var tdee: Double { max(bmr * activityLevel.factor, 0) }

    /// Resolved daily target (g/day) for a macro, derived from the TDEE:
    /// protein = weight × g/kg, fat = TDEE × fat% / 9 kcal, carbs = remaining kcal / 4.
    /// Falls back to the fixed EFSA / EU reference when body data is missing.
    func targetGrams(for macro: MacroNutrient) -> Double {
        guard hasBodyData, macro != .fiber else {
            return EFSAReferenceIntakes.value(for: macro, age: age, sex: sex).value
        }
        let proteinG = weight * NSDecimalNumber(decimal: proteinPerKg).doubleValue
        let fatKcal = tdee * NSDecimalNumber(decimal: fatPercent).doubleValue / 100
        let carbsKcal = max(tdee - proteinG * 4 - fatKcal, 0)

        switch macro {
        case .protein: return proteinG
        case .fat: return fatKcal / 9
        case .carbs: return carbsKcal / 4
        case .fiber: return EFSAReferenceIntakes.value(for: .fiber, age: age, sex: sex).value
        }
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
