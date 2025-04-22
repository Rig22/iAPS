//
//  DanaBarOption.swift
//  FreeAPS
//
//  Created by Richard on 17.04.25.
//
enum DanaBarOption: String, CaseIterable, Identifiable {
    case max = "DanaBar Max"
    case icon = "DanaBar Icon"
    case min = "DanaBar Min"

    var id: String { rawValue }
    var previewImageName: String {
        switch self {
        case .max: return "DanaBarMaxPreview"
        case .icon: return "DanaBarIconPreview"
        case .min: return "DanaBarMinPreview"
        }
    }
}
