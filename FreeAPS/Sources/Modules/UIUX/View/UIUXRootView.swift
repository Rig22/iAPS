import SwiftUI
import Swinject

extension UIUX {
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

        let dateRange: ClosedRange<Date> = {
            let calendar = Calendar.current
            let now = Date()

            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            let day = calendar.component(.day, from: now) // Aktuellen Tag hinzufügen
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)

            let startComponents = DateComponents(year: 2025, month: 1, day: 1, hour: 0, minute: 0)
            let endComponents = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute) // Tag ergänzt

            let startDate = calendar.date(from: startComponents)!
            let endDate = calendar.date(from: endComponents)!

            return startDate ... endDate
        }()

        @State private var displayedStartTime: String?

        func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            return formatter.string(from: date)
        }

        var body: some View {
            VStack(spacing: 0) {
                ZStack {
                    GeometryReader { geometry in
                        ScrollView {
                            Form {
                                Section(
                                    header: Text("Bars"),
                                    footer: Text("Added Bars you want")
                                ) {
                                    Toggle("Dana Bar", isOn: $state.danaBar)
                                    if state.danaBar {
                                        Picker(
                                            "Max Reservoir Insulin Age",
                                            selection: $state.insulinAgeOption
                                        ) {
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

                                    if state.danaBar {
                                        Picker(
                                            "Max Cannula Age",
                                            selection: $state.cannulaAgeOption
                                        ) {
                                            Text("1 Day").tag("Ein_Tag")
                                            Text("2 Days").tag("Zwei_Tage")
                                            Text("3 Days").tag("Drei_Tage")
                                            Text("4 Days").tag("Vier_Tage")
                                            Text("5 Days").tag("Fuenf_Tage")
                                        }
                                        .pickerStyle(NavigationLinkPickerStyle())
                                    }
                                    Toggle("Bottom Bar", isOn: $state.timeSettings)
                                }

                                Section(
                                    header: Text("Visual Options"),
                                    footer: Text("According to your taste")
                                ) {
                                    Section {
                                        Picker(selection: $state.lightMode, label: Text("Color Scheme")) {
                                            ForEach(LightMode.allCases) { item in
                                                Text(NSLocalizedString(item.rawValue, comment: "ColorScheme Selection"))
                                            }
                                        }
                                    } header: { Text("Light / Dark Mode") }
                                    Toggle("3D Look", isOn: $state.button3D)

                                    Toggle("Show Pump Icon", isOn: $state.showPumpIcon)

                                    if state.showPumpIcon {
                                        if #available(iOS 18.0, *) {
                                            Picker("Select Icon", selection: $state.pumpIconRawValue) {
                                                ForEach(PumpIconOption.allCases, id: \.rawValue) { option in
                                                    HStack {
                                                        Image(option.rawValue)
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 60, height: 40)
                                                        Text(option.displayName)
                                                            .foregroundColor(.primary)
                                                    }
                                                    .tag(option.rawValue)
                                                }
                                            }
                                            .pickerStyle(NavigationLinkPickerStyle())
                                        }
                                    }

                                    Toggle("Hide Concentration Badge", isOn: $state.hideInsulinBadge)
                                    Toggle("Always Color Glucose Value (green, yellow etc)", isOn: $state.alwaysUseColors)
                                    Toggle(
                                        "Never display the small glucose chart when scrolling",
                                        isOn: $state.skipGlucoseChart
                                    )
                                }

                                Section {
                                    Text("App Icons").navigationLink(to: .iconConfig, from: self)
                                } header: { Text("Choose your App Icon") }

                                Section(
                                    header: Text(
                                        "Show Sensor Age for Dexcom G5, G6, G7, Libre 1, Libre 2 and Enlite"
                                    ),
                                    footer: Text("Direct Support implemented")
                                ) {
                                    Toggle("Display Sensor Time Remaining", isOn: $state.displayExpiration)
                                        ._onBindingChange($state.displayExpiration) { enabled in
                                            if enabled {
                                                state.displaySAGE = false
                                            }
                                        }

                                    Toggle("Display Sensor Age", isOn: $state.displaySAGE)
                                        ._onBindingChange($state.displaySAGE) { enabled in
                                            if enabled {
                                                state.displayExpiration = false
                                            }
                                        }
                                }

                                Section(header: Text("Chart settings")) {
                                    Toggle("Display Chart X - Grid lines", isOn: $state.xGridLines)
                                    Toggle("Display Chart Y - Grid lines", isOn: $state.yGridLines)
                                    Toggle("Mark Glucose Target Range", isOn: $state.rulerMarks)
                                    Toggle("Display Insulin Activity Chart", isOn: $state.showInsulinActivity)
                                    Toggle("Display COB Chart", isOn: $state.showCobChart)
                                    HStack {
                                        Text("Currently selected chart time")
                                        Spacer()
                                        DecimalTextField("6", value: $state.hours, formatter: carbsFormatter)
                                        Text("hours").foregroundColor(.white)
                                    }
                                    Toggle("Standing / Laying TIR Chart", isOn: $state.oneDimensionalGraph)
                                    Toggle("Use insulin bars", isOn: $state.useInsulinBars)
                                    Toggle("Use carb bars", isOn: $state.useCarbBars)
                                    Toggle("Display carb equivalents", isOn: $state.fpus)
                                    if state.fpus {
                                        Toggle("Display carb equivalent amount", isOn: $state.fpuAmounts)
                                    }
                                    Toggle("Hide oref0 Predictions", isOn: $state.hidePredictions)
                                }
                                // Toggle("Display Glucose Delta", isOn: $state.displayDelta)

                                Section(header: Text("Button Panel")) {
                                    Toggle("Display Temp Targets Button", isOn: $state.useTargetButton)
                                    Toggle("Display Profile Override Button", isOn: $state.profileButton)
                                    Toggle("Display Meal Button", isOn: $state.carbButton)
                                }

                                Section(header: Text("Statistics settings")) {
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
                                }

                                Section(header: Text("Add Meal View settings")) {
                                    Toggle("Skip Bolus screen after carbs", isOn: $state.skipBolusScreenAfterCarbs)
                                    Toggle("Display and allow Fat and Protein entries", isOn: $state.useFPUconversion)
                                }
                            }
                            .frame(minHeight: geometry.size.height)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
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
}
