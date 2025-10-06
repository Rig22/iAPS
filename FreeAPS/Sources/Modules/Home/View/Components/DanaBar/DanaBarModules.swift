import SwiftUI

private var reservoirFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter
}

// MARK: - Helper Functions

private func colorForRemainingHours(_ remainingHours: CGFloat) -> Color {
    switch remainingHours {
    case ..<2: return .dynamicColorRed
    case ..<6: return .dynamicColorYellow
    default: return .dynamicIconForeground
    }
}

// MARK: - InsulinCatheterSymbol

public struct InsulinCatheterSymbol: View {
    var color: Color
    var baseSize: CGFloat = 40

    public init(color: Color, baseSize: CGFloat = 40) {
        self.color = color
        self.baseSize = baseSize
    }

    public var body: some View {
        ZStack {
            Image(systemName: "hockey.puck")
                .resizable()
                .foregroundStyle(color)
                .frame(width: 22, height: 12)
                .offset(x: 0, y: -1)

            Rectangle()
                .frame(width: 2, height: 7)
                .foregroundStyle(color)
                .offset(x: 0, y: 8)
        }
        .frame(width: baseSize, height: baseSize)
    }
}

// MARK: - ReservoirView

public struct ReservoirView: View {
    @ObservedObject var viewModel: DanaBarViewModel
    @StateObject private var pieSegmentViewModel = PieSegmentViewModel()

    public init(viewModel: DanaBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let reservoir = viewModel.reservoirLevel {
                let maxValue = Decimal(300)
                let reservoirDecimal = Decimal(reservoir)
                let fractionDecimal = reservoirDecimal / maxValue
                let fill = max(min(CGFloat(NSDecimalNumber(decimal: fractionDecimal).doubleValue), 1.0), 0.0)

                let reservoirColor: Color = {
                    if reservoir < 20 {
                        return .dynamicColorRed
                    } else if reservoir < 50 {
                        return .dynamicColorYellow
                    } else {
                        return .dynamicIconForeground.opacity(0.5)
                    }
                }()

                let displayText: String = {
                    if reservoir == 0 {
                        return "--"
                    } else {
                        let concentrationValue = Decimal(viewModel.concentration.last?.concentration ?? 1.0)
                        let adjustedReservoir = reservoirDecimal * concentrationValue
                        return (reservoirFormatter.string(from: adjustedReservoir as NSNumber) ?? "") + "U"
                    }
                }()

                ZStack {
                    FillablePieSegment(
                        pieSegmentViewModel: pieSegmentViewModel,
                        fillFraction: fill,
                        color: reservoirColor,
                        backgroundColor: .clear,
                        displayText: displayText,
                        symbolSize: 25,
                        symbol: "",
                        animateProgress: false,
                        button3D: viewModel.button3D,
                        symbolRotation: -90,
                        symbolBackgroundColor: Color.dynamicIconBackground,
                        symbolColor: Color.dynamicIconForeground
                    )
                    .frame(width: 60, height: 60)
                    Image(systemName: "cross.vial")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.dynamicIconForeground)
                        .frame(width: 25, height: 25)
                }
            }
        }
    }
}

// MARK: - CannulaAgeView

public struct CannulaAgeView: View {
    @ObservedObject var viewModel: DanaBarViewModel
    @StateObject private var pieSegmentViewModel = PieSegmentViewModel()

