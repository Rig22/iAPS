import Foundation

// Originale FreeAPSSettings Struktur
struct FreeAPSSettings: JSON, Equatable, Codable {
    var units: GlucoseUnits = .mgdL
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
    var cgm: CGMType = .glucoseDirect
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
    var xGridLines: Bool = false
    var yGridLines: Bool = false
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
    var useLiveActivity: Bool = true
    var liveActivityEventualArrow: Bool = false
    var liveActivityChart = false
    var liveActivityChartShowPredictions = true
    var liveActivityChartThresholdLines = true
    var liveActivityChartDynamicRange = true
    var useTargetButton: Bool = false
    var alwaysUseColors: Bool = false
    var disable15MinTrend: Bool = false
    // Sounds
    var hypoSound: String = "Default"
    var hyperSound: String = "Default"
    var ascending: String = "Default"
    var descending: String = "Default"
    var carbSound: String = "Default"
    var bolusFailure: String = "Silent"
    var missingLoops = true
    // Alerts
    var lowAlert: Bool = true
    var highAlert: Bool = true
    var ascendingAlert: Bool = true
    var descendingAlert: Bool = true
    var carbsRequiredAlert: Bool = true
    //
    var profilesOrTempTargets: Bool = false
    var allowBolusShortcut: Bool = false
    var allowedRemoteBolusAmount: Decimal = 0.0
    var eventualBG: Bool = false
    var minumimPrediction: Bool = false
    var minimumSMB: Decimal = 0.3
    var useInsulinBars: Bool = true
    var disableCGMError: Bool = true
    var uploadVersion: Bool = true
    var skipGlucoseChart: Bool = false
    var birthDate = Date.distantPast
    var sexSetting: Int = 3
    var disableHypoTreatment: Bool = false
    var hideInsulinBadge: Bool = false
    var allowDilution: Bool = false
    var displayDelta: Bool = false
    var profileID: String = "Hypo Treatment"
    var extended_overrides = false
    var extendHomeView = true
    var displayExpiration = false
    var sensorDays: Double = 10
    var fpus: Bool = true
    var fpuAmounts: Bool = false
    // Dana-Toggles
    var timeSettings: Bool = true
    var pumpIconRawValue: String = "ic_dana_rs"
    var danaBar: Bool = false
    var legendsSwitch: Bool = false
    var tempTargetbar: Bool = false
    var backgroundColorOptionRawValue: String = BackgroundColorOption.teal.rawValue
    var danaBarOption: String = DanaBarOption.max.rawValue
    var insulinAgeOption: String = "Drei_Tage"
    var cannulaAgeOption: String = "Drei_Tage"
    var loopViewOption: String = LoopViewOption.view1.rawValue
    var chartBackgroundColored: Bool = false
    var carbInsulinLoopViewOption: Bool = false
    var barViewOptionConfigurationRawValue: String = BarViewOptionConfiguration.none.rawValue
    var topBarActive: Bool = false
    var danaBarActive: Bool = false
    var ttBarActive: Bool = false
    var bottomBarActive: Bool = false
    var button3D: Bool = false
    var sensorAgeDays: SensorAgeDays = .Fuenfzehn_Tage
    var sensorStartTime: Date?
    var bolusProgressViewOption: String = BolusProgressViewOption.bolusview2.rawValue
    var sensorStartTimeDefault = Date.distantPast
    var incidenceOfLight = false
    var lightGlowOverlaySelector: String = LightGlowOverlaySelector.atriumview1.rawValue
    var insulinHours: Double?
    var button3DBackground: Bool = false
    var batteryIconOption: Bool = false
    var carbButton: Bool = true
    var profileButton: Bool = true
    var glucoseOverrideThreshold: Decimal = 100
    var glucoseOverrideThresholdActive: Bool = false
    var glucoseOverrideThresholdActiveDown: Bool = false
    var glucoseOverrideThresholdDown: Decimal = 100
    var showPumpIcon: Bool = false
    // Dana-Toggles
    // Auto ISF
    var autoisf: Bool = false
    var smbDeliveryRatioBGrange: Decimal = 0
    var smbDeliveryRatioMin: Decimal = 0.5
    var smbDeliveryRatioMax: Decimal = 0.5
    var autoISFhourlyChange: Decimal = 1
    var higherISFrangeWeight: Decimal = 0
    var lowerISFrangeWeight: Decimal = 0
    var postMealISFweight: Decimal = 0.01
    var enableBGacceleration: Bool = true
    var bgAccelISFweight: Decimal = 0
    var bgBrakeISFweight: Decimal = 0.10
    var iobThresholdPercent: Decimal = 100
    var autoisf_max: Decimal = 1.2
    var autoisf_min: Decimal = 0.8
    // B30
    var use_B30 = false
    var iTime_Start_Bolus: Decimal = 1.5
    var iTime_target: Decimal = 90
    var b30targetLevel: Decimal = 100
    var b30upperLimit: Decimal = 130
    var b30upperdelta: Decimal = 8
    var b30factor: Decimal = 5
    var b30_duration: Decimal = 30
    // Keto protection
    var ketoProtect: Bool = false
    var variableKetoProtect: Bool = false
    var ketoProtectBasalPercent: Decimal = 20
    var ketoProtectAbsolut: Bool = false
    var ketoProtectBasalAbsolut: Decimal = 0

