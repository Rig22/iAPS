import Algorithms
import Combine
import CryptoKit
import Foundation
import HealthKit
import LoopKit
import LoopKitUI
import Swinject
import TidepoolServiceKit
import UIKit

protocol TidepoolManager {
    func addTidepoolService(service: Service)
    func getTidepoolServiceUI() -> ServiceUI?
    func getTidepoolPluginHost() -> PluginHost?
    func hasTidepoolService() -> Bool
    func deleteTidepoolService()
    func uploadGlucose() async
    func uploadCarbs() async
    func uploadInsulin() async
    func uploadSettings() async
    func forceTidepoolDataUpload()
}

final class BaseTidepoolManager: TidepoolManager, Injectable {
    @Injected() private var broadcaster: Broadcaster!
    @Injected() private var glucoseStorage: GlucoseStorage!
    @Injected() private var carbsStorage: CarbsStorage!
    @Injected() private var pumpHistoryStorage: PumpHistoryStorage!
    @Injected() private var storage: FileStorage!
    @Injected() private var settingsManager: SettingsManager!

    private let processQueue = DispatchQueue(label: "BaseTidepoolManager.processQueue")
    private var subscriptions = Set<AnyCancellable>()

    /// Stored so pump status can be resolved lazily, avoiding an eager DI cycle
    /// (TidepoolManager → DeviceDataManager → … ) at init time.
    private var resolver: Resolver?
    private var deviceDataManager: DeviceDataManager? {
        resolver?.resolve(DeviceDataManager.self)
    }

    /// Holds the active Tidepool service. Persisted between launches via `rawTidepoolService`.
    private var tidepoolService: RemoteDataService? {
        didSet {
            rawTidepoolService = tidepoolService?.rawValue
        }
    }

    @PersistedProperty(key: "TidepoolState") var rawTidepoolService: Service.RawValue?

    /// Cursor for incremental glucose uploads — only readings strictly newer than this date are sent.
    @Persisted(key: "TidepoolGlucoseLastUploadDate") private var lastGlucoseUploadDate: Date = .distantPast

    /// Cursor for incremental carb uploads — keyed on `createdAt` (when iAPS stored the entry).
    @Persisted(key: "TidepoolCarbsLastUploadDate") private var lastCarbsUploadDate: Date = .distantPast

    /// Cursor for incremental insulin/dose uploads — keyed on event `timestamp`.
    @Persisted(key: "TidepoolInsulinLastUploadDate") private var lastInsulinUploadDate: Date = .distantPast

    /// Cursor for incremental non-dose pump event uploads (alarms, prime, rewind).
    @Persisted(key: "TidepoolPumpEventLastUploadDate") private var lastPumpEventUploadDate: Date = .distantPast

    /// Last uploaded settings sync identifier — used to skip re-uploading unchanged therapy settings.
    @Persisted(key: "TidepoolLastSettingsSyncId") private var lastSettingsSyncId: String = ""

    init(resolver: Resolver) {
        self.resolver = resolver
        injectServices(resolver)
        loadTidepoolService()
        subscribe()
    }

    private func subscribe() {
        broadcaster.register(GlucoseObserver.self, observer: self)
        broadcaster.register(CarbsObserver.self, observer: self)
        broadcaster.register(PumpHistoryObserver.self, observer: self)
        broadcaster.register(SettingsObserver.self, observer: self)
    }

    /// Restores the persisted Tidepool service on app launch.
    private func loadTidepoolService() {
        guard let raw = rawTidepoolService else { return }
        tidepoolService = tidepoolServiceFromRaw(raw)
        tidepoolService?.serviceDelegate = self
        tidepoolService?.stateDelegate = self
    }

    private func tidepoolServiceFromRaw(_ rawValue: [String: Any]) -> RemoteDataService? {
        guard let rawState = rawValue["state"] as? StatefulPluggable.RawStateValue,
              let service = TidepoolService(rawState: rawState)
        else { return nil }
        return service
    }

    func addTidepoolService(service: Service) {
        guard let remote = service as? RemoteDataService else { return }
        tidepoolService = remote
        tidepoolService?.serviceDelegate = self
        tidepoolService?.stateDelegate = self
    }

    func getTidepoolServiceUI() -> ServiceUI? {
        tidepoolService as? ServiceUI
    }

