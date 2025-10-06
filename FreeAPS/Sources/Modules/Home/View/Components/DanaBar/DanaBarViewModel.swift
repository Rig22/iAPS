import Combine
import CoreData
import SwiftUI

public class DanaBarViewModel: ObservableObject {
    // State Properties die von HomeRootView kommen
    @Published var reservoirLevel: Double?
    @Published var insulinHours: Double?
    @Published var cannulaHours: Double?
    @Published var batteryHours: Double?
    @Published var isConnected: Bool = false
    @Published var button3D: Bool = false
    @Published var insulinAgeOption: String = "Drei_Tage"
    @Published var cannulaAgeOption: String = "Drei_Tage"

    // Formatter und Helper
    let reservoirFormatter: NumberFormatter
    let concentration: FetchedResults<InsulinConcentration>

    public init(
        reservoirLevel: Double? = nil,
        insulinHours: Double? = nil,
        cannulaHours: Double? = nil,
        batteryHours: Double? = nil,
        isConnected: Bool = false,
        button3D: Bool = false,
        insulinAgeOption: String = "Drei_Tage",
        cannulaAgeOption: String = "Drei_Tage",
        reservoirFormatter: NumberFormatter,
        concentration: FetchedResults<InsulinConcentration>
    ) {
        self.reservoirLevel = reservoirLevel
        self.insulinHours = insulinHours
        self.cannulaHours = cannulaHours
        self.batteryHours = batteryHours
        self.isConnected = isConnected
        self.button3D = button3D
        self.insulinAgeOption = insulinAgeOption
        self.cannulaAgeOption = cannulaAgeOption
        self.reservoirFormatter = reservoirFormatter
        self.concentration = concentration
    }

    func getInsulinAgeOption() -> InsulinAgeOption? {
        InsulinAgeOption(rawValue: insulinAgeOption)
    }

    func getCannulaAgeOption() -> CannulaAgeOption? {
        CannulaAgeOption(rawValue: cannulaAgeOption)
    }

    // Helper Functions hier hinzufügen:
    public func colorForRemainingHours(_ remainingHours: CGFloat) -> Color {
        switch remainingHours {
        case ..<2: return .dynamicColorRed
        case ..<6: return .dynamicColorYellow
        default: return .dynamicIconForeground
        }
    }

    public func colorForRemainingMinutes(_ remainingMinutes: CGFloat) -> Color {
        switch remainingMinutes {
        case ..<120: return .dynamicColorRed
        case ..<360: return .dynamicColorYellow
        default: return .dynamicIconForeground
        }
    }
}
