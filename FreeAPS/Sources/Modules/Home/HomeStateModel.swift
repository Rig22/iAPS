import Combine
import CoreData
import DanaKit
import LoopKitUI
import SwiftDate
import SwiftUI

extension Home {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var broadcaster: Broadcaster!
        @Injected() var apsManager: APSManager!
        @Injected() var nightscoutManager: NightscoutManager!
        @Injected() var storage: TempTargetsStorage!
        private let timer = DispatchTimer(timeInterval: 5)
        private(set) var filteredHours = 24
        @Published var glucose: [BloodGlucose] = []
        @Published var isManual: [BloodGlucose] = []
        @Published var announcement: [Announcement] = []
        @Published var suggestion: Suggestion?
        @Published var dynamicVariables: DynamicVariables?
        @Published var uploadStats = false
        @Published var enactedSuggestion: Suggestion?
        @Published var recentGlucose: BloodGlucose?
        @Published var glucoseDelta: Int?
        @Published var tempBasals: [PumpHistoryEvent] = []
        @Published var boluses: [PumpHistoryEvent] = []
        @Published var suspensions: [PumpHistoryEvent] = []
        @Published var maxBasal: Decimal = 2
        @Published var autotunedBasalProfile: [BasalProfileEntry] = []
        @Published var basalProfile: [BasalProfileEntry] = []
        @Published var tempTargets: [TempTarget] = []
        @Published var carbs: [CarbsEntry] = []
        @Published var timerDate = Date()
        @Published var closedLoop = false
        @Published var pumpSuspended = false
        @Published var isLooping = false
        @Published var statusTitle = ""
        @Published var lastLoopDate: Date = .distantPast
        @Published var tempRate: Decimal?
        @Published var battery: Battery?
        @Published var reservoir: Decimal?
        @Published var pumpName = ""
        @Published var pumpExpiresAtDate: Date?
        @Published var tempTarget: TempTarget?
        @Published var setupPump = false
        @Published var errorMessage: String? = nil
        @Published var errorDate: Date? = nil
        @Published var bolusProgress: Decimal?
        @Published var bolusAmount: Decimal?
        @Published var eventualBG: Int?
        @Published var isf: Decimal?
        @Published var carbsRequired: Decimal?
        @Published var allowManualTemp = false
        @Published var units: GlucoseUnits = .mmolL
        @Published var pumpDisplayState: PumpDisplayState?
        @Published var alarm: GlucoseAlarm?
        @Published var animatedBackground = false
        @Published var manualTempBasal = false
        @Published var smooth = false
        @Published var maxValue: Decimal = 1.2
        @Published var lowGlucose: Decimal = 4 / 0.0555
        @Published var highGlucose: Decimal = 10 / 0.0555
        @Published var overrideUnit: Bool = false
        @Published var displayXgridLines: Bool = false
        @Published var displayYgridLines: Bool = false
        @Published var thresholdLines: Bool = false
        @Published var timeZone: TimeZone?
        @Published var hours: Int = 6
        @Published var totalBolus: Decimal = 0
        @Published var isStatusPopupPresented: Bool = false
        @Published var readings: [Readings] = []
        @Published var loopStatistics: (Int, Int, Double, String) = (0, 0, 0, "")
        @Published var standing: Bool = false
        @Published var preview: Bool = true
        @Published var useTargetButton: Bool = false
        @Published var overrideHistory: [OverrideHistory] = []
        @Published var overrides: [Override] = []
        @Published var alwaysUseColors: Bool = true
        // Dana UI Toggels
        @Published var timeSettings: Bool = true
        @Published var danaIcon: Bool = true
        @Published var legendsSwitch: Bool = true
        @Published var danaBar: Bool = true
        @Published var tempTargetbar: Bool = true
        // Dana UI Toggels
        @Published var useCalc: Bool = true
        @Published var minimumSMB: Decimal = 0.3
        @Published var maxBolus: Decimal = 0
        @Published var maxBolusValue: Decimal = 1
        @Published var useInsulinBars: Bool = false
        @Published var iobData: [IOBData] = []
        @Published var neg: Int = 0
        @Published var tddChange: Decimal = 0
        @Published var tddAverage: Decimal = 0
        @Published var tddYesterday: Decimal = 0
        @Published var tdd2DaysAgo: Decimal = 0
        @Published var tdd3DaysAgo: Decimal = 0
        @Published var tddActualAverage: Decimal = 0
        @Published var skipGlucoseChart: Bool = false
        // specialDanaKitFunction
        @Published var pumpBatteryChargeRemaining: String?
        @Published var isConnected: Bool = false
        @Published var bluetooth: Bool = true
        @Published var cannulaDate: Date?
        @Published var cannulaAge: String?
        @Published var cannulaHours: Double?
        @Published var reservoirDate: Date?
        @Published var reservoirLevel: Double? = 0
        @Published var reservoirAge: String?
        @Published var insulinType: String?
        //