    func getTidepoolPluginHost() -> PluginHost? {
        self as PluginHost
    }

    func hasTidepoolService() -> Bool {
        tidepoolService != nil
    }

    func deleteTidepoolService() {
        tidepoolService = nil
    }

    func forceTidepoolDataUpload() {
        Task {
            await uploadInsulin()
            await uploadCarbs()
            await uploadGlucose()
            await uploadSettings()
        }
    }

    // MARK: - Upload entry points

    func uploadGlucose() async {
        guard let service = tidepoolService else { return }

        let cursor = lastGlucoseUploadDate
        let provenance = hostIdentifier

        let samples: [StoredGlucoseSample] = glucoseStorage.retrieve()
            .filter { $0.dateString > cursor }
            .compactMap { $0.asStoredGlucoseSample(provenance: provenance) }

        guard !samples.isEmpty else { return }

        let limit = service.glucoseDataLimit ?? 100
        let chunks = samples.chunks(ofCount: limit).map { Array($0) }
        let newestDate = samples.map(\.startDate).max() ?? cursor

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            var anyFailed = false

            for chunk in chunks {
                group.enter()
                service.uploadGlucoseData(chunk) { result in
                    if case let .failure(error) = result {
                        anyFailed = true
                        debug(.service, "Tidepool glucose upload failed: \(error)")
                    }
                    group.leave()
                }
            }

            group.notify(queue: self.processQueue) {
                if !anyFailed {
                    self.lastGlucoseUploadDate = newestDate
                    debug(.service, "Tidepool glucose upload OK (\(samples.count) samples)")
                }
                continuation.resume()
            }
        }
    }

    func uploadCarbs() async {
        guard let service = tidepoolService else { return }

        let cursor = lastCarbsUploadDate
        let provenance = hostIdentifier

        // iAPS' carbHistory contains both real carbs and FPU-derived pseudo-carbs.
        // We only upload real intake.
        let entries = carbsStorage.recent()
            .filter { !$0.isFPUEntry }
            .filter { $0.createdAt > cursor }

        guard !entries.isEmpty else { return }

        let created = entries.map { $0.asSyncCarbObject(provenance: provenance, operation: .create) }
        let limit = service.carbDataLimit ?? 100
        let chunks = created.chunks(ofCount: limit).map { Array($0) }
        let newestDate = entries.map(\.createdAt).max() ?? cursor

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            var anyFailed = false

            for chunk in chunks {
                group.enter()
                service.uploadCarbData(created: chunk, updated: [], deleted: []) { result in
                    if case let .failure(error) = result {
                        anyFailed = true
                        debug(.service, "Tidepool carbs upload failed: \(error)")
                    }
                    group.leave()
                }
            }

            group.notify(queue: self.processQueue) {
                if !anyFailed {
                    self.lastCarbsUploadDate = newestDate
                    debug(.service, "Tidepool carbs upload OK (\(created.count) entries)")
                }
                continuation.resume()
            }
        }
    }

    func uploadInsulin() async {
        guard let service = tidepoolService else { return }

        let cursor = lastInsulinUploadDate
        let provenance = hostIdentifier
        let events = pumpHistoryStorage.recent().filter { $0.timestamp > cursor }

        let doses = events.toDoseEntries(provenance: provenance)
        let pumpEvents = events.toPersistedPumpEvents()

        async let dosesOk = uploadDoses(doses, service: service)
        async let eventsOk = uploadPumpEvents(pumpEvents, service: service)

        let (a, b) = await (dosesOk, eventsOk)
        let newestDate = events.map(\.timestamp).max() ?? cursor
        if a, b {
            lastInsulinUploadDate = newestDate
            lastPumpEventUploadDate = newestDate
        }
    }

    private func uploadDoses(_ doses: [DoseEntry], service: RemoteDataService) async -> Bool {
        guard !doses.isEmpty else { return true }
        let limit = service.doseDataLimit ?? 100
        let chunks = doses.chunks(ofCount: limit).map { Array($0) }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let group = DispatchGroup()
            var anyFailed = false
            for chunk in chunks {
                group.enter()
                service.uploadDoseData(created: chunk, deleted: []) { result in
                    if case let .failure(error) = result {
                        anyFailed = true
                        debug(.service, "Tidepool dose upload failed: \(error)")
                    }
                    group.leave()
                }
            }
            group.notify(queue: self.processQueue) {
                if !anyFailed {
                    debug(.service, "Tidepool dose upload OK (\(doses.count) doses)")
                }
                continuation.resume(returning: !anyFailed)
            }
        }
    }

    private func uploadPumpEvents(_ events: [PersistedPumpEvent], service: RemoteDataService) async -> Bool {
        guard !events.isEmpty else { return true }
        let limit = service.pumpEventDataLimit ?? 100
        let chunks = events.chunks(ofCount: limit).map { Array($0) }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let group = DispatchGroup()
            var anyFailed = false
            for chunk in chunks {
                group.enter()
                service.uploadPumpEventData(chunk) { result in
                    if case let .failure(error) = result {
                        anyFailed = true
                        debug(.service, "Tidepool pump-event upload failed: \(error)")
                    }
                    group.leave()
                }
            }
            group.notify(queue: self.processQueue) {
                if !anyFailed {
                    debug(.service, "Tidepool pump-event upload OK (\(events.count) events)")
                }
                continuation.resume(returning: !anyFailed)
            }
        }
    }

    func uploadSettings() async {
        guard let service = tidepoolService, let settings = createStoredSettings() else { return }

        // Skip re-upload if therapy settings are unchanged since last successful upload.
        let syncId = settings.syncIdentifier.uuidString
        guard syncId != lastSettingsSyncId else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.uploadSettingsData([settings]) { result in
                switch result {
                case .success:
                    self.lastSettingsSyncId = syncId
                    debug(.service, "Tidepool settings upload OK")
                case let .failure(error):
                    debug(.service, "Tidepool settings upload failed: \(error)")
                }
                continuation.resume()
            }
        }
    }

    /// Assembles a LoopKit `StoredSettings` snapshot from iAPS' oref therapy files + pump status.
    private func createStoredSettings() -> StoredSettings? {
        guard
            let basalProfile = storage.retrieve(OpenAPS.Settings.basalProfile, as: [BasalProfileEntry].self),
            let carbRatios = storage.retrieve(OpenAPS.Settings.carbRatios, as: CarbRatios.self),
            let isf = storage.retrieve(OpenAPS.Settings.insulinSensitivities, as: InsulinSensitivities.self),
            let bgTargets = storage.retrieve(OpenAPS.Settings.bgTargets, as: BGTargets.self)
        else {
            debug(.service, "Tidepool: therapy settings incomplete, skipping settings upload")
            return nil
        }

        let pumpSettings = settingsManager.pumpSettings
        let preferences: Preferences? = storage.retrieve(OpenAPS.Settings.preferences, as: Preferences.self)
        let dosingEnabled = settingsManager.settings.closedLoop
        let pumpStatus = deviceDataManager?.pumpManager?.status
        let insulinType = pumpStatus?.insulinType

        let suspendThreshold = preferences.map {
            GlucoseThreshold(unit: .milligramsPerDeciliter, value: Double($0.threshold_setting))
        }

        let insulinModel: StoredInsulinModel? = preferences.map {
            $0.asStoredInsulinModel(insulinType: insulinType, dia: Double(pumpSettings.insulinActionCurve))
        }

        return StoredSettings(
            date: Date(),
            controllerTimeZone: TimeZone.current,
            dosingEnabled: dosingEnabled,
            glucoseTargetRangeSchedule: bgTargets.asGlucoseRangeSchedule(),
            preMealTargetRange: nil,
            workoutTargetRange: nil,
            overridePresets: nil,
            scheduleOverride: nil,
            preMealOverride: nil,
            maximumBasalRatePerHour: Double(pumpSettings.maxBasal),
            maximumBolus: Double(pumpSettings.maxBolus),
            suspendThreshold: suspendThreshold,
            insulinType: insulinType,
            defaultRapidActingModel: insulinModel,
            basalRateSchedule: basalProfile.asBasalRateSchedule(),
            insulinSensitivitySchedule: isf.asInsulinSensitivitySchedule(),
            carbRatioSchedule: carbRatios.asCarbRatioSchedule(),
            notificationSettings: nil,
            controllerDevice: createControllerDevice(),
            cgmDevice: nil,
            pumpDevice: pumpStatus?.device,
            bloodGlucoseUnit: settingsManager.settings.units.hkUnit,
            syncIdentifier: contentBasedSyncIdentifier(
                basalProfile: basalProfile,
                carbRatios: carbRatios,
                insulinSensitivities: isf,
                bgTargets: bgTargets,
                pumpSettings: pumpSettings,
                preferences: preferences,
                dosingEnabled: dosingEnabled
            )
        )
    }

    private func createControllerDevice() -> StoredSettings.ControllerDevice {
        let device = UIDevice.current
        return StoredSettings.ControllerDevice(
            name: "iAPS",
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            model: device.model,
            modelIdentifier: device.model
        )
    }

    /// Deterministic UUID over therapy-relevant content. Unchanged settings produce the same
    /// identifier so Tidepool can dedupe server-side and we skip redundant uploads.
    private func contentBasedSyncIdentifier(
        basalProfile: [BasalProfileEntry],
        carbRatios: CarbRatios,
        insulinSensitivities: InsulinSensitivities,
        bgTargets: BGTargets,
        pumpSettings: PumpSettings,
        preferences: Preferences?,
        dosingEnabled: Bool
    ) -> UUID {
        var hasher = SHA256()
        for e in basalProfile { hasher.update(data: Data("\(e.minutes):\(e.rate)".utf8)) }
        for e in carbRatios.schedule { hasher.update(data: Data("\(e.offset):\(e.ratio)".utf8)) }
        for e in insulinSensitivities.sensitivities { hasher.update(data: Data("\(e.offset):\(e.sensitivity)".utf8)) }
        for e in bgTargets.targets { hasher.update(data: Data("\(e.offset):\(e.low):\(e.high)".utf8)) }
        hasher.update(data: Data("maxBasal:\(pumpSettings.maxBasal)".utf8))
        hasher.update(data: Data("maxBolus:\(pumpSettings.maxBolus)".utf8))
        if let prefs = preferences { hasher.update(data: Data("threshold:\(prefs.threshold_setting)".utf8)) }
        hasher.update(data: Data("dosingEnabled:\(dosingEnabled)".utf8))

        let bytes = Array(hasher.finalize().prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

// MARK: - GlucoseObserver

extension BaseTidepoolManager: GlucoseObserver {
    func glucoseDidUpdate(_: [BloodGlucose]) {
        Task { await uploadGlucose() }
    }
}

// MARK: - CarbsObserver

extension BaseTidepoolManager: CarbsObserver {
    func carbsDidUpdate(_: [CarbsEntry]) {
        Task { await uploadCarbs() }
    }
}

// MARK: - PumpHistoryObserver

extension BaseTidepoolManager: PumpHistoryObserver {
    func pumpHistoryDidUpdate(_: [PumpHistoryEvent]) {
        Task { await uploadInsulin() }
    }
}

// MARK: - SettingsObserver

extension BaseTidepoolManager: SettingsObserver {
    func settingsDidChange(_: FreeAPSSettings) {
        Task { await uploadSettings() }
    }
}

// MARK: - ServiceDelegate

extension BaseTidepoolManager: ServiceDelegate {
    var hostIdentifier: String {
        "org.artificial-pancreas.iAPS"
    }

    var hostVersion: String {
        var semantic = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
        while semantic.split(separator: ".").count < 3 { semantic += ".0" }
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
        return semantic + "+" + build
    }

    func issueAlert(_: LoopKit.Alert) {}
    func retractAlert(identifier _: LoopKit.Alert.Identifier) {}

    func enactRemoteOverride(name _: String, durationTime _: TimeInterval?, remoteAddress _: String) async throws {}
    func cancelRemoteOverride() async throws {}
    func deliverRemoteCarbs(
        amountInGrams _: Double,
        absorptionTime _: TimeInterval?,
        foodType _: String?,
        startDate _: Date?
    ) async throws {}
    func deliverRemoteBolus(amountInUnits _: Double) async throws {}
}

// MARK: - StatefulPluggableDelegate

extension BaseTidepoolManager: StatefulPluggableDelegate {
    func pluginDidUpdateState(_ plugin: StatefulPluggable) {
        guard let service = plugin as? RemoteDataService else { return }
        rawTidepoolService = service.rawValue
    }

    func pluginWantsDeletion(_: StatefulPluggable) {
        deleteTidepoolService()
    }
}
