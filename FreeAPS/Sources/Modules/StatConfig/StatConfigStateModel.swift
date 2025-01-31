import SwiftUI

extension StatConfig {
    final class StateModel: BaseStateModel<Provider> {
        @Published var overrideHbA1cUnit = false
        @Published var low: Decimal = 4 / 0.0555
        @Published var high: Decimal = 10 / 0.0555
        @Published var xGridLines = false
        @Published var yGridLines: Bool = false
        @Published var oneDimensionalGraph = false
        @Published var rulerMarks: Bool = false
        @Published var skipBolusScreenAfterCarbs: Bool = false
        @Published var useFPUconversion: Bool = true
        @Published var useTargetButton: Bool = false
        @Published var hours: Decimal = 6
        @Published var alwaysUseColors: Bool = true
        // Dana UI Toggels
        @Published var danaIconRawValue: String = "ic_dana_rs"
        @Published var danaBar: Bool = false
        @Published var insulinBadge: Bool = false
        @Published var hideInsulinBadge: Bool = false
        @Published var legendsSwitch: Bool = false
        @Published var tempTargetBar: Bool = false
        @Published var timeSettings: Bool = false
        @Published var backgroundColorOptionRawValue: String = BackgroundColorOption.darkBlue.rawValue
        @Published var backgroundColorSelected: String = BackgroundColorOption.darkBlue.rawValue
        @Published var danaBarViewOption: String = "view1"
        @Published var insulinAgeOption: String = "Drei_Tage"
        @Published var cannulaAgeOption: String = "Drei_Tage"
        @Published var loopViewOption: String = LoopViewOption.view1.rawValue
        @Published var chartBackgroundColored: Bool = false
        @Published var carbInsulinLoopViewOption: Bool = true

        // Dana UI Toggels
        @Published var minimumSMB: Decimal = 0.3
        @Published var useInsulinBars: Bool = true
        @Published var skipGlucoseChart: Bool = false
        @Published var extendHomeView: Bool = true

        // Computed property für die tatsächlich ausgewählte Hintergrundfarbe
        var selectedBackgroundColor: Color {
            BackgroundColorOption(rawValue: backgroundColorOptionRawValue)?.color ?? .clear
        }

        var units: GlucoseUnits = .mmolL

        override func subscribe() {
            let units = settingsManager.settings.units
            self.units = units

            subscribeSetting(\.overrideHbA1cUnit, on: $overrideHbA1cUnit) { overrideHbA1cUnit = $0 }
            subscribeSetting(\.xGridLines, on: $xGridLines) { xGridLines = $0 }
            subscribeSetting(\.yGridLines, on: $yGridLines) { yGridLines = $0 }
            subscribeSetting(\.rulerMarks, on: $rulerMarks) { rulerMarks = $0 }
            subscribeSetting(\.skipGlucoseChart, on: $skipGlucoseChart) { skipGlucoseChart = $0 }
            // Dana Toggels
            subscribeSetting(\.danaIconRawValue, on: $danaIconRawValue) { danaIconRawValue = $0 }
            subscribeSetting(\.danaBar, on: $danaBar) { danaBar = $0 }
            subscribeSetting(\.danaBarViewOption, on: $danaBarViewOption) { danaBarViewOption = $0 }
            subscribeSetting(\.insulinAgeOption, on: $insulinAgeOption) { insulinAgeOption = $0 }
            subscribeSetting(\.cannulaAgeOption, on: $cannulaAgeOption) { cannulaAgeOption = $0 }
            subscribeSetting(\.loopViewOption, on: $loopViewOption) { loopViewOption = $0 }
            subscribeSetting(\.insulinBadge, on: $insulinBadge) { insulinBadge = $0 }
            subscribeSetting(\.hideInsulinBadge, on: $hideInsulinBadge) { hideInsulinBadge = $0 }
            subscribeSetting(\.legendsSwitch, on: $legendsSwitch) { legendsSwitch = $0 }
            subscribeSetting(\.tempTargetbar, on: $tempTargetBar) { tempTargetBar = $0 }
            subscribeSetting(\.timeSettings, on: $timeSettings) { timeSettings = $0 }
            subscribeSetting(\.backgroundColorOptionRawValue, on: $backgroundColorOptionRawValue) {
                self.backgroundColorOptionRawValue = $0 }
            subscribeSetting(\.chartBackgroundColored, on: $chartBackgroundColored) { chartBackgroundColored = $0 }
            subscribeSetting(\.carbInsulinLoopViewOption, on: $carbInsulinLoopViewOption) { carbInsulinLoopViewOption = $0 }
            // Dana Toggels
            subscribeSetting(\.alwaysUseColors, on: $alwaysUseColors) { alwaysUseColors = $0 }
            subscribeSetting(\.useFPUconversion, on: $useFPUconversion) { useFPUconversion = $0 }
            subscribeSetting(\.useTargetButton, on: $useTargetButton) { useTargetButton = $0 }
            subscribeSetting(\.skipBolusScreenAfterCarbs, on: $skipBolusScreenAfterCarbs) { skipBolusScreenAfterCarbs = $0 }
            subscribeSetting(\.oneDimensionalGraph, on: $oneDimensionalGraph) { oneDimensionalGraph = $0 }
            subscribeSetting(\.useInsulinBars, on: $useInsulinBars) { useInsulinBars = $0 }
            subscribeSetting(\.extendHomeView, on: $extendHomeView) { extendHomeView = $0 }
            subscribeSetting(\.low, on: $low, initial: {
                let value = max(min($0, 90), 40)
                low = units == .mmolL ? value.asMmolL : value
            }, map: {
                guard units == .mmolL else { return $0 }
                return $0.asMgdL
            })

            subscribeSetting(\.high, on: $high, initial: {
                let value = max(min($0, 270), 110)
                high = units == .mmolL ? value.asMmolL : value
            }, map: {
                guard units == .mmolL else { return $0 }
                return $0.asMgdL
            })

            subscribeSetting(\.hours, on: $hours.map(Int.init), initial: {
                let value = max(min($0, 24), 2)
                hours = Decimal(value)
            }, map: {
                $0
            })

            subscribeSetting(\.minimumSMB, on: $minimumSMB, initial: {
                minimumSMB = max(min($0, 10), 0)
            }, map: {
                $0
            })
        }
    }
}
