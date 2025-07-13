enum PumpIconOption: String, Codable, CaseIterable {
    case danaI = "DanaI"
    case danaRS = "DanaRS"
    case medtronic = "Medtronic"
    case pod = "OmniPod"
    case nano200 = "Nano200"
    case nano300 = "Nano300"

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