    // Computed property for background color option
    var backgroundColorOption: BackgroundColorOption {
        get {
            BackgroundColorOption(rawValue: backgroundColorOptionRawValue) ?? .teal
        }
        set {
            backgroundColorOptionRawValue = newValue.rawValue
        }
    }

    // Computed property for Dana Icon
    var pumpIconOption: PumpIconOption {
        get {
            PumpIconOption(rawValue: pumpIconRawValue) ?? .danaRS
        }
        set {
            pumpIconRawValue = newValue.rawValue
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
        case liveActivityEventualArrow
        case liveActivityChart
        case liveActivityChartShowPredictions
        case liveActivityChartThresholdLines
        case liveActivityChartDynamicRange
        case liveActivityThresholdLines
        case useTargetButton
        case alwaysUseColors
        case hypoSound
        case hyperSound
        case ascending
        case descending
        case carbSound
        case bolusFailure
        case missingLoops
        case lowAlert
        case highAlert
        case ascendingAlert
        case descendingAlert
        case carbsRequiredAlert
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
        case displayDelta
        case disableHypoTreatment
        case allowDilution
        case profileID
        case extendedOverride
        case extendHomeView
        case displayExpiration
        case sensorDays
        case fpus
        case fpuAmount
        case disable15MinTrend
        // Dana Toggles
        case danaIconRawValue
        case danaBar
        case insulinBadge
        case hideInsulinBadge
        case legendsSwitch
        case tempTargetbar
        case timeSettings
        case backgroundColorOptionRawValue
        case danaBarOption
        case insulinAgeOption
        case cannulaAgeOption
        case loopViewOption
        case chartBackgroundColored
        case carbInsulinLoopViewOption
        case topBarActive
        case danaBarActive
        case ttBarActive
        case bottomBarActive
        case barViewOptionConfigurationRawValue
        case button3D
        case sensorAgeDays
        case sensorStartTime
        case bolusProgressViewOption
        case sensorStartTimeDefault
        case incidenceOfLight
        case lightGlowOverlaySelector
        case insulinHours
        case button3DBackground
        case batteryIconOption
        case carbButton
        case profileButton
        case glucoseOverrideThreshold
        case glucoseOverrideThresholdActive
        case glucoseOverrideThresholdActiveDown
        case glucoseOverrideThresholdDown
        case showPumpIcon
        // Dana Toggles
        // AutoISF
        case autoisf
        case smbDeliveryRatioRange
        case smbDeliveryRatioMin
        case smbDeliveryRatioMax
        case autoISFhourlyChange
        case higherISFrangeWeight
        case lowerISFrangeWeight
        case postMealISFweight
        case enableBGacceleration
        case bgAccelISFweight
        case bgBrakeISFweight
        case iobThresholdPercent
        case autoisf_max
        case autoisf_min
        // B30
        case use_B30
        case iTime_Start_Bolus
        case iTime_target
        case b30targetLevel
        case b30upperLimit
        case b30upperdelta
        case b30factor
        case b30_duration
        // Keto Protect
        case ketoProtect
        case variableKetoProtect
        case ketoProtectBasalPercent
        case ketoProtectAbsolut
        case ketoProtectBasalAbsolut
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(settings.units, forKey: .units)
        try container.encode(settings.closedLoop, forKey: .closedLoop)
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
        try container.encode(settings.liveActivityEventualArrow, forKey: .liveActivityEventualArrow)
        // --- live activity chart
        try container.encode(settings.liveActivityChart, forKey: .liveActivityChart)
        try container.encode(settings.liveActivityChartShowPredictions, forKey: .liveActivityChartShowPredictions)
        try container.encode(settings.liveActivityChartThresholdLines, forKey: .liveActivityChartThresholdLines)
        try container.encode(settings.liveActivityChartDynamicRange, forKey: .liveActivityChartDynamicRange)
        // ----
        try container.encode(settings.hypoSound, forKey: .hypoSound)
        try container.encode(settings.hyperSound, forKey: .hyperSound)
        try container.encode(settings.ascending, forKey: .ascending)
        try container.encode(settings.descending, forKey: .descending)
        try container.encode(settings.carbSound, forKey: .carbSound)
        try container.encode(settings.bolusFailure, forKey: .bolusFailure)
        try container.encode(settings.missingLoops, forKey: .missingLoops)
        try container.encode(settings.lowAlert, forKey: .lowAlert)
        try container.encode(settings.highAlert, forKey: .highAlert)
        try container.encode(settings.ascendingAlert, forKey: .ascendingAlert)
        try container.encode(settings.descendingAlert, forKey: .descendingAlert)
        try container.encode(settings.carbsRequiredAlert, forKey: .carbsRequiredAlert)
        try container.encode(settings.alwaysUseColors, forKey: .alwaysUseColors)
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
        try container.encode(settings.extended_overrides, forKey: .extendedOverride)
        try container.encode(settings.displayDelta, forKey: .displayDelta)
        try container.encode(settings.profileID, forKey: .profileID)
        try container.encode(settings.displayExpiration, forKey: .displayExpiration)
        try container.encode(settings.sensorDays, forKey: .sensorDays)
        try container.encode(settings.fpus, forKey: .fpus)
        try container.encode(settings.fpuAmounts, forKey: .fpuAmount)
        try container.encode(settings.disable15MinTrend, forKey: .disable15MinTrend)
        // Dana Toggels
        try container.encode(settings.danaBar, forKey: .danaBar)
        try container.encode(settings.hideInsulinBadge, forKey: .hideInsulinBadge)
        try container.encode(settings.legendsSwitch, forKey: .legendsSwitch)
        try container.encode(settings.tempTargetbar, forKey: .tempTargetbar)
        try container.encode(settings.timeSettings, forKey: .timeSettings)
        try container.encode(settings.backgroundColorOptionRawValue, forKey: .backgroundColorOptionRawValue)
        try container.encode(settings.danaBarOption, forKey: .danaBarOption)
        try container.encode(settings.insulinAgeOption, forKey: .insulinAgeOption)
        try container.encode(settings.cannulaAgeOption, forKey: .cannulaAgeOption)
        try container.encode(settings.loopViewOption, forKey: .loopViewOption)
        try container.encode(settings.chartBackgroundColored, forKey: .chartBackgroundColored)
        try container.encode(settings.carbInsulinLoopViewOption, forKey: .carbInsulinLoopViewOption)
        try container.encode(settings.topBarActive, forKey: .topBarActive)
        try container.encode(settings.danaBarActive, forKey: .danaBarActive)
        try container.encode(settings.ttBarActive, forKey: .ttBarActive)
        try container.encode(settings.bottomBarActive, forKey: .bottomBarActive)
        try container.encode(settings.barViewOptionConfigurationRawValue, forKey: .barViewOptionConfigurationRawValue)
        try container.encode(settings.button3D, forKey: .button3D)
        try container.encode(settings.sensorAgeDays, forKey: .sensorAgeDays)
        try container.encodeIfPresent(settings.sensorStartTime, forKey: .sensorStartTime)
        // try container.encode(settings.bolusProgressViewOption, forKey: .bolusProgressViewOption)
        try container.encode(settings.sensorStartTimeDefault, forKey: .sensorStartTimeDefault)
        try container.encode(settings.incidenceOfLight, forKey: .incidenceOfLight)
        try container.encode(settings.lightGlowOverlaySelector, forKey: .lightGlowOverlaySelector)
        try container.encode(settings.insulinHours, forKey: .insulinHours)
        try container.encode(settings.button3DBackground, forKey: .button3DBackground)
        try container.encode(settings.batteryIconOption, forKey: .batteryIconOption)
        try container.encode(settings.carbButton, forKey: .carbButton)
        try container.encode(settings.profileButton, forKey: .profileButton)
        try container.encode(settings.glucoseOverrideThreshold, forKey: .glucoseOverrideThreshold)
        try container.encode(settings.glucoseOverrideThresholdActive, forKey: .glucoseOverrideThresholdActive)
        try container.encode(settings.glucoseOverrideThresholdActiveDown, forKey: .glucoseOverrideThresholdActiveDown)
        try container.encode(settings.glucoseOverrideThresholdDown, forKey: .glucoseOverrideThresholdDown)
        try container.encode(settings.showPumpIcon, forKey: .showPumpIcon)
        // Dana Toggels
        // AutoISF
        try container.encode(settings.autoisf, forKey: .autoisf)
        try container.encode(settings.smbDeliveryRatioBGrange, forKey: .smbDeliveryRatioRange)
        try container.encode(settings.smbDeliveryRatioMin, forKey: .smbDeliveryRatioMin)
        try container.encode(settings.smbDeliveryRatioMax, forKey: .smbDeliveryRatioMax)
        try container.encode(settings.autoISFhourlyChange, forKey: .autoISFhourlyChange)
        try container.encode(settings.higherISFrangeWeight, forKey: .higherISFrangeWeight)
        try container.encode(settings.lowerISFrangeWeight, forKey: .lowerISFrangeWeight)
        try container.encode(settings.postMealISFweight, forKey: .postMealISFweight)
        try container.encode(settings.enableBGacceleration, forKey: .enableBGacceleration)
        try container.encode(settings.bgAccelISFweight, forKey: .bgAccelISFweight)
        try container.encode(settings.bgBrakeISFweight, forKey: .bgBrakeISFweight)
        try container.encode(settings.iobThresholdPercent, forKey: .iobThresholdPercent)
        try container.encode(settings.autoisf_max, forKey: .autoisf_max)
        try container.encode(settings.autoisf_min, forKey: .autoisf_min)
        // B30
        try container.encode(settings.use_B30, forKey: .use_B30)
        try container.encode(settings.iTime_Start_Bolus, forKey: .iTime_Start_Bolus)
        try container.encode(settings.iTime_target, forKey: .iTime_target)
        try container.encode(settings.b30targetLevel, forKey: .b30targetLevel)
        try container.encode(settings.b30upperLimit, forKey: .b30upperLimit)
        try container.encode(settings.b30upperdelta, forKey: .b30upperdelta)
        try container.encode(settings.b30factor, forKey: .b30factor)
        try container.encode(settings.b30_duration, forKey: .b30_duration)
        // Keto Protect
        try container.encode(settings.ketoProtect, forKey: .ketoProtect)
        try container.encode(settings.variableKetoProtect, forKey: .variableKetoProtect)
        try container.encode(settings.ketoProtectBasalPercent, forKey: .ketoProtectBasalPercent)
        try container.encode(settings.ketoProtectAbsolut, forKey: .ketoProtectAbsolut)
        try container.encode(settings.ketoProtectBasalAbsolut, forKey: .ketoProtectBasalAbsolut)
    }
}
