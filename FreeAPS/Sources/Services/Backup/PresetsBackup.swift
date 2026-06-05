import CoreData
import Foundation

/// Reads and writes the Core-Data-backed user presets (override profiles +
/// meal presets) for the backup feature.
///
/// Restore strategy is **replace**: all existing entities in the target
/// store are deleted first, then the entities from the backup are inserted.
/// This matches the mental model "restore to a previous snapshot".
///
/// Safe to call during early app launch (FreeAPSApp.init →
/// EarlyBackupRestore.applyIfPending) — `CoreDataStack.shared` is a static
/// singleton with no Swinject dependencies.
enum PresetsBackup {
    /// Subdirectory under Documents/ where FoodImageStorageManager stores
    /// user-captured meal thumbnails as PNG.
    private static let foodImagesSubdir = "FoodItems"

    // MARK: - Collect (Core Data -> Codable)

    static func collectOverridePresets() -> [BackupOverridePreset] {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        var result: [BackupOverridePreset] = []
        context.performAndWait {
            let request = OverridePresets.fetchRequest() as NSFetchRequest<OverridePresets>
            request.predicate = NSPredicate(format: "name != %@", "" as String)
            guard let items = try? context.fetch(request) else { return }
            result = items.map { item in
                BackupOverridePreset(
                    id: item.id ?? "",
                    name: item.name ?? "",
                    emoji: item.emoji,
                    date: item.date,
                    duration: (item.duration ?? 0) as Decimal,
                    indefinite: item.indefinite,
                    percentage: item.percentage,
                    target: (item.target ?? 0) as Decimal,
                    advancedSettings: item.advancedSettings,
                    smbIsOff: item.smbIsOff,
                    smbIsAlwaysOff: item.smbIsAlwaysOff,
                    smbMinutes: (item.smbMinutes ?? 0) as Decimal,
                    uamMinutes: (item.uamMinutes ?? 0) as Decimal,
                    start: (item.start ?? 0) as Decimal,
                    end: (item.end ?? 0) as Decimal,
                    isf: item.isf,
                    cr: item.cr,
                    isfAndCr: item.isfAndCr,
                    basal: item.basal,
                    maxIOB: (item.maxIOB ?? 0) as Decimal,
                    overrideMaxIOB: item.overrideMaxIOB,
                    overrideAutoISF: item.overrideAutoISF,
                    endWIthNewCarbs: item.endWIthNewCarbs,
                    glucoseOverrideThreshold: (item.glucoseOverrideThreshold ?? 0) as Decimal,
                    glucoseOverrideThresholdActive: item.glucoseOverrideThresholdActive,
                    glucoseOverrideThresholdDown: (item.glucoseOverrideThresholdDown ?? 0) as Decimal,
                    glucoseOverrideThresholdActiveDown: item.glucoseOverrideThresholdActiveDown
                )
            }
        }
        return result
    }

    static func collectMealPresets() -> [BackupMealPreset] {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        var result: [BackupMealPreset] = []
        context.performAndWait {
            let request = Presets.fetchRequest() as NSFetchRequest<Presets>
            guard let items = try? context.fetch(request) else { return }
            result = items.map { item in
                let micronutrients = (item.micronutrient ?? []).compactMap { entry -> BackupPresetMicronutrient? in
                    guard let name = entry.micronutrient.name else { return nil }
                    return BackupPresetMicronutrient(
                        name: name,
                        type: entry.micronutrient.type,
                        unit: entry.micronutrient.unit ?? "",
                        amount: (entry.amount ?? 0) as Decimal,
                        per100: entry.per100
                    )
                }
                return BackupMealPreset(
                    dish: item.dish ?? "",
                    carbs: (item.carbs ?? 0) as Decimal,
                    fat: (item.fat ?? 0) as Decimal,
                    protein: (item.protein ?? 0) as Decimal,
                    fiber: (item.fiber ?? 0) as Decimal,
                    sugars: (item.sugars ?? 0) as Decimal,
                    glycemicIndex: (item.glycemicIndex ?? 0) as Decimal,
                    foodID: item.foodID,
                    imageURL: item.imageURL,
                    mealUnits: item.mealUnits,
                    portionSize: (item.portionSize ?? 0) as Decimal,
                    per100: item.per100,
                    standardName: item.standardName,
                    standardServing: item.standardServing,
                    standardServingSize: (item.standardServingSize ?? 0) as Decimal,
                    tags: item.tags,
                    micronutrients: micronutrients.isEmpty ? nil : micronutrients
                )
            }
        }
        return result
    }

    // MARK: - Restore (Codable -> Core Data, replace strategy)

