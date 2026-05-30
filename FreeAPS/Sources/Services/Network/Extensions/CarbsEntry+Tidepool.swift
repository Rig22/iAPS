import Foundation
import LoopKit

extension CarbsEntry {
    /// True for the pseudo-carb entries iAPS generates from Fat-Protein-Units.
    /// We skip these when uploading because they are not real carb intake.
    var isFPUEntry: Bool { isFPU == true }

    private var stableSyncIdentifier: String {
        if let id = id, !id.isEmpty { return id }
        // Fallback when an entry came in without an id (e.g. older backfills).
        // createdAt is unique enough in practice — iAPS stores carbs with second resolution.
        return "iaps-\(Int(createdAt.timeIntervalSince1970))"
    }

    /// Builds the LoopKit type Tidepool expects in `uploadCarbData`.
    func asSyncCarbObject(provenance: String, operation: LoopKit.Operation = .create) -> SyncCarbObject {
        SyncCarbObject(
            absorptionTime: nil,
            createdByCurrentApp: enteredBy != CarbsEntry.remote,
            foodType: note,
            grams: Double(truncating: carbs as NSNumber),
            startDate: actualDate ?? createdAt,
            uuid: nil,
            provenanceIdentifier: provenance,
            syncIdentifier: stableSyncIdentifier,
            syncVersion: 1,
            userCreatedDate: createdAt,
            userUpdatedDate: nil,
            userDeletedDate: operation == .delete ? createdAt : nil,
            operation: operation,
            addedDate: createdAt,
            supercededDate: nil
        )
    }
}