    public init(viewModel: DanaBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            let cannulaDisplayText: String = {
                guard let cannulaHours = viewModel.cannulaHours,
                      let cannulaAgeOption = CannulaAgeOption(rawValue: viewModel.cannulaAgeOption)
                else {
                    return "--"
                }

                let remainingHours = max(cannulaAgeOption.maxCannulaAge - cannulaHours, 0)
                let totalRemainingMinutes = Int(remainingHours * 60)
                let days = totalRemainingMinutes / (24 * 60)
                let hours = (totalRemainingMinutes % (24 * 60)) / 60
                let minutes = totalRemainingMinutes % 60

                if days >= 1 {
                    return "\(days)d\(hours)h"
                } else if hours >= 1 {
                    return "\(hours)h\(minutes)m"
                } else {
                    return "\(minutes)m"
                }
            }()

            let cannulaFraction: CGFloat = {
                if let cannulaHours = viewModel.cannulaHours,
                   let cannulaAgeOption = CannulaAgeOption(rawValue: viewModel.cannulaAgeOption)
                {
                    let remainingHours = cannulaAgeOption.maxCannulaAge - cannulaHours
                    if remainingHours <= 1 {
                        return 1.0
                    } else {
                        return CGFloat(min(max(
                            remainingHours / cannulaAgeOption.maxCannulaAge,
                            0.0
                        ), 1.0))
                    }
                } else {
                    return 0.0
                }
            }()

            let cannulaColor: Color = {
                if let cannulaHours = viewModel.cannulaHours,
                   let cannulaAgeOption = CannulaAgeOption(rawValue: viewModel.cannulaAgeOption)
                {
                    let maxCannulaAge = cannulaAgeOption.maxCannulaAge
                    let remainingHours = maxCannulaAge - CGFloat(cannulaHours)
                    return colorForRemainingHours(remainingHours)
                } else {
                    return .clear
                }
            }()

            ZStack {
                FillablePieSegment(
                    pieSegmentViewModel: pieSegmentViewModel,
                    fillFraction: cannulaFraction,
                    color: cannulaColor,
                    backgroundColor: .clear,
                    displayText: cannulaDisplayText,
                    symbolSize: 0,
                    symbol: "",
                    animateProgress: false,
                    button3D: viewModel.button3D,
                    symbolRotation: -90,
                    symbolBackgroundColor: Color.dynamicIconBackground,
                    symbolColor: Color.dynamicIconForeground
                )
                .frame(width: 60, height: 60)

                InsulinCatheterSymbol(color: cannulaColor)
                    .offset(y: -1.5)
            }
        }
    }
}

// MARK: - InsulinAgeView

public struct InsulinAgeView: View {
    @ObservedObject var viewModel: DanaBarViewModel
    @StateObject private var pieSegmentViewModel = PieSegmentViewModel()

    public init(viewModel: DanaBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            let insulinDisplayText: String = {
                guard let insulinHours = viewModel.insulinHours,
                      let insulinAgeOption = InsulinAgeOption(rawValue: viewModel.insulinAgeOption)
                else {
                    return "--"
                }

                let remainingHours = max(insulinAgeOption.maxInsulinAge - insulinHours, 0)
                let totalRemainingMinutes = Int(remainingHours * 60)
                let days = totalRemainingMinutes / (24 * 60)
                let hours = (totalRemainingMinutes % (24 * 60)) / 60
                let minutes = totalRemainingMinutes % 60

                if days >= 1 {
                    return "\(days)d\(hours)h"
                } else if hours >= 1 {
                    return "\(hours)h\(minutes)m"
                } else {
                    return "\(minutes)m"
                }
            }()

            let insulinFraction: CGFloat = {
                guard let insulinHours = viewModel.insulinHours,
                      let insulinAgeOption = InsulinAgeOption(rawValue: viewModel.insulinAgeOption)
                else {
                    return 0.0
                }
                let remainingHours = insulinAgeOption.maxInsulinAge - insulinHours
                return remainingHours <= 1 ? 1.0 : CGFloat(min(max(
                    remainingHours / insulinAgeOption.maxInsulinAge,
                    0.0
                ), 1.0))
            }()

            let insulinColor: Color = {
                guard let insulinHours = viewModel.insulinHours,
                      let insulinAgeOption = InsulinAgeOption(rawValue: viewModel.insulinAgeOption)
                else {
                    return .clear
                }

                let maxInsulinAge = insulinAgeOption.maxInsulinAge
                let remainingHours = maxInsulinAge - CGFloat(insulinHours)

                return colorForRemainingHours(remainingHours)
            }()

            ZStack {
                FillablePieSegment(
                    pieSegmentViewModel: pieSegmentViewModel,
                    fillFraction: insulinFraction,
                    color: insulinColor,
                    backgroundColor: .clear,
                    displayText: insulinDisplayText,
                    symbolSize: 25,
                    symbol: "",
                    animateProgress: false,
                    button3D: viewModel.button3D,
                    symbolBackgroundColor: Color.dynamicIconBackground,
                    symbolColor: Color.dynamicIconForeground
                )
                Image(systemName: "cross.vial")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                    .foregroundColor(.dynamicIconForeground)
                    .offset(y: -1.5)
            }
            .frame(width: 60, height: 60)
        }
    }
}