    static func restoreOverridePresets(_ presets: [BackupOverridePreset]) {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        context.performAndWait {
            let request = OverridePresets.fetchRequest() as NSFetchRequest<OverridePresets>
            if let existing = try? context.fetch(request) {
                for entity in existing { context.delete(entity) }
            }

            for preset in presets {
                let entity = OverridePresets(context: context)
                entity.id = preset.id
                entity.name = preset.name
                entity.emoji = preset.emoji
                entity.date = preset.date
                entity.duration = preset.duration as NSDecimalNumber
                entity.indefinite = preset.indefinite
                entity.percentage = preset.percentage
                entity.target = preset.target as NSDecimalNumber
                entity.advancedSettings = preset.advancedSettings
                entity.smbIsOff = preset.smbIsOff
                entity.smbIsAlwaysOff = preset.smbIsAlwaysOff
                entity.smbMinutes = preset.smbMinutes as NSDecimalNumber
                entity.uamMinutes = preset.uamMinutes as NSDecimalNumber
                entity.start = preset.start as NSDecimalNumber
                entity.end = preset.end as NSDecimalNumber
                entity.isf = preset.isf
                entity.cr = preset.cr
                entity.isfAndCr = preset.isfAndCr
                entity.basal = preset.basal
                entity.maxIOB = preset.maxIOB as NSDecimalNumber
                entity.overrideMaxIOB = preset.overrideMaxIOB
                entity.overrideAutoISF = preset.overrideAutoISF ?? false
                entity.endWIthNewCarbs = preset.endWIthNewCarbs ?? false
                entity.glucoseOverrideThreshold = (preset.glucoseOverrideThreshold ?? 100) as NSDecimalNumber
                entity.glucoseOverrideThresholdActive = preset.glucoseOverrideThresholdActive ?? false
                entity.glucoseOverrideThresholdDown = (preset.glucoseOverrideThresholdDown ?? 90) as NSDecimalNumber
                entity.glucoseOverrideThresholdActiveDown = preset.glucoseOverrideThresholdActiveDown ?? false
            }

            try? context.save()
        }
    }

    static func restoreMealPresets(_ presets: [BackupMealPreset]) {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        context.performAndWait {
            let request = Presets.fetchRequest() as NSFetchRequest<Presets>
            if let existing = try? context.fetch(request) {
                for entity in existing { context.delete(entity) }
            }

            for preset in presets {
                let entity = Presets(context: context)
                entity.dish = preset.dish
                entity.carbs = preset.carbs as NSDecimalNumber
                entity.fat = preset.fat as NSDecimalNumber
                entity.protein = preset.protein as NSDecimalNumber
                if let fiber = preset.fiber { entity.fiber = fiber as NSDecimalNumber }
                if let sugars = preset.sugars { entity.sugars = sugars as NSDecimalNumber }
                if let glycemicIndex = preset.glycemicIndex { entity.glycemicIndex = glycemicIndex as NSDecimalNumber }
                entity.foodID = preset.foodID
                entity.imageURL = preset.imageURL
                entity.mealUnits = preset.mealUnits
                if let portionSize = preset.portionSize { entity.portionSize = portionSize as NSDecimalNumber }
                if let per100 = preset.per100 { entity.per100 = per100 }
                entity.standardName = preset.standardName
                entity.standardServing = preset.standardServing
                if let standardServingSize = preset.standardServingSize {
                    entity.standardServingSize = standardServingSize as NSDecimalNumber
                }
                entity.tags = preset.tags

                // Rebuild micronutrient join rows + shared definitions.
                // setMicronutrient does fetch-or-create on the Micronutrient
                // definition (by name), so definitions are deduplicated across
                // presets within this batch.
                for micro in preset.micronutrients ?? [] {
                    try? entity.setMicronutrient(
                        name: micro.name,
                        type: micro.type,
                        unit: micro.unit,
                        amount: micro.amount,
                        per100: micro.per100,
                        context: context
                    )
                }
            }

            try? context.save()
        }
    }

    // MARK: - Meal thumbnail images

    /// Read every PNG under Documents/FoodItems/ as raw Data, keyed by the
    /// file's base name (the UUID part of `local://<UUID>` imageURLs).
    /// Returns an empty dictionary if the directory doesn't exist — e.g. on
    /// builds without FoodSearch or before any local image was captured.
    static func collectMealImages() -> [String: Data] {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return [:]
        }
        let folder = documents.appendingPathComponent(foodImagesSubdir, isDirectory: true)
        guard fm.fileExists(atPath: folder.path) else { return [:] }

        guard let contents = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return [:] }

        var result: [String: Data] = [:]
        for url in contents where url.pathExtension.lowercased() == "png" {
            guard let data = try? Data(contentsOf: url) else { continue }
            let key = url.deletingPathExtension().lastPathComponent
            result[key] = data
        }
        return result
    }

    /// Write the supplied PNG payloads back to Documents/FoodItems/<key>.png,
    /// creating the directory if needed. Existing files with the same names
    /// are overwritten (replace strategy, consistent with the rest of the
    /// preset restore path).
    static func restoreMealImages(_ images: [String: Data]) {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let folder = documents.appendingPathComponent(foodImagesSubdir, isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        for (key, data) in images {
            let fileURL = folder.appendingPathComponent("\(key).png")
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                NSLog("[Backup] failed to write meal image \(key).png: \(error)")
            }
        }
    }
}
