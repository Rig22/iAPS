//
//  IconColorOption.swift
//  FreeAPS
//
//  Created by Richard on 02.07.25.
//
import SwiftUICore

enum IconColorOption: String, CaseIterable, Identifiable, Encodable {
    case purple
    case pink
    case blue
    case clear

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .purple:
            return Color(red: 0.43, green: 0.38, blue: 0.91)
        case .pink:
            return Color(red: 0.70, green: 0.38, blue: 0.92)
        case .blue:
            return Color(red: 0.23, green: 0.51, blue: 0.97)
        case .clear:
            return Color.clear
        }
    }
}