        let coredataContext = CoreDataStack.shared.persistentContainer.viewContext

        override func subscribe() {
            setupGlucose()
            setupBasals()
            setupBoluses()
            setupSuspensions()
            setupPumpSettings()
            setupBasalProfile()
            setupTempTargets()
            setupCarbs()
            setupBattery()
            setupReservoir()
            setupAnnouncements()
            setupCurrentPumpTimezone()
            setupOverrideHistory()
            setupLoopStats()
            setupData()

            // iobData = provider.reasons()
            suggestion = provider.suggestion
            dynamicVariables = provider.dynamicVariables
            overrideHistory = provider.overrideHistory()
            uploadStats = settingsManager.settings.uploadStats
            enactedSuggestion = provider.enactedSuggestion
            units = settingsManager.settings.units
            allowManualTemp = !settingsManager.settings.closedLoop
            closedLoop = settingsManager.settings.closedLoop
            lastLoopDate = apsManager.lastLoopDate
            carbsRequired = suggestion?.carbsReq
            alarm = provider.glucoseStorage.alarm
            manualTempBasal = apsManager.isManualTempBasal
            setStatusTitle()
            setupCurrentTempTarget()
            smooth = settingsManager.settings.smoothGlucose
            maxValue = settingsManager.preferences.autosensMax
            lowGlucose = settingsManager.settings.low
            highGlucose = settingsManager.settings.high
            overrideUnit = settingsManager.settings.overrideHbA1cUnit
            displayXgridLines = settingsManager.settings.xGridLines
            displayYgridLines = settingsManager.settings.yGridLines
            thresholdLines = settingsManager.settings.rulerMarks
            useTargetButton = settingsManager.settings.useTargetButton
            hours = settingsManager.settings.hours
            alwaysUseColors = settingsManager.settings.alwaysUseColors

            // Dana UI Toggels
            timeSettings = settingsManager.settings.timeSettings
            danaIcon = settingsManager.settings.danaIcon
            legendsSwitch = settingsManager.settings.legendsSwitch
            danaBar = settingsManager.settings.danaBar
            tempTargetbar = settingsManager.settings.tempTargetbar
            // Dana UI Toggels

            useCalc = settingsManager.settings.useCalc
            minimumSMB = settingsManager.settings.minimumSMB
            maxBolus = settingsManager.pumpSettings.maxBolus
            useInsulinBars = settingsManager.settings.useInsulinBars
            skipGlucoseChart = settingsManager.settings.skipGlucoseChart

            broadcaster.register(GlucoseObserver.self, observer: self)
            broadcaster.register(SuggestionObserver.self, observer: self)
            broadcaster.register(SettingsObserver.self, observer: self)
            broadcaster.register(PumpHistoryObserver.self, observer: self)
            broadcaster.register(PumpSettingsObserver.self, observer: self)
            broadcaster.register(BasalProfileObserver.self, observer: self)
            broadcaster.register(TempTargetsObserver.self, observer: self)
            broadcaster.register(CarbsObserver.self, observer: self)
            broadcaster.register(EnactedSuggestionObserver.self, observer: self)
            broadcaster.register(PumpBatteryObserver.self, observer: self)
            broadcaster.register(PumpReservoirObserver.self, observer: self)
            broadcaster.register(PumpTimeZoneObserver.self, observer: self)
            animatedBackground = settingsManager.settings.animatedBackground

            subscribeSetting(\.hours, on: $hours, initial: {
                let value = max(min($0, 24), 2)
                hours = value
            }, map: {
                $0
            })

            timer.eventHandler = {
                DispatchQueue.main.async { [weak self] in
                    self?.timerDate = Date()
                    self?.setupCurrentTempTarget()
                }
            }
            timer.resume()

            apsManager.isLooping
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.isLooping, on: self)
                .store(in: &lifetime)

