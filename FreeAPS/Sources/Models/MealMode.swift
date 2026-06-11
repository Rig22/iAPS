import Foundation

class MealMode: ObservableObject {
    enum Mode {
        case image
        case barcode
        case presets
        case meal
        /// Öffnet die Suche mit erzwungener KI-Textsuche (statt der
        /// konfigurierten Datenbank-Suche) — Einstieg aus dem AI Hub.
        /// Kamera/Barcode bleiben über die Suchleisten-Buttons erreichbar.
        case aiSearch
    }

    var mode: Mode = .meal
}
