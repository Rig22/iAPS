//
//  DanaIconOption.swift
//  FreeAPS
//
//  Created by Richard on 28.11.24.
//
enum DanaIconOption: String, Codable, CaseIterable {
    case danaI = "Dana_i"
    case danaRS = "Dana_rs"

    var displayName: String {
        switch self {
        case .danaI:
            return "Dana i"
        case .danaRS:
            return "Dana RS"
        }
    }
}