            apsManager.lastLoopDateSubject
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.lastLoopDate, on: self)
                .store(in: &lifetime)

            apsManager.pumpName
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.pumpName, on: self)
                .store(in: &lifetime)

            apsManager.pumpExpiresAtDate
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.pumpExpiresAtDate, on: self)
                .store(in: &lifetime)

            apsManager.lastError
                .receive(on: DispatchQueue.main)
                .map { [weak self] error in
                    self?.errorDate = error == nil ? nil : Date()
                    if let error = error {
                        info(.default, error.localizedDescription)
                    }
                    return error?.localizedDescription
                }
                .weakAssign(to: \.errorMessage, on: self)
                .store(in: &lifetime)

            apsManager.bolusProgress
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.bolusProgress, on: self)
                .store(in: &lifetime)

            apsManager.bolusAmount
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.bolusAmount, on: self)
                .store(in: &lifetime)

            apsManager.pumpDisplayState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    guard let self = self else { return }
                    self.pumpDisplayState = state
                    if state == nil {
                        self.reservoir = nil
                        self.battery = nil
                        self.pumpName = ""
                        self.pumpExpiresAtDate = nil
                        self.setupPump = false
                    } else {
                        self.setupBattery()
                        self.setupReservoir()
                    }
                }
                .store(in: &lifetime)

            $setupPump
                .sink { [weak self] show in
                    guard let self = self else { return }
                    if show, let pumpManager = self.provider.apsManager.pumpManager,
                       let bluetoothProvider = self.provider.apsManager.bluetoothManager
                    {
                        let view = PumpConfig.PumpSettingsView(
                            pumpManager: pumpManager,
                            bluetoothManager: bluetoothProvider,
                            completionDelegate: self,
                            setupDelegate: self
                        ).asAny()
                        self.router.mainSecondaryModalView.send(view)
                    } else {
                        self.router.mainSecondaryModalView.send(nil)
                    }
                }
                .store(in: &lifetime)
        }

        func addCarbs() {
            showModal(for: .addCarbs(editMode: false, override: false))
        }

        func runLoop() {
            provider.heartbeatNow()
        }

        func cancelBolus() {
            apsManager.cancelBolus()
        }

        func cancelProfile() {
            let os = OverrideStorage()
            // Is there a saved Override?
            if let activeOveride = os.fetchLatestOverride().first {
                let presetName = os.isPresetName()
                // Is the Override a Preset?
                if let preset = presetName {
                    if let duration = os.cancelProfile() {
                        // Update in Nightscout
                        nightscoutManager.editOverride(preset, duration, activeOveride.date ?? Date.now)
                    }
                } else if activeOveride.isPreset { // Because hard coded Hypo treatment isn't actually a preset
                    if let duration = os.cancelProfile() {
                        nightscoutManager.editOverride("📉", duration, activeOveride.date ?? Date.now)
                    }
                } else {
                    let nsString = activeOveride.percentage.formatted() != "100" ? activeOveride.percentage
                        .formatted() + " %" : "Custom"
                    if let duration = os.cancelProfile() {
                        nightscoutManager.editOverride(nsString, duration, activeOveride.date ?? Date.now)
                    }
                }
            }
            setupOverrideHistory()
        }

        // DanaKitspecial Funktions
        func specialDanaKitFunction() {
            guard let pumpManager = provider.apsManager.pumpManager as? DanaKitPumpManager else {
                return
            }

            if let cannulaDate = pumpManager.state.cannulaDate {
                cannulaHours = -cannulaDate.timeIntervalSinceNow / 3600 // Store as Double
                cannulaAge = String(format: "%.0fh", cannulaHours ?? 0) // Store for display

            } else {
                cannulaHours = nil
                cannulaAge = "--"
            }

            if let reservoirDate = pumpManager.state.reservoirDate {
                reservoirAge = formatToDaysAndHours(reservoirDate)

            } else {
                reservoirAge = "--" // Wenn kein Datum vorhanden ist
            }

            reservoirLevel = pumpManager.state.reservoirLevel
            isConnected = pumpManager.state.isConnected

            let batteryCharge = pumpManager.state.batteryRemaining
            pumpBatteryChargeRemaining = String(format: "%.0f", batteryCharge)
        }

        private func formatToDaysAndHours(_ date: Date) -> String {
            let secondsInADay: TimeInterval = 86400
            let secondsInAnHour: TimeInterval = 3600

            let days = String(format: "%.0f", -date.timeIntervalSinceNow / secondsInADay)
            let hours = String(
                format: "%.0f",
                (-date.timeIntervalSinceNow.truncatingRemainder(dividingBy: secondsInADay)) / secondsInAnHour
            )

            return "\(days)d \(hours)h"
        }

        private func formatToTotalHours(_ date: Date) -> String {
            let secondsInAnHour: TimeInterval = 3600
            let totalHours = -date.timeIntervalSinceNow / secondsInAnHour
            return String(format: "%.0fh", totalHours)
        }

        func cancelTempTarget() {
            storage.storeTempTargets([TempTarget.cancel(at: Date())])
            coredataContext.performAndWait {
                let saveToCoreData = TempTargets(context: self.coredataContext)
                saveToCoreData.active = false
                saveToCoreData.date = Date()
                try? self.coredataContext.save()

                let setHBT = TempTargetsSlider(context: self.coredataContext)
                setHBT.enabled = false
                setHBT.date = Date()
                try? self.coredataContext.save()
            }
        }

        private func setupGlucose() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isManual = self.provider.manualGlucose(hours: self.filteredHours)
                self.glucose = self.provider.filteredGlucose(hours: self.filteredHours)
                self.readings = CoreDataStorage().fetchGlucose(interval: DateFilter().today)
                self.recentGlucose = self.glucose.last
                if self.glucose.count >= 2 {
                    self.glucoseDelta = (self.recentGlucose?.glucose ?? 0) - (self.glucose[self.glucose.count - 2].glucose ?? 0)
                } else {
                    self.glucoseDelta = nil
                }
                self.alarm = self.provider.glucoseStorage.alarm
            }
        }

        private func setupBasals() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.manualTempBasal = self.apsManager.isManualTempBasal
                self.tempBasals = self.provider.pumpHistory(hours: self.filteredHours).filter {
                    $0.type == .tempBasal || $0.type == .tempBasalDuration
                }
                let lastTempBasal = Array(self.tempBasals.suffix(2))
                guard lastTempBasal.count == 2 else {
                    self.tempRate = nil
                    return
                }

                guard let lastRate = lastTempBasal[0].rate, let lastDuration = lastTempBasal[1].durationMin else {
                    self.tempRate = nil
                    return
                }
                let lastDate = lastTempBasal[0].timestamp
                guard Date().timeIntervalSince(lastDate.addingTimeInterval(lastDuration.minutes.timeInterval)) < 0 else {
                    self.tempRate = nil
                    return
                }
                self.tempRate = lastRate
            }
        }

        private func setupBoluses() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.boluses = self.provider.pumpHistory(hours: self.filteredHours).filter {
                    $0.type == .bolus
                }
                self.maxBolusValue = self.boluses.compactMap(\.amount).max() ?? 1
            }
        }

        private func setupSuspensions() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.suspensions = self.provider.pumpHistory(hours: self.filteredHours).filter {
                    $0.type == .pumpSuspend || $0.type == .pumpResume
                }

                let last = self.suspensions.last
                let tbr = self.tempBasals.first { $0.timestamp > (last?.timestamp ?? .distantPast) }

                self.pumpSuspended = tbr == nil && last?.type == .pumpSuspend
            }
        }

        private func setupPumpSettings() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.maxBasal = self.provider.pumpSettings().maxBasal
            }
        }

        private func setupBasalProfile() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.autotunedBasalProfile = self.provider.autotunedBasalProfile()
                self.basalProfile = self.provider.basalProfile()
            }
        }

        private func setupTempTargets() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.manualTempBasal = self.apsManager.isManualTempBasal
                self.tempTargets = self.provider.tempTargets(hours: self.filteredHours)
            }
        }

        private func setupCarbs() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.carbs = self.provider.carbs(hours: self.filteredHours)
            }
        }

        private func setupOverrideHistory() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overrideHistory = self.provider.overrideHistory()
            }
        }

        private func setupLoopStats() {
            let loopStats = CoreDataStorage().fetchLoopStats(interval: DateFilter().today)
            let loops = loopStats.compactMap({ each in each.loopStatus }).count
            let readings = CoreDataStorage().fetchGlucose(interval: DateFilter().today).compactMap({ each in each.glucose }).count
            let percentage = min(readings != 0 ? (Double(loops) / Double(readings) * 100) : 0, 100)
            // First loop date
            let time = (loopStats.last?.start ?? Date.now).addingTimeInterval(-5.minutes.timeInterval)

            let average = -1 * (time.timeIntervalSinceNow / 60) / max(Double(loops), 1)

            loopStatistics = (
                loops,
                readings,
                percentage,
                average.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) + " min"
            )
        }

        private func setupOverrides() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overrides = self.provider.overrides()
            }
        }

        private func setupAnnouncements() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.announcement = self.provider.announcement(self.filteredHours)
            }
        }

        private func setStatusTitle() {
            guard let suggestion = suggestion else {
                statusTitle = "No suggestion"
                return
            }

            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            if closedLoop,
               let enactedSuggestion = enactedSuggestion,
               let timestamp = enactedSuggestion.timestamp,
               enactedSuggestion.deliverAt == suggestion.deliverAt, enactedSuggestion.recieved == true
            {
                statusTitle = NSLocalizedString("Enacted at", comment: "Headline in enacted pop up") + " " + dateFormatter
                    .string(from: timestamp)
            } else if let suggestedDate = suggestion.deliverAt {
                statusTitle = NSLocalizedString("Suggested at", comment: "Headline in suggested pop up") + " " + dateFormatter
                    .string(from: suggestedDate)
            } else {
                statusTitle = "Suggested"
            }

            eventualBG = suggestion.eventualBG
            isf = suggestion.isf
        }

        private func setupReservoir() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.reservoir = self.provider.pumpReservoir()
            }
        }

        private func setupBattery() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.battery = self.provider.pumpBattery()
            }
        }

        private func setupCurrentTempTarget() {
            tempTarget = provider.tempTarget()
        }

        private func setupCurrentPumpTimezone() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.timeZone = self.provider.pumpTimeZone()
            }
        }

        private func setupData() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let data = self.provider.reasons() {
                    self.iobData = data
                    neg = data.filter({ $0.iob < 0 }).count * 5
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

                    if let tdds_ = self.provider.dynamicVariables {
                        tddAverage = ((tdds.first?.tdd ?? 0) as Decimal) - tdds_.average_total_data
                        tddActualAverage = tdds_.average_total_data
                    }
                }
            }
        }

        func openCGM() {
            guard var url = nightscoutManager.cgmURL else { return }

            switch url.absoluteString {
            case "http://127.0.0.1:1979":
                url = URL(string: "spikeapp://")!
            case "http://127.0.0.1:17580":
                url = URL(string: "diabox://")!
            case CGMType.libreTransmitter.appURL?.absoluteString:
                showModal(for: .libreConfig)
            default: break
            }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }

        func infoPanelTTPercentage(_ hbt_: Double, _ target: Decimal) -> Decimal {
            guard hbt_ != 0 || target != 0 else {
                return 0
            }
            let c = Decimal(hbt_ - 100)
            let ratio = min(c / (target + c - 100), maxValue)
            return (ratio * 100)
        }
    }
}

