import SwiftUI
import Swinject

extension StatConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
            }
            formatter.roundingMode = .halfUp
            return formatter
        }

        private var carbsFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        private var insulinFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        func BarViewOptionConfigurationRawValue(
            topBar: Bool, danaBar: Bool, legendBar: Bool, ttBar: Bool, bottomBar: Bool
        ) -> BarViewOptionConfiguration {
            let activeBars = [
                (topBar, "top"),
                (danaBar, "dana"),
                (legendBar, "legend"),
                (ttBar, "tt"),
                (bottomBar, "bottom")
            ].compactMap { $0.0 ? $0.1 : nil }

            let imageName = "bars_" + (activeBars.isEmpty ? "none" : activeBars.joined(separator: "_"))

            return BarViewOptionConfiguration(rawValue: imageName) ?? .none
        }

        var body: some View {
            /* VStack(alignment: .center) {
               Image(state.danaIconRawValue)
             .resizable()
             .scaledToFit()
             .frame(width: 100, height: 67)
             .padding(.top, 20) */

            Form {
                Section {
                    ZStack {
                        Image(BarViewOptionConfigurationRawValue(
                            topBar: state.carbInsulinLoopViewOption,
                            danaBar: state.danaBar,
                            legendBar: state.legendsSwitch,
                            ttBar: state.tempTargetBar,
                            bottomBar: state.timeSettings
                        ).imageName)
                            .resizable()
                            .scaledToFit()

                        if state.danaBar && state.danaBarViewOption == "view2" { Image(state.danaIconRawValue)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 55)
                            .offset(x: -45, y: 8)
                        } else {}
                    }
                    .frame(width: 360, height: 245)
                }

                Section {
                    Toggle("Top Bar", isOn: $state.carbInsulinLoopViewOption)
                    if state.carbInsulinLoopViewOption {
                        Picker("Select Loop View", selection: $state.loopViewOption) {
                            ForEach(LoopViewOption.allCases) { option in
                                HStack {
                                    Image(option == .view1 ? "LoopView1" : "LoopView2")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                    Text(option.rawValue)
                                        .font(.caption)
                                }
                                .tag(option)
                            }
                        }
                        .pickerStyle(NavigationLinkPickerStyle())
                    }

                    Section {
                        Toggle("Dana Bar", isOn: $state.danaBar)

                        if state.danaBar {
                            Picker("Wähle eine Ansicht", selection: $state.danaBarViewOption) {
                                Text("DanaBar 1").tag("view1")
                                Text("DanaBar 2").tag("view2")
                            }
                            .pickerStyle(SegmentedPickerStyle())

                            if state.danaBarViewOption == "view2" {
                                if #available(iOS 18.0, *) {
                                    Picker("Pump Icon", selection: $state.danaIconRawValue) {
                                        ForEach(DanaIconOption.allCases, id: \.rawValue) { option in
                                            HStack {
                                                Image(option.rawValue)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 60, height: 40)

                                                Text(option.displayName)
                                                    .foregroundColor(.white)
                                            }
                                            .tag(option.rawValue)
                                        }
                                    }
                                    .pickerStyle(NavigationLinkPickerStyle())
                                } else {
                                    // Fallback für frühere iOS-Versionen
                                }
                            }

                            if state.danaBarViewOption == "view1" {
                                Picker("Max Reservoir Insulin Age", selection: $state.insulinAgeOption) {
                                    Text("1 Day").tag("Ein_Tag")
                                    Text("2 Days").tag("Zwei_Tage")
                                    Text("3 Days").tag("Drei_Tage")
                                    Text("4 Days").tag("Vier_Tage")
                                    Text("5 Days").tag("Fuenf_Tage")
                                    Text("6 Days").tag("Sechs_Tage")
                                    Text("7 Days").tag("Sieben_Tage")
                                    Text("8 Days").tag("Acht_Tage")
                                    Text("9 Days").tag("Neun_Tage")
                                    Text("10 Days").tag("Zehn_Tage")
                                }
                                .pickerStyle(NavigationLinkPickerStyle())
                            }

                            Picker("Max Cannula Age", selection: $state.cannulaAgeOption) {
                                Text("1 Day").tag("Ein_Tag")
                                Text("2 Days").tag("Zwei_Tage")
                                Text("3 Days").tag("Drei_Tage")
                                Text("4 Days").tag("Vier_Tage")
                                Text("5 Days").tag("Fuenf_Tage")
                            }
                            .pickerStyle(NavigationLinkPickerStyle())

                            Toggle("Insulin Concentration Badge", isOn: $state.insulinBadge)
                        }
                    }
                    Toggle("Legend Bar", isOn: $state.legendsSwitch)
                    Toggle("TT Bar", isOn: $state.tempTargetBar)
                    Toggle("Bottom Bar", isOn: $state.timeSettings)

                    if #available(iOS 18.0, *) {
                        Picker("Background Color", selection: $state.backgroundColorOptionRawValue) {
                            ForEach(BackgroundColorOption.allCases) { option in
                                HStack {
                                    Rectangle()
                                        .fill(option.color)
                                        .frame(width: 25, height: 25)
                                        .cornerRadius(4)

                                    Text(option.rawValue.capitalized)
                                        .foregroundColor(.primary)
                                }
                                .tag(option.rawValue)
                            }
                        }
                        .pickerStyle(NavigationLinkPickerStyle())
                    } else {
                        // Fallback für frühere iOS-Versionen
                    }

                    Toggle("Chart Backgrounds ⇢ Dark", isOn: $state.chartBackgroundColored)
                    Toggle("Never display the small glucose chart when scrolling", isOn: $state.skipGlucoseChart)
                } header: { Text("UI | UX Settings ") }

                Section {
                    Toggle("Display Chart X - Grid lines", isOn: $state.xGridLines)
                    Toggle("Display Chart Y - Grid lines", isOn: $state.yGridLines)
                    Toggle("Display Chart Threshold lines for Low and High", isOn: $state.rulerMarks)
                    HStack {
                        Text("Currently selected chart time")
                        Spacer()
                        DecimalTextField("6", value: $state.hours, formatter: carbsFormatter)
                        Text("hours").foregroundColor(.white)
                    }
                    Toggle("Standing / Laying TIR Chart", isOn: $state.oneDimensionalGraph)
                    Toggle("Use insulin bars", isOn: $state.useInsulinBars)
                    HStack {
                        Text("Hide the bolus amount strings when amount is under")
                        Spacer()
                        DecimalTextField("0.2", value: $state.minimumSMB, formatter: insulinFormatter)
                        Text("U").foregroundColor(.secondary)
                    }
                } header: { Text("Chart settings ") }

                Section {
                    Toggle("Display Temp Targets Button", isOn: $state.useTargetButton)
                } header: { Text("Button Panel ") }
                footer: { Text("In case you're using both profiles and temp targets") }

                Section {
                    HStack {
                        Text("Low")
                        Spacer()
                        DecimalTextField("0", value: $state.low, formatter: glucoseFormatter)
                        Text(state.units.rawValue).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("High")
                        Spacer()
                        DecimalTextField("0", value: $state.high, formatter: glucoseFormatter)
                        Text(state.units.rawValue).foregroundColor(.secondary)
                    }
                    Toggle("Override HbA1c Unit", isOn: $state.overrideHbA1cUnit)

                } header: { Text("Statistics settings ") }

                Section {
                    Toggle("Skip Bolus screen after carbs", isOn: $state.skipBolusScreenAfterCarbs)
                    Toggle("Display and allow Fat and Protein entries", isOn: $state.useFPUconversion)
                } header: { Text("Add Meal View settings ") }

                /*   Section {
                     Toggle(isOn: $state.extendHomeView) {
                         Text("Display Ratio and a History View button")
                     }
                 } header: { Text("Auto ISF Home View") }*/
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .onAppear(perform: configureView)
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("UI/UX")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}
