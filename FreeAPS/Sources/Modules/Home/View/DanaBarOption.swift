//
//  DanaBarOption.swift
//  FreeAPS
//
//  Created by Richard on 22.06.25.
//
enum DanaBarOption: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case marquee = "Marquee"
    case max = "Dana Bar"

    var id: String { rawValue }
    var previewImageName: String {
        switch self {
        case .standard: return "BarStandardPreview"
        case .marquee: return "BarMarqueePreview"
        case .max: return "BarMaxPreview"
        }
    }
}
