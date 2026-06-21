import Foundation

enum AddCarbs {
    enum Config {}

    /// Einmalige Vorbelegung für den manuellen Carb-Screen, gesetzt von einem
    /// anderen Modul (AI Hub Meal Simulator) direkt vor `showModal(.addCarbs)`.
    /// Wird beim ersten Erscheinen konsumiert und genullt.
    struct Prefill {
        let carbs: Decimal
        let fat: Decimal
        let protein: Decimal
        let note: String
    }

    static var pendingPrefill: Prefill?
}

protocol AddCarbsProvider: Provider {
    var suggestion: Suggestion? { get }
}
