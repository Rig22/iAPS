//
//  DanaBarOption.swift
//  FreeAPS
//
//  Created by Richard on 22.06.25.
//
enum DanaBarOption: String, CaseIterable, Identifiable {
    case max = "Dana Bar"
    case min = "Min"
    case marquee = "Marquee"
    case simple = "Simple"

    var id: String { rawValue }
    var previewImageName: String {
        switch self {
        case .max: return "BarMaxPreview"
        case .min: return "BarMinPreview"
        case .marquee: return "BarMarqueePreview"
        case .simple: return "BarSimplePreview"
        }
    }
}
