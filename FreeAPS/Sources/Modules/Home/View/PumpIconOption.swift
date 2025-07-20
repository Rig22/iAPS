enum PumpIconOption: String, Codable, CaseIterable {
    case danaI
    case danaRS
    case medtronic
    case pod
    case nano200
    case nano300

    var displayName: String {
        switch self {
        case .danaI:
            return "Dana i"
        case .danaRS:
            return "Dana RS"
        case .medtronic:
            return "Medtronic"
        case .pod:
            return "OmniPod"
        case .nano200:
            return "Nano 200"
        case .nano300:
            return "Nano 300"
        }
    }
}
