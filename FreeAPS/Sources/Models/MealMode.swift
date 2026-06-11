import Foundation

class MealMode: ObservableObject {
    enum Mode: Equatable, Hashable {
        case image
        case barcode
        case presets
        case meal
        /// Öffnet die Suche mit erzwungener KI-Textsuche (statt der
        /// konfigurierten Datenbank-Suche) — Einstieg aus dem AI Hub.
        /// Eine mitgegebene Query wird sofort gesucht.
        case aiSearch(query: String?)
    }

    var mode: Mode = .meal
}
