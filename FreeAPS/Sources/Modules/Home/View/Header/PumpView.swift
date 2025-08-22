import SwiftUI

enum PumpType {
    case omnipod
    case medtrum
    case mdtDana

    var maxCapacity: Double {
        switch self {
        case .medtrum,
             .omnipod: return 200
        case .mdtDana: return 300
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
        HStack(spacing: 5) {
            // Common layout for Omnipod and Medtrum (pod-style)
            if usePodLayout {
                // Container für Medtrum mit Offset
                if pumpType == .medtrum {
                    medtrumContent()
                    // .offset(x: 15) // Medtrum-spezifischer Offset
                } else {
                    omnipodContent()
                }
            }
            // MDT/Dana/Simulator layout
            else {
                mdtDanaContent()
                simulatorContent()
            }
        }
        .offset(x: 0, y: 15) // Overall vertical adjustment
    }

    // MARK: - Simulator

    @ViewBuilder private func simulatorContent() -> some View {
        Image(systemName: "gearshape.2.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: 36)
            .foregroundColor(.gray)
            .overlay(
                Text("Sim")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.white)
                    .offset(y: 18)
            )
    }

    @ViewBuilder private func medtrumContent() -> some View {
        if let date = expiresAtDate {
            if let insulin = reservoir {
                let adjustedReservoir = Double(insulin) * (concentration.last?.concentration ?? 1)
                let maxReservoir: Double = 200
                let portion = max(0.0, min(1.0, adjustedReservoir / maxReservoir))

                if insulin == 0xDEAD_BEEF {
                    medtrumInsulinAmount(portion: 1 - portion)
                        .padding(.leading, showInsulinBadge ? 7 : 0)
                        .overlay {
                            if let timeZone = timeZone,
                               timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
                            {
                                ClockOffset(mdtPump: false)
                            }
                            if showInsulinBadge {
                                NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: true)
                            }
                        }
                        .offset(y: -5)
                } else {
                    HStack(spacing: 0) {
                        Text(
                            reservoirFormatter
                                .string(from: (insulin * Decimal(concentration.last?.concentration ?? 1)) as NSNumber) ?? ""
                        )
                        Text("U")
                    }
                    .foregroundStyle(.white)
                    .offset(x: 2, y: 0)

                    medtrumInsulinAmount(portion: 1 - portion)
                        .padding(.leading, showInsulinBadge ? 7 : 0)
                        .overlay {
                            if let timeZone = timeZone,
                               timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
                            {
                                ClockOffset(mdtPump: false)
                            }
                            if showInsulinBadge {
                                NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: true)
                            }
                        }
                        .offset(y: -5)
                }
            }

            HStack(spacing: 4) {
                remainingTimeMedtrum(time: date.timeIntervalSince(timerDate))
                    .font(.pumpFont)

                /*    if battery != nil {
                     batteryIcon(for: .medtrum)
                         .offset(x: -6, y: 0)
                 }*/
            }
            .offset(x: -4, y: 0)
        } else {
            Text("No Pump")
                .font(.statusFont)
                .foregroundStyle(.white)
                .offset(x: 0, y: -4)
        }
    }

    // Omnipod-spezifischer Content
    @ViewBuilder private func omnipodContent() -> some View {
        if let date = expiresAtDate {
            // Insulin amount (U)
            if let insulin = reservoir {
                // 120 % due to being non rectangular. +10 because of bottom inserter
                let amountFraction = 1.0 - (Double(insulin + 10) * 1.2 / 200)
                if insulin == 0xDEAD_BEEF {
                    podInsulinAmount(portion: amountFraction)
                        .padding(.leading, showInsulinBadge ? 7 : 0)
                        .overlay {
                            if let timeZone = timeZone,
                               timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
                            {
                                ClockOffset(mdtPump: false)
                            }
                            if showInsulinBadge {
                                NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: true)
                            }
                        }
                        .offset(y: -3) // Pod insulin vertical adjustment
                } else {
                    HStack(spacing: 0) {
                        Text(
                            reservoirFormatter
                                .string(from: (insulin * Decimal(concentration.last?.concentration ?? 1)) as NSNumber) ??
                                ""
                        )
                        Text("U")
                    }
                    .foregroundStyle(.white)
                    .offset(x: 6, y: 0) // Horizontal adjustment
                    podInsulinAmount(portion: amountFraction)
                        .padding(.leading, showInsulinBadge ? 7 : 0)
                        .overlay {
                            if let timeZone = timeZone,
                               timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
                            {
                                ClockOffset(mdtPump: false)
                            }
                            if showInsulinBadge {
                                NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: true)
                            }
                        }
                        .offset(y: -5) // Pod insulin vertical adjustment
                }
            }

            HStack(spacing: 4) {
                remainingTime(time: date.timeIntervalSince(timerDate))
                    .font(.pumpFont)
            }
            .offset(x: -4, y: 0) // Vertical adjustment für time row
        } else {
            Text("No Patch")
                .font(.statusFont)
                .foregroundStyle(.white)
                .offset(x: 0, y: -4)
        }
    }

    @ViewBuilder private func mdtDanaContent() -> some View {
        if let reservoir = reservoir {
            let amountFraction = 1.0 - (Double(reservoir) / 300.0)

            HStack(spacing: 0) {
                Text(
                    reservoirFormatter
                        .string(from: (reservoir * Decimal(concentration.last?.concentration ?? 1)) as NSNumber) ?? ""
                )
                .font(.statusFont)
                Text("U")
                    .font(.statusFont)
            }
            .foregroundStyle(.white)
            .offset(y: 9)

            pumpInsulinAmount(portion: amountFraction)
                .padding(.leading, showInsulinBadge ? 7 : 0)
                .overlay {
                    /* if let timeZone, timeZone != TimeZone.current {
                         ClockOffset(mdtPump: false)
                     }*/
                    if showInsulinBadge {
                        NonStandardInsulin(concentration: concentration.last?.concentration ?? 1, pod: false)
                    }
                }

            if battery != nil {
                batteryIcon(for: .mdtDana)
            }
        } else {
            Text("No Pump")
                .font(.statusFont)
                .foregroundStyle(.white)
        }
    }

    private func remainingTime(time: TimeInterval) -> some View {
        let color: Color = {
            if time <= 0 { return .red }
            else if time < 4 * 60 * 60 { return .red }
            else if time < 24 * 60 * 60 { return .yellow }
            else { return .white }
        }()

        return HStack {
            if time > 0 {
                let days = Int(time / 1.days.timeInterval)
                let hours = Int(time / 1.hours.timeInterval)
                let minutes = Int(time / 1.minutes.timeInterval)
                let adjustedHours = Int(hours - days * 24)

                if days >= 1 {
                    HStack(spacing: 0) {
                        Text(" \(days)")
                        Text(NSLocalizedString("d", comment: "abbreviation for days"))
                        if adjustedHours >= 0 {
                            Text(" ")
                            Text("\(adjustedHours)")
                            Text(NSLocalizedString("h", comment: "abbreviation for hours"))
                        }
                    }
                } else if hours >= 1 {
                    HStack(spacing: 0) {
                        Text("\(hours)")
                        Text(NSLocalizedString("h", comment: "abbreviation for hours"))
                    }
                } else {
                    HStack(spacing: 0) {
                        Text(" \(minutes)")
                        Text(NSLocalizedString("m", comment: "abbreviation for minutes"))
                    }
                }
            } else {
                Text(NSLocalizedString("Replace", comment: "View/Header when pod expired"))
            }
        }
        .foregroundStyle(color)
    }

    private func remainingTimeMedtrum(time: TimeInterval) -> some View {
        let color: Color = {
            if time <= 0 { return .green }
            else if time < 4 * 60 * 60 { return .red }
            else if time < 24 * 60 * 60 { return .yellow }
            else { return .white }
        }()

        return HStack {
            if time > 0 {
                let days = Int(time / 1.days.timeInterval)
                let hours = Int(time / 1.hours.timeInterval)
                let minutes = Int(time / 1.minutes.timeInterval)
                let adjustedHours = Int(hours - days * 24)

                if days >= 1 {
                    HStack(spacing: 0) {
                        Text(" \(days)")
                        Text(NSLocalizedString("d", comment: "abbreviation for days"))
                        if adjustedHours >= 0 {
                            Text(" ")
                            Text("\(adjustedHours)")
                            Text(NSLocalizedString("h", comment: "abbreviation for hours"))
                        }
                    }
                } else if hours >= 1 {
                    HStack(spacing: 0) {
                        Text("\(hours)")
                        Text(NSLocalizedString("h", comment: "abbreviation for hours"))
                    }
                } else {
                    HStack(spacing: 0) {
                        Text(" \(minutes)")
                        Text(NSLocalizedString("m", comment: "abbreviation for minutes"))
                    }
                }
            } else {
                Text(NSLocalizedString("Power Mode", comment: "View/Header when pod expired"))
            }
        }
        .foregroundStyle(color)
    }

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
            return .gray
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

    private var timerColor: Color {
        guard let expisesAt = expiresAtDate else {
            return .gray
        }

        let time = expisesAt.timeIntervalSince(timerDate)

        switch time {
        case ...8.hours.timeInterval:
            return .red
        case ...1.days.timeInterval:
            return .yellow
        default:
            return .green
        }
    }

    private func podInsulinAmount(portion: Double) -> some View {
        ZStack {
            let pump = colorScheme == .dark ? "pod_dark" : "pod_light"
            UIImage(imageLiteralResourceName: pump)
                .fillImageUpToPortion(color: reservoirColor.opacity(0.8), portion: portion)
                .resizable()
                .aspectRatio(0.72, contentMode: .fit)
                .frame(width: IAPSconfig.iconSize, height: IAPSconfig.iconSize)
                .symbolRenderingMode(.palette)
                .offset(x: 0, y: -5)
                .shadow(radius: 1, x: 2, y: 2)
                .foregroundStyle(.white)
                .overlay {
                    let units = 50 * (concentration.last?.concentration ?? 1)
                    portion <= 0.3 ?
                        Text((reservoirFormatter.string(from: units as NSNumber) ?? "") + "+").foregroundStyle(.white)
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
                .frame(maxWidth: 30, maxHeight: 30)
                .symbolRenderingMode(.palette)
                .shadow(radius: 1, x: 2, y: 2)
                .foregroundStyle(.white)
        }
    }

    private func medtrumInsulinAmount(portion: Double) -> some View {
        ZStack {
            UIImage(imageLiteralResourceName: "nano200pumpview")
                .fillImageUpToPortion(color: reservoirColor.opacity(0.8), portion: max(portion, 0.0))
                .resizable()
                .frame(maxWidth: 30, maxHeight: 30)
                .symbolRenderingMode(.palette)
                .shadow(radius: 1, x: 2, y: 2)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder private func batteryIcon(for type: PumpType) -> some View {
        if let battery = battery {
            let percent = batteryLevel(for: battery.percent ?? 100)
            let offsetY: CGFloat = {
                switch type {
                case .medtrum: return -8 // Offset für Medtrum
                case .mdtDana: return 0 // Offset für MDT/Dana
                default: return -1 // Leichter Offset für Omnipod (wird im Moment nicht verwendet)
                }
            }()

            Image(systemName: "battery.\(percent)")
                .resizable()
                .rotationEffect(.degrees(-90))
                .frame(maxWidth: 31, maxHeight: 14)
                .foregroundColor(batteryColor)
                .offset(y: offsetY)
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
            RoundedRectangle(cornerRadius: 15)
                .fill(.red)
                .frame(width: 33, height: 15)
                .overlay {
                    Text("U" + (formatter.string(from: concentration * 100 as NSNumber) ?? ""))
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                }
        }
        .offset(x: pod ? -15 : -15, y: pod ? -24 : -22) // Gleicher Offset für alle Pumpentypen
    }
}
