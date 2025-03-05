enum SensorAgeDays: String, Codable, CaseIterable {
    case Ein_Tag
    case Zwei_Tage
    case Drei_Tage
    case Vier_Tage
    case Fuenf_Tage
    case Sechs_Tage
    case Sieben_Tage
    case Acht_Tage
    case Neun_Tage
    case Zehn_Tage
    case Elf_Tage
    case Zwoelf_Tage
    case Dreizehn_Tage
    case Vierzehn_Tage
    case Fuenfzehn_Tage

    /// Lokalisierter Anzeigename
    var localizedName: String {
        "\(asInt()) Tage"
    }

    /// Anzahl der Tage als Integer
    func asInt() -> Int {
        switch self {
        case .Ein_Tag: return 1
        case .Zwei_Tage: return 2
        case .Drei_Tage: return 3
        case .Vier_Tage: return 4
        case .Fuenf_Tage: return 5
        case .Sechs_Tage: return 6
        case .Sieben_Tage: return 7
        case .Acht_Tage: return 8
        case .Neun_Tage: return 9
        case .Zehn_Tage: return 10
        case .Elf_Tage: return 11
        case .Zwoelf_Tage: return 12
        case .Dreizehn_Tage: return 13
        case .Vierzehn_Tage: return 14
        case .Fuenfzehn_Tage: return 15
        }
    }

    /// Anzahl der Stunden als Double (optional für Berechnungen)
    var hours: Double {
        Double(asInt()) * 24
    }
}
