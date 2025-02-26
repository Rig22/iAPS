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

        @State private var displayedStartTime: String?

        // **Funktionen müssen außerhalb der View stehen!**
        func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            return formatter.string(from: date)
        }

        func saveSensorStartTime(_ date: Date) {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "sensorStartTime")
        }

        func loadSensorStartTime() -> String? {
            if let savedTime = UserDefaults.standard.value(forKey: "sensorStartTime") as? TimeInterval {
                let savedDate = Date(timeIntervalSince1970: savedTime)
                return formatDate(savedDate)
            }
            return nil
        }

        var body: some View {
            VStack(spacing: 0) {
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
                        .frame(width: 360, height: 280)

                    if state.danaBar && state.danaBarViewOption == "view2" {
                        Image(state.danaIconRawValue)
                            .resizable()
                            .frame(width: 25, height: 18)
                            .offset(x: -53, y: -44)
                    }
                }
                .frame(width: 360, height: 280)
                .padding(.top, 20)
                .padding(.leading, 110)
                .padding(.bottom, 10)

                GeometryReader { geometry in
                    ScrollView {
                        Form {
                            Section(
                                header: Text("Bar Selection"),
                                footer: Text("Select the  desired bar view")
                            ) {
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
                                //  }

                                //  Section {
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
                                        }
                                    }
                                    if state.danaBarViewOption == "view1" {
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
                                // }

                                // Section {
                                Toggle("Legend Bar", isOn: $state.legendsSwitch)
                                Toggle("TT Bar", isOn: $state.tempTargetBar)
                                Toggle("Bottom Bar", isOn: $state.timeSettings)
                            }

                            Section(
                                header: Text("Visual Options"),
                                footer: Text("According to your taste")
                            ) {
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
                                }

                                Toggle("Chart Backgrounds ⇢ Dark", isOn: $state.chartBackgroundColored)
                                Toggle("3D Look", isOn: $state.button3D)
                            }

                            // Section(header: Text("Sensor Settings"))
                            Section(
                                header: Text("Sensor Settings"),
                                footer: Text("Long press for setting new Sensor Start Time")
                            ) {
                                Toggle("Display Sensor Time Remaining", isOn: $state.displayExpiration)
                                if state.displayExpiration {
                                    Picker("Select Sensor Span", selection: $state.sensorAgeDays) {
                                        Text("1 Tag").tag("Ein_Tag")
                                        Text("2 Tage").tag("Zwei_Tage")
                                        Text("3 Tage").tag("Drei_Tage")
                                        Text("4 Tage").tag("Vier_Tage")
                                        Text("5 Tage").tag("Fuenf_Tage")
                                        Text("6 Tage").tag("Sechs_Tage")
                                        Text("7 Tage").tag("Sieben_Tage")
                                        Text("8 Tage").tag("Acht_Tage")
                                        Text("9 Tage").tag("Neun_Tage")
                                        Text("10 Tage").tag("Zehn_Tage")
                                        Text("11 Tage").tag("Elf_Tage")
                                        Text("12 Tage").tag("Zwoelf_Tage")
                                        Text("13 Tage").tag("Dreizehn_Tage")
                                        Text("14 Tage").tag("Vierzehn_Tage")
                                        Text("15 Tage").tag("Fuenfzehn_Tage")
                                    }
                                    .pickerStyle(NavigationLinkPickerStyle())

                                    VStack(alignment: .leading, spacing: 8) {
                                        Button(action: {}, label: {
                                            Text("Start New Sensor")
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 38)
                                                .foregroundColor(.orange)
                                        })
                                            .buttonStyle(.bordered)
                                            .padding(.top)
                                            .simultaneousGesture(
                                                LongPressGesture(minimumDuration: 1.0) // 1 Sekunde halten
                                                    .onEnded { _ in
                                                        let newStartTime = Date()
                                                        state.sensorStartTime = newStartTime
                                                        state.settingsManager.settings.sensorStartTime = newStartTime

                                                        // Formatieren und Speichern der Startzeit
                                                        displayedStartTime = formatDate(newStartTime)
                                                        saveSensorStartTime(newStartTime)

                                                        // Haptisches Feedback
                                                        let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                                                        impactHeavy.impactOccurred()

                                                        print("New sensor started at: \(newStartTime)")
                                                    }
                                            )

                                        // Anzeige der letzten Startzeit
                                        HStack {
                                            Text("Last sensor start time:")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Spacer()
                                            if let startTime = displayedStartTime {
                                                Text(startTime)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(.top)
                                        .padding(.horizontal)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .onAppear {
                                        displayedStartTime = loadSensorStartTime()
                                    }
                                }
                            }

                            Section(header: Text("Chart settings")) {
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
                            }
                            // Toggle("Display Glucose Delta", isOn: $state.displayDelta)

                            Section(header: Text("Button Panel")) {
                                Toggle("Display Temp Targets Button", isOn: $state.useTargetButton)
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
                        .frame(minHeight: geometry.size.height) // Fix für ScrollView
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
