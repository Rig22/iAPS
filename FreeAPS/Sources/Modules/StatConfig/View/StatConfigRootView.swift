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

        var body: some View {
            // VStack(alignment: .center) {
            /*  Image(state.danaIconRawValue)
             .resizable()
             .scaledToFit()
             .frame(width: 200, height: 200)
             .padding(.top, 20)*/

            Form {
                Section {
                    if #available(iOS 18.0, *) {
                        Picker("Pumpen-Icon", selection: $state.danaIconRawValue) {
                            ForEach(DanaIconOption.allCases, id: \.rawValue) { option in
                                HStack {
                                    Image(option.rawValue)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 80)

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

                    Toggle("Dana Bar", isOn: $state.danaBar)

                    if state.danaBar {
                        Toggle("Insulin Concentration Badge", isOn: $state.insulinBadge)
                            .transition(.opacity)
                            .animation(.default, value: state.danaBar)
                    }
                    Toggle("Legend Bar", isOn: $state.legendsSwitch)
                    Toggle("TempTarget Bar", isOn: $state.tempTargetBar)
                    Toggle("Bottom Bar", isOn: $state.timeSettings)
                } header: { Text("Dana UI | UX Settings ") }

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

                } header: { Text("Home Chart settings ") }

                Section {
                    Toggle("Display Temp Targets Button", isOn: $state.useTargetButton)
                } header: { Text("Home View Button Panel ") }
                footer: { Text("In case you're using both profiles and temp targets") }

                Section {
                    Toggle("Never display the small glucose chart when scrolling", isOn: $state.skipGlucoseChart)
                    // Toggle("Always Color Glucose Value (green, yellow etc)", isOn: $state.alwaysUseColors)
                } header: { Text("Header settings") }
                /*  footer: {
                 Text("Normally glucose is colored red only when over or under your notification limits for high/low") }*/

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
