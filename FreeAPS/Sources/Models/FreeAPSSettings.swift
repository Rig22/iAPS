import Foundation

// Originale FreeAPSSettings Struktur
struct FreeAPSSettings: JSON, Equatable, Codable {
    var units: GlucoseUnits = .mmolL
    var closedLoop: Bool = false
    var allowAnnouncements: Bool = false
    var useAutotune: Bool = false
    var isUploadEnabled: Bool = false
    var useLocalGlucoseSource: Bool = false
    var localGlucosePort: Int = 8080
    var debugOptions: Bool = false
    var insulinReqPercentage: Decimal = 70
    var skipBolusScreenAfterCarbs: Bool = false
    var displayHR: Bool = false
    var cgm: CGMType = .nightscout
    var uploadGlucose: Bool = true
    var useCalendar: Bool = false
    var displayCalendarIOBandCOB: Bool = false
    var displayCalendarEmojis: Bool = false
    var glucoseBadge: Bool = false
    var glucoseNotificationsAlways: Bool = false
    var useAlarmSound: Bool = false
    var addSourceInfoToGlucoseNotifications: Bool = false
    var lowGlucose: Decimal = 72
    var highGlucose: Decimal = 270
    var carbsRequiredThreshold: Decimal = 10
    var animatedBackground: Bool = false
    var useFPUconversion: Bool = true
    var individualAdjustmentFactor: Decimal = 0.5
    var timeCap: Int = 8
    var minuteInterval: Int = 30
    var delay: Int = 60
    var useAppleHealth: Bool = false
    var smoothGlucose: Bool = false
    var displayOnWatch: AwConfig = .BGTarget
    var overrideHbA1cUnit: Bool = false
    var high: Decimal = 145
    var low: Decimal = 70
    var uploadStats: Bool = false
    var hours: Int = 6
    var xGridLines: Bool = true
    var yGridLines: Bool = true
    var oneDimensionalGraph: Bool = false
    var rulerMarks: Bool = false
    var maxCarbs: Decimal = 1000
    var displayFatAndProteinOnWatch: Bool = false
    var confirmBolusFaster: Bool = false
    var onlyAutotuneBasals: Bool = false
    var overrideFactor: Decimal = 0.8
    var useCalc: Bool = true
    var fattyMeals: Bool = false
    var fattyMealFactor: Decimal = 0.7
    var displayPredictions: Bool = true
    var useLiveActivity: Bool = false
    var useTargetButton: Bool = false
    var alwaysUseColors: Bool = true
    // Dana Toggels
    var timeSettings: Bool = false
    var danaIcon: Bool = true
    var danaBar: Bool = false
    var legendsSwitch: Bool = false
    var tempTargetbar: Bool = false
    var backgroundColorOptionRawValue: String = BackgroundColorOption.blue.rawValue
    // Dana Toggels
    var profilesOrTempTargets: Bool = false
    var allowBolusShortcut: Bool = false
    var allowedRemoteBolusAmount: Decimal = 0.0
    var eventualBG: Bool = false
    var minumimPrediction: Bool = false
    var minimumSMB: Decimal = 0.3
    var useInsulinBars: Bool = false
    var disableCGMError: Bool = true
    var uploadVersion: Bool = true
    var skipGlucoseChart: Bool = false
    var birthDate = Date.distantPast
    var sexSetting: Int = 3
    var disableHypoTreatment: Bool = false
    var insulinBadge: Bool = false
    var hideInsulinBadge: Bool = false
    var allowDilution: Bool = false

    // Computed property for background color option
    var backgroundColorOption: BackgroundColorOption {
        get {
            BackgroundColorOption(rawValue: backgroundColorOptionRawValue) ?? .blue
        }
        set {
            backgroundColorOptionRawValue = newValue.rawValue
        }
    }
}

// Wrapper für FreeAPSSettings, um Encodable zu unterstützen
struct EncodableFreeAPSSettings: Encodable {
    private let settings: FreeAPSSettings

