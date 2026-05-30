import Foundation

extension DataTable {
    final class Provider: BaseProvider, DataTableProvider {
        @Injected() var pumpHistoryStorage: PumpHistoryStorage!
        @Injected() var tempTargetsStorage: TempTargetsStorage!
        @Injected() var glucoseStorage: GlucoseStorage!
        @Injected() var carbsStorage: CarbsStorage!
        @Injected() var nightscoutManager: NightscoutManager!
        @Injected() var healthkitManager: HealthKitManager!
        @Injected() var tidepoolManager: TidepoolManager!

        func pumpHistory() -> [PumpHistoryEvent] {
            pumpHistoryStorage.recent()
        }

        func pumpSettings() -> PumpSettings {
            storage.retrieve(OpenAPS.Settings.settings, as: PumpSettings.self)
                ?? PumpSettings(from: OpenAPS.defaults(for: OpenAPS.Settings.settings))
                ?? PumpSettings(insulinActionCurve: 6, maxBolus: 10, maxBasal: 4)
        }

        func tempTargets() -> [TempTarget] {
            tempTargetsStorage.recent()
        }

        func carbs() -> [CarbsEntry] {
            carbsStorage.recent()
        }

        func fpus() -> [CarbsEntry] {
            carbsStorage.recent()
        }

        func deleteCarbs(_ date: Date) {
            // Tidepool delete first — it looks up the entry in storage, which
            // nightscoutManager.deleteCarbs removes.
            tidepoolManager.deleteCarbs(at: date)
            nightscoutManager.deleteCarbs(date)
        }

        /// Tidepool-only carb delete (no Nightscout/HealthKit). Used by the carb edit path,
        /// which handles Nightscout separately.
        func deleteCarbsFromTidepool(at date: Date) {
            tidepoolManager.deleteCarbs(at: date)
        }

        func deleteInsulin(_ treatement: Treatment) {
            if let id = treatement.idPumpEvent {
                // Tidepool first — it looks up the event in storage, which the
                // nightscout/healthkit deletes below remove.
                tidepoolManager.deleteInsulin(syncId: id)
                healthkitManager.deleteInsulin(syncID: id)
            }
            nightscoutManager.deleteInsulin(at: treatement.date)
        }

        func glucose() -> [BloodGlucose] {
            glucoseStorage.retrieveRaw().sorted { $0.date > $1.date }
        }

        func deleteGlucose(id: String) {
            glucoseStorage.removeGlucose(ids: [id])
            healthkitManager.deleteGlucose(syncID: id)
        }

        func deleteManualGlucose(date: Date?) {
            nightscoutManager.deleteManualGlucose(at: date ?? .distantPast)
        }
    }
}
