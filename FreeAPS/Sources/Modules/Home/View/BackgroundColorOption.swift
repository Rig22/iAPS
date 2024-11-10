// Created by Rig22
// 05.11.2024
import SwiftUICore

enum BackgroundColorOption: String, CaseIterable, Identifiable, Encodable {
    case darkBlue
    case blue
    case teal
    case darkGreen
    case black
    case darkGray
    case blackBerry
    case darkRed
    case burntOrange
    case mustard
    case aubergine

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .darkBlue:
            return Color(red: 0.08, green: 0.15, blue: 0.20)
        case .blue:
            return Color(red: 0.10, green: 0.20, blue: 0.50)
        case .teal:
            return Color(red: 0.00, green: 0.32, blue: 0.32)
        case .darkGreen:
            return Color(red: 0.10, green: 0.25, blue: 0.15)
        case .black:
            return Color(red: 0.00, green: 0.00, blue: 0.00)
        case .darkGray:
            return Color(red: 0.12, green: 0.14, blue: 0.14)
        case .blackBerry:
            return Color(red: 0.23, green: 0.04, blue: 0.14)
        case .darkRed:
            return Color(red: 0.25, green: 0.07, blue: 0.10)
        case .burntOrange:
            return Color(red: 0.45, green: 0.22, blue: 0.12)
        case .mustard:
            return Color(red: 0.28, green: 0.22, blue: 0.10)
        case .aubergine:
            return Color(red: 0.15, green: 0.05, blue: 0.25)
        }
    }
}
