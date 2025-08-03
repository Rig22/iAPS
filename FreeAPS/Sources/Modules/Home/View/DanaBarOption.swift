//  DanaBarOption.swift
//  FreeAPS
//
//  Created by Richard on 22.06.25.
//
enum DanaBarOption: String, CaseIterable, Identifiable {
    case standard2 = "Classic"
    case max = "Dana Bar"

    var id: String { rawValue }
    var previewImageName: String {
        switch self {
        case .standard2: return "BarStandardPreview"
        case .max: return "BarMaxPreview"
        }
    }
}
