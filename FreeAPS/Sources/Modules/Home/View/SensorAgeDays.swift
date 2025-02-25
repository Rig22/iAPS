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

    var displayName: String {
        switch self {
        case .Ein_Tag: return "24"
        case .Zwei_Tage: return "48"
        case .Drei_Tage: return "72"
        case .Vier_Tage: return "96"
        case .Fuenf_Tage: return "120"
        case .Sechs_Tage: return "144"
        case .Sieben_Tage: return "168"
        case .Acht_Tage: return "192"
        case .Neun_Tage: return "216"
        case .Zehn_Tage: return "240"
        case .Elf_Tage: return "264"
        case .Zwoelf_Tage: return "288"
        case .Dreizehn_Tage: return "312"
        case .Vierzehn_Tage: return "336"
        case .Fuenfzehn_Tage: return "360"
        }
    }

    var sensorAgeDays: Double {
        switch self {
        case .Ein_Tag: return 24
        case .Zwei_Tage: return 48
        case .Drei_Tage: return 72
        case .Vier_Tage: return 96
        case .Fuenf_Tage: return 120
        case .Sechs_Tage: return 144
        case .Sieben_Tage: return 168
        case .Acht_Tage: return 192
        case .Neun_Tage: return 216
        case .Zehn_Tage: return 240
        case .Elf_Tage: return 264
        case .Zwoelf_Tage: return 288
        case .Dreizehn_Tage: return 312
        case .Vierzehn_Tage: return 336
        case .Fuenfzehn_Tage: return 360
        }
    }

    // Neue Methode asInt
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
}
