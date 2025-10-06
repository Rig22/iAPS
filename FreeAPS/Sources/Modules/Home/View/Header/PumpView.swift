import SwiftUI

enum PumpType {
    case omnipod
    case medtrum
    case mdtDana
    case simulator

    var maxCapacity: Double {
        switch self {
        case .medtrum,
             .omnipod: return 200
        case .mdtDana,
             .simulator: return 300
        }
    }
}

struct PumpView: View {
    @Binding var reservoir: Decimal?
    @Binding var battery: Battery?
    @Binding var name: String
    @Binding var expiresAtDate: Date?
    @Binding var timerDate: Date
    @Binding var timeZone: TimeZone?

    @State var state: Home.StateModel

    @Environment(\.colorScheme) var colorScheme

    private var reservoirFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    private var batteryFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        return dateFormatter
    }

    @FetchRequest(
        entity: InsulinConcentration.entity(), sortDescriptors: [NSSortDescriptor(key: "date", ascending: true)]
    ) var concentration: FetchedResults<InsulinConcentration>

    private var pumpType: PumpType {
        if state.pumpName.contains("Omni") {
            return .omnipod
        } else if state.pumpName.contains("Medtrum") {
            return .medtrum
        } else if state.pumpName.contains("Simulator") {
            return .simulator
        } else {
            return .mdtDana
        }
    }

    private var usePodLayout: Bool {
        pumpType == .omnipod || pumpType == .medtrum
    }

    private var showInsulinBadge: Bool {
        (concentration.last?.concentration ?? 1) != 1 && !state.settingsManager.settings.hideInsulinBadge
    }

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                if usePodLayout {
                    if pumpType == .medtrum {
                        medtrumContent()
                    } else {
                        omnipodContent()
                    }
                } else {
                    switch pumpType {
                    case .mdtDana:
                        mdtDanaContent()
                    case .simulator:
                        HStack(spacing: 8) {
                            mdtDanaContent()
                            simulatorContent()
                        }
                    default:
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                TimeEllipse(
                    button3D: state.button3D,
                    minHeight: 40,
                    cornerRadius: 20,
                    horizontalPadding: 6
                )
            )
        }
        .offset(x: 0, y: 10) // Overall vertical adjustment
    }

    // MARK: - Simulator

    @ViewBuilder private func simulatorContent() -> some View {
        // Empty for now
    }

    // MARK: - Medtrum Content

    @ViewBuilder private func medtrumContent() -> some View {
        if let date = expiresAtDate {
            HStack(spacing: 8) {
                if let insulin = reservoir {
                    let adjustedReservoir = Double(insulin) * (concentration.last?.concentration ?? 1)
                    let maxReservoir: Double = 200
                    let portion = max(0.0, min(1.0, adjustedReservoir / maxReservoir))

                    if insulin == 0xDEAD_BEEF {
                        medtrumInsulinAmount(portion: 1 - portion)
                            .overlay(alignment: .topLeading) {
                                if showInsulinBadge {
                                    NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: true)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if let timeZone = timeZone,
                                   timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
                                {
                                    ClockOffset(mdtPump: false)
                                }
                            }
                    } else {
                        medtrumInsulinAmount(portion: 1 - portion)
                            .overlay(alignment: .center) {
                                HStack(spacing: 1) {
                                    Text(
                                        reservoirFormatter
                                            .string(from: (
                                                insulin *
                                                    Decimal(concentration.last?.concentration ?? 1)
                                            ) as NSNumber) ?? ""
                                    )
                                    .font(.system(size: 11, weight: .medium))
                                    // Text("U")
                                    Text("")
                                        .font(.system(size: 7, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0.5, y: 0.5) // Leichter Schatten für Kontrast
                            }
                            .overlay(alignment: .topLeading) {
                                if showInsulinBadge {
                                    NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: true)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if let timeZone = timeZone,
                                   timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
                                {
                                    ClockOffset(mdtPump: false)
                                }
                            }
                    }
                }

                // Time remaining
                VStack(spacing: 2) {
                    remainingTimeMedtrum(time: date.timeIntervalSince(timerDate))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.dynamicSecondaryText)
                }
            }
        } else {
            Text("No Pump")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.dynamicSecondaryText)
        }
    }

    // MARK: - Omnipod Content

    @ViewBuilder private func omnipodContent() -> some View {
        if let date = expiresAtDate {
            HStack(spacing: 8) {
                if let insulin = reservoir {
                    let amountFraction = 1.0 - (Double(insulin + 10) * 1.2 / 200)

                    if insulin == 0xDEAD_BEEF {
                        podInsulinAmount(portion: amountFraction)
                            .overlay(alignment: .topLeading) {
                                if showInsulinBadge {
                                    NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: true)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if let timeZone = timeZone,
                                   timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
                                {
                                    ClockOffset(mdtPump: false)
                                }
                            }
                    } else {
                        HStack(spacing: 2) {
                            Text(
                                reservoirFormatter
                                    .string(from: (insulin * Decimal(concentration.last?.concentration ?? 1)) as NSNumber) ??
                                    ""
                            )
                            .font(.system(size: 17, weight: .medium))
                            Text("U")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.dynamicSecondaryText)

                        podInsulinAmount(portion: amountFraction)
                            .overlay(alignment: .topLeading) {
                                if showInsulinBadge {
                                    NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: true)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if let timeZone = timeZone,
                                   timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
                                {
                                    ClockOffset(mdtPump: false)
                                }
                            }
                    }
                }

                // Time remaining
                remainingTime(time: date.timeIntervalSince(timerDate))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.dynamicSecondaryText)
            }
        } else {
            Text("No Patch")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.dynamicSecondaryText)
        }
    }

    // MARK: - MDT/Dana Content

    @ViewBuilder private func mdtDanaContent() -> some View {
        if let reservoir = reservoir {
            let amountFraction = 1.0 - (Double(reservoir) / 300.0)

            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Text(
                        reservoirFormatter
                            .string(from: (reservoir * Decimal(concentration.last?.concentration ?? 1)) as NSNumber) ?? ""
                    )
                    .font(.system(size: 17, weight: .medium))
                    Text("U")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundColor(.dynamicSecondaryText)

                pumpInsulinAmount(portion: amountFraction)
                    .overlay(alignment: .topLeading) {
                        if showInsulinBadge {
                            NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: false)
                        }
                    }

                // Battery icon right next to pump symbol
                if battery != nil {
                    batteryIcon(for: .mdtDana)
                }
            }
        } else {
            Text("No Pump")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.dynamicSecondaryText)
        }
    }

    // MARK: - Remaining Time Views

    private func remainingTime(time: TimeInterval) -> some View {
        let color: Color = {
            if time <= 0 { return .red }
            else if time < 4 * 60 * 60 { return .red }
            else if time < 24 * 60 * 60 { return .orange }
            else { return .dynamicSecondaryText }
        }()

        return Group {
            if time > 0 {
                let days = Int(time / 1.days.timeInterval)
                let hours = Int(time / 1.hours.timeInterval)
                let minutes = Int(time / 1.minutes.timeInterval)
                let adjustedHours = Int(hours - days * 24)

                if days >= 1 {
                    HStack(spacing: 2) {
                        Text("\(days)")
                        Text("d")
                        if adjustedHours >= 0 {
                            Text("\(adjustedHours)")
                            Text("h")
                        }
                    }
                } else if hours >= 1 {
                    HStack(spacing: 2) {
                        Text("\(hours)")
                        Text("h")
                    }
                } else {
                    HStack(spacing: 2) {
                        Text("\(minutes)")
                        Text("m")
                    }
                }
            } else {
                Text("Replace")
            }
        }
        .foregroundStyle(color)
    }

    private func remainingTimeMedtrum(time: TimeInterval) -> some View {
        let color: Color = {
            if time <= 0 { return .green }
            else if time < 4 * 60 * 60 { return .red }
            else if time < 24 * 60 * 60 { return .orange }
            else { return .dynamicSecondaryText }
        }()

        return Group {
            if time > 0 {
                let days = Int(time / 1.days.timeInterval)
                let hours = Int(time / 1.hours.timeInterval)
                let minutes = Int(time / 1.minutes.timeInterval)
                let adjustedHours = Int(hours - days * 24)

                if days >= 1 {
                    HStack(spacing: 2) {
                        Text("\(days)")
                        Text("d")
                        if adjustedHours >= 0 {
                            Text("\(adjustedHours)")
                            Text("h")
                        }
                    }
                } else if hours >= 1 {
                    HStack(spacing: 2) {
                        Text("\(hours)")
                        Text("h")
                    }
                } else {
                    HStack(spacing: 2) {
                        Text("\(minutes)")
                        Text("m")
                    }
                }
            } else {
                Text("Battery Mode")
                    .foregroundStyle(Color.dynamicSecondaryText)
            }
        }
        .foregroundStyle(color)
    }

    // MARK: - Icon Views

    private func podInsulinAmount(portion: Double) -> some View {
        ZStack {
            let pump = colorScheme == .dark ? "pod_dark" : "pod_light"
            UIImage(imageLiteralResourceName: pump)
                .fillImageUpToPortion(color: reservoirColor.opacity(0.8), portion: portion)
                .resizable()
                .aspectRatio(0.72, contentMode: .fit)
                .frame(width: IAPSconfig.iconSize, height: IAPSconfig.iconSize)
                .symbolRenderingMode(.palette)
                .shadow(radius: 1, x: 2, y: 2)
                .foregroundColor(.dynamicIconBackground)
                .overlay {
                    let units = 50 * (concentration.last?.concentration ?? 1)
                    portion <= 0.3 ?
                        Text((reservoirFormatter.string(from: units as NSNumber) ?? "") + "+")
                        .foregroundColor(.white)
                        .font(.system(size: 6))
                        .offset(y: -4)
                        : nil
                }
        }
    }

    private func pumpInsulinAmount(portion: Double) -> some View {
        ZStack {
            let pump = colorScheme == .dark ? "pump_dark" : "pump_light"
            UIImage(imageLiteralResourceName: pump)
                .fillImageUpToPortion(color: reservoirColor.opacity(0.8), portion: max(portion, 0.0))
                .resizable()
                .frame(width: 30, height: 30)
                .symbolRenderingMode(.palette)
                .shadow(radius: 1, x: 2, y: 2)
                .foregroundColor(.dynamicIconBackground)
        }
    }

    private func medtrumInsulinAmount(portion: Double) -> some View {
        ZStack {
            let medtrumpump = colorScheme == .dark ? "nano200light" : "nano200light"
            UIImage(imageLiteralResourceName: medtrumpump)
                .fillImageUpToPortion(color: reservoirColor.opacity(0.8), portion: max(portion, 0.0))
                .resizable()
                .frame(width: 34, height: 34)
                .symbolRenderingMode(.palette)
                .shadow(radius: 1, x: 2, y: 2)
                .foregroundColor(.dynamicIconBackground)
            /*  .overlay {
                 // Zusätzlicher Overlay für niedrigen Füllstand (wie bei Omnipod)
                 if portion >= 0.7 { // Wenn nur noch wenig Insulin (portion ist 1 - Füllstand)
                     let units = 50 * (concentration.last?.concentration ?? 1)
                     Text((reservoirFormatter.string(from: units as NSNumber) ?? "") + "+")
                         .foregroundColor(.white)
                         .font(.system(size: 6))
                         .offset(y: -8) // Position an Medtrum-Icon anpassen
                 }
             }*/
        }
    }

    @ViewBuilder private func batteryIcon(for _: PumpType) -> some View {
        if let battery = battery {
            let percent = batteryLevel(for: battery.percent ?? 100)

            Image(systemName: "battery.\(percent)")
                .resizable()
                .rotationEffect(.degrees(-90))
                .frame(maxWidth: 31, maxHeight: 14)
                .foregroundColor(batteryColor)
        }
    }

    // MARK: - Helper Properties

    private var batteryColor: Color {
        guard let battery = battery, let percent = battery.percent else {
            return .gray
        }
        switch percent {
        case ...10:
            return .red
        case ...20:
            return .yellow
        default:
            return .green
        }
    }

    private var reservoirColor: Color {
        guard let reservoir = reservoir else {
            return .clear
        }

        switch reservoir {
        case ...10:
            return .red
        case ...30:
            return .yellow
        default:
            return .blue
        }
    }

    // Hilfsfunktion für Batterie-Level
    private func batteryLevel(for percent: Int) -> Int {
        switch percent {
        case ...40: return 25
        case ...60: return 50
        case ...80: return 75
        default: return 100
        }
    }
}

struct NonStandardInsulin: View {
    let concentration: Double
    let pod: Bool

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.red)
                .frame(width: 28, height: 12)
                .overlay {
                    Text("U" + (formatter.string(from: concentration * 100 as NSNumber) ?? ""))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white)
                }
        }
        .offset(x: -12, y: -12)
    }
}