// MARK: - BatteryAgeView

public struct BatteryAgeView: View {
    @ObservedObject var viewModel: DanaBarViewModel
    @StateObject private var pieSegmentViewModel = PieSegmentViewModel()

    public init(viewModel: DanaBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            var batteryAgeColor: Color {
                if let batteryHours = viewModel.batteryHours {
                    switch batteryHours {
                    case 192...:
                        return Color.dynamicIconForeground.opacity(0.5)
                    case 168 ..< 192:
                        return Color.dynamicIconForeground.opacity(0.5)
                    default:
                        return Color.dynamicIconForeground.opacity(0.5)
                    }
                } else {
                    return .dynamicIconForeground.opacity(0.5)
                }
            }

            let batteryAgeText: String = {
                if let batteryHours = viewModel.batteryHours {
                    let totalMinutes = Int(batteryHours * 60)
                    if totalMinutes < 60 {
                        return "\(totalMinutes)min"
                    } else {
                        let days = totalMinutes / (24 * 60)
                        let hours = (totalMinutes % (24 * 60)) / 60
                        return days > 0 ? "\(days)d\(hours)h" : "\(hours)h"
                    }
                } else {
                    return "--"
                }
            }()

            ZStack {
                FillablePieSegment(
                    pieSegmentViewModel: pieSegmentViewModel,
                    fillFraction: 1.0,
                    color: batteryAgeColor,
                    backgroundColor: .clear,
                    displayText: batteryAgeText,
                    symbolSize: 25,
                    symbol: "battery.50percent",
                    animateProgress: false,
                    button3D: viewModel.button3D,
                    symbolRotation: -90,
                    symbolBackgroundColor: Color.dynamicIconBackground,
                    symbolColor: Color.dynamicIconForeground
                )
                .frame(width: 60, height: 60)

                Image(systemName: "clock.fill")
                    .resizable()
                    .foregroundColor(Color.dynamicIconForeground)
                    .frame(width: 15, height: 15)
                    .offset(x: 13, y: -17)
            }
        }
    }
}

// MARK: - BluetoothConnectionView

public struct BluetoothConnectionView: View {
    @ObservedObject var viewModel: DanaBarViewModel
    @StateObject private var pieSegmentViewModel = PieSegmentViewModel()

    public init(viewModel: DanaBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            let connectionFraction: CGFloat = viewModel.isConnected ? 1.0 : 0.0
            let displayText: String = viewModel.isConnected ? "ON" : "OFF"

            HStack {
                ZStack {
                    FillablePieSegment(
                        pieSegmentViewModel: pieSegmentViewModel,
                        fillFraction: connectionFraction,
                        color: Color.dynamicColorBlue,
                        backgroundColor: .clear,
                        displayText: displayText,
                        symbolSize: 25,
                        symbol: "dot.radiowaves.left.and.right",
                        animateProgress: true,
                        button3D: viewModel.button3D,
                        symbolBackgroundColor: Color.dynamicIconBackground,
                        symbolColor: Color.dynamicIconForeground
                    )
                    .frame(width: 60, height: 60)
                }
                .offset(y: -2)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isConnected)
    }
}
