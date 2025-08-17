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
    case atriumview2 = "NewMoon"

    var id: String { rawValue }

    var highlightColor: Color {
        switch self {
        case .atriumview: return Color.gray
        case .atriumview1: return Color.white
        case .atriumview2: return Color.black
        }
    }
}
