//
//  LightGlowOverlaySelector.swift
//  FreeAPS
//
//  Created by Richard on 29.03.25.
//
import SwiftUICore

enum LightGlowOverlaySelector: String, CaseIterable, Identifiable {
    case atriumview = "Moonlight"
    case atriumview1 = "FullMoon"
    case atriumview2 = "MiddaySun"
    case atriumview3 = "EveningSun"
    case atriumview4 = "RedSun"

    var id: String { rawValue }

    var highlightColor: Color {
        switch self {
        case .atriumview: return Color.white.opacity(0.9)
        case .atriumview1: return Color.gray.opacity(0.9)
        case .atriumview2: return Color.yellow.opacity(0.9)
        case .atriumview3: return Color.orange.opacity(0.9)
        case .atriumview4: return Color.red.opacity(0.9)
        }
    }
}