    init(settings: FreeAPSSettings) {
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey {
        case units
        case closedLoop
        case allowAnnouncements
        case useAutotune
        case isUploadEnabled
        case useLocalGlucoseSource
        case localGlucosePort
        case debugOptions
        case insulinReqPercentage
        case skipBolusScreenAfterCarbs
        case displayHR
        case cgm
        case uploadGlucose
        case useCalendar
        case displayCalendarIOBandCOB
        case displayCalendarEmojis
        case glucoseBadge
        case glucoseNotificationsAlways
        case useAlarmSound
        case addSourceInfoToGlucoseNotifications
        case lowGlucose
        case highGlucose
        case carbsRequiredThreshold
        case animatedBackground
        case useFPUconversion
        case individualAdjustmentFactor
        case timeCap
        case minuteInterval
        case delay
        case useAppleHealth
        case smoothGlucose
        case displayOnWatch
        case overrideHbA1cUnit
        case high
        case low
        case uploadStats
        case hours
        case xGridLines
        case yGridLines
        case oneDimensionalGraph
        case rulerMarks
        case maxCarbs
        case displayFatAndProteinOnWatch
        case confirmBolusFaster
        case onlyAutotuneBasals
        case overrideFactor
        case useCalc
        case fattyMeals
        case fattyMealFactor
        case displayPredictions
        case useLiveActivity
        case useTargetButton
        case alwaysUseColors
        // Dana Toggels
        case danaIcon
        case danaBar
        case insulinBadge
        case hideInsulinBadge
        case legendsSwitch
        case tempTargetbar
        case timeSettings
        case backgroundColorOptionRawValue
        // Dana Toggels
        case profilesOrTempTargets
        case allowBolusShortcut
        case allowedRemoteBolusAmount
        case eventualBG
        case minumimPrediction
        case minimumSMB
        case useInsulinBars
        case disableCGMError
        case uploadVersion
        case skipGlucoseChart
        case birthDate
        case sexSetting
        case disableHypoTreatment
        case allowDilution
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(settings.units, forKey: .units)
        // ... (Encode all properties similar to settings.units)
        try container.encode(settings.closedLoop, forKey: .closedLoop)
        try container.encode(settings.allowAnnouncements, forKey: .allowAnnouncements)
        try container.encode(settings.useAutotune, forKey: .useAutotune)
        try container.encode(settings.isUploadEnabled, forKey: .isUploadEnabled)
        try container.encode(settings.useLocalGlucoseSource, forKey: .useLocalGlucoseSource)
        try container.encode(settings.localGlucosePort, forKey: .localGlucosePort)
        try container.encode(settings.debugOptions, forKey: .debugOptions)
        try container.encode(settings.insulinReqPercentage, forKey: .insulinReqPercentage)
        try container.encode(settings.skipBolusScreenAfterCarbs, forKey: .skipBolusScreenAfterCarbs)
        try container.encode(settings.displayHR, forKey: .displayHR)
        try container.encode(settings.cgm, forKey: .cgm)
        try container.encode(settings.uploadGlucose, forKey: .uploadGlucose)
        try container.encode(settings.useCalendar, forKey: .useCalendar)
        try container.encode(settings.displayCalendarIOBandCOB, forKey: .displayCalendarIOBandCOB)
        try container.encode(settings.displayCalendarEmojis, forKey: .displayCalendarEmojis)
        try container.encode(settings.glucoseBadge, forKey: .glucoseBadge)
        try container.encode(settings.glucoseNotificationsAlways, forKey: .glucoseNotificationsAlways)
        try container.encode(settings.useAlarmSound, forKey: .useAlarmSound)
        try container.encode(settings.addSourceInfoToGlucoseNotifications, forKey: .addSourceInfoToGlucoseNotifications)
        try container.encode(settings.lowGlucose, forKey: .lowGlucose)
        try container.encode(settings.highGlucose, forKey: .highGlucose)
        try container.encode(settings.carbsRequiredThreshold, forKey: .carbsRequiredThreshold)
        try container.encode(settings.animatedBackground, forKey: .animatedBackground)
        try container.encode(settings.useFPUconversion, forKey: .useFPUconversion)
        try container.encode(settings.individualAdjustmentFactor, forKey: .individualAdjustmentFactor)
        try container.encode(settings.timeCap, forKey: .timeCap)
        try container.encode(settings.minuteInterval, forKey: .minuteInterval)
        try container.encode(settings.delay, forKey: .delay)
        try container.encode(settings.useAppleHealth, forKey: .useAppleHealth)
        try container.encode(settings.smoothGlucose, forKey: .smoothGlucose)
        try container.encode(settings.displayOnWatch, forKey: .displayOnWatch)
        try container.encode(settings.overrideHbA1cUnit, forKey: .overrideHbA1cUnit)
        try container.encode(settings.high, forKey: .high)
        try container.encode(settings.low, forKey: .low)
        try container.encode(settings.uploadStats, forKey: .uploadStats)
        try container.encode(settings.hours, forKey: .hours)
        try container.encode(settings.xGridLines, forKey: .xGridLines)
        try container.encode(settings.yGridLines, forKey: .yGridLines)
        try container.encode(settings.oneDimensionalGraph, forKey: .oneDimensionalGraph)
        try container.encode(settings.rulerMarks, forKey: .rulerMarks)
        try container.encode(settings.maxCarbs, forKey: .maxCarbs)
        try container.encode(settings.displayFatAndProteinOnWatch, forKey: .displayFatAndProteinOnWatch)
        try container.encode(settings.confirmBolusFaster, forKey: .confirmBolusFaster)
        try container.encode(settings.onlyAutotuneBasals, forKey: .onlyAutotuneBasals)
        try container.encode(settings.overrideFactor, forKey: .overrideFactor)
        try container.encode(settings.useCalc, forKey: .useCalc)
        try container.encode(settings.fattyMeals, forKey: .fattyMeals)
        try container.encode(settings.fattyMealFactor, forKey: .fattyMealFactor)
        try container.encode(settings.displayPredictions, forKey: .displayPredictions)
        try container.encode(settings.useLiveActivity, forKey: .useLiveActivity)
        try container.encode(settings.useTargetButton, forKey: .useTargetButton)
        try container.encode(settings.alwaysUseColors, forKey: .alwaysUseColors)
        // Dana Toogels
        try container.encode(settings.danaIcon, forKey: .danaIcon)
        try container.encode(settings.danaBar, forKey: .danaBar)
        try container.encode(settings.insulinBadge, forKey: .insulinBadge)
        try container.encode(settings.hideInsulinBadge, forKey: .hideInsulinBadge)
        try container.encode(settings.legendsSwitch, forKey: .legendsSwitch)
        try container.encode(settings.tempTargetbar, forKey: .tempTargetbar)
        try container.encode(settings.timeSettings, forKey: .timeSettings)
        try container.encode(settings.backgroundColorOptionRawValue, forKey: .backgroundColorOptionRawValue)
        // Dana Toggels
        try container.encode(settings.profilesOrTempTargets, forKey: .profilesOrTempTargets)
        try container.encode(settings.allowBolusShortcut, forKey: .allowBolusShortcut)
        try container.encode(settings.allowedRemoteBolusAmount, forKey: .allowedRemoteBolusAmount)
        try container.encode(settings.eventualBG, forKey: .eventualBG)
        try container.encode(settings.minumimPrediction, forKey: .minumimPrediction)
        try container.encode(settings.minimumSMB, forKey: .minimumSMB)
        try container.encode(settings.useInsulinBars, forKey: .useInsulinBars)
        try container.encode(settings.disableCGMError, forKey: .disableCGMError)
        try container.encode(settings.uploadVersion, forKey: .uploadVersion)
        try container.encode(settings.skipGlucoseChart, forKey: .skipGlucoseChart)
        try container.encode(settings.birthDate, forKey: .birthDate)
        try container.encode(settings.sexSetting, forKey: .sexSetting)
        try container.encode(settings.disableHypoTreatment, forKey: .disableHypoTreatment)
        try container.encode(settings.allowDilution, forKey: .allowDilution)
    }
}
