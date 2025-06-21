//
//  DanaIconOption.swift
//  FreeAPS
//
//  Created by Richard on 28.11.24.
//
enum PumpIconOption: String, Codable, CaseIterable {
    case danaI = "Dana_i"
    case danaRS = "Dana_rs"
    case medtronic = "Medtronic"
    case pod = "OmniPod"
    case nano = "TouchCare_Nano"

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
        case .nano:
            return "TouchCare Nano"
        }
    }
}