extension Home.StateModel:
    GlucoseObserver,
    SuggestionObserver,
    SettingsObserver,
    PumpHistoryObserver,
    PumpSettingsObserver,
    BasalProfileObserver,
    TempTargetsObserver,
    CarbsObserver,
    EnactedSuggestionObserver,
    PumpBatteryObserver,
    PumpReservoirObserver,
    PumpTimeZoneObserver
{
    func glucoseDidUpdate(_: [BloodGlucose]) {
        setupGlucose()
        setupLoopStats()
    }

    func suggestionDidUpdate(_ suggestion: Suggestion) {
        self.suggestion = suggestion
        carbsRequired = suggestion.carbsReq
        setStatusTitle()
        setupOverrideHistory()
        setupLoopStats()
        setupData()
    }

    func settingsDidChange(_ settings: FreeAPSSettings) {
        allowManualTemp = !settings.closedLoop
        uploadStats = settingsManager.settings.uploadStats
        closedLoop = settingsManager.settings.closedLoop
        units = settingsManager.settings.units
        animatedBackground = settingsManager.settings.animatedBackground
        manualTempBasal = apsManager.isManualTempBasal
        smooth = settingsManager.settings.smoothGlucose
        lowGlucose = settingsManager.settings.low
        highGlucose = settingsManager.settings.high
        overrideUnit = settingsManager.settings.overrideHbA1cUnit
        displayXgridLines = settingsManager.settings.xGridLines
        displayYgridLines = settingsManager.settings.yGridLines
        thresholdLines = settingsManager.settings.rulerMarks
        useTargetButton = settingsManager.settings.useTargetButton
        hours = settingsManager.settings.hours
        alwaysUseColors = settingsManager.settings.alwaysUseColors
        // Dana UI Toggels

        timeSettings = settingsManager.settings.timeSettings
        danaIcon = settingsManager.settings.danaIcon
        legendsSwitch = settingsManager.settings.legendsSwitch
        danaBar = settingsManager.settings.danaBar
        tempTargetbar = settingsManager.settings.tempTargetbar

        // Dana UI Toggels
        useCalc = settingsManager.settings.useCalc
        minimumSMB = settingsManager.settings.minimumSMB
        maxBolus = settingsManager.pumpSettings.maxBolus
        useInsulinBars = settingsManager.settings.useInsulinBars
        skipGlucoseChart = settingsManager.settings.skipGlucoseChart
        setupGlucose()
        setupOverrideHistory()
        setupData()
    }

    func pumpHistoryDidUpdate(_: [PumpHistoryEvent]) {
        setupBasals()
        setupBoluses()
        setupSuspensions()
        setupAnnouncements()
    }

    func pumpSettingsDidChange(_: PumpSettings) {
        setupPumpSettings()
    }

    func basalProfileDidChange(_: [BasalProfileEntry]) {
        setupBasalProfile()
    }

    func tempTargetsDidUpdate(_: [TempTarget]) {
        setupTempTargets()
    }

    func carbsDidUpdate(_: [CarbsEntry]) {
        setupCarbs()
        setupAnnouncements()
    }

    func enactedSuggestionDidUpdate(_ suggestion: Suggestion) {
        enactedSuggestion = suggestion
        setStatusTitle()
        setupOverrideHistory()
        setupLoopStats()
        setupData()
    }

    func pumpBatteryDidChange(_: Battery) {
        setupBattery()
    }

    func pumpReservoirDidChange(_: Decimal) {
        setupReservoir()
    }

    func pumpTimeZoneDidChange(_: TimeZone) {
        setupCurrentPumpTimezone()
    }
}

extension Home.StateModel: CompletionDelegate {
    func completionNotifyingDidComplete(_: CompletionNotifying) {
        setupPump = false
    }
}

extension Home.StateModel: PumpManagerOnboardingDelegate {
    func pumpManagerOnboarding(didCreatePumpManager pumpManager: PumpManagerUI) {
        provider.apsManager.pumpManager = pumpManager
        if let insulinType = pumpManager.status.insulinType {
            settingsManager.updateInsulinCurve(insulinType)
        }
    }

    func pumpManagerOnboarding(didOnboardPumpManager _: PumpManagerUI) {
        // nothing to do
    }

    func pumpManagerOnboarding(didPauseOnboarding _: PumpManagerUI) {
        // TODO:
    }
}
