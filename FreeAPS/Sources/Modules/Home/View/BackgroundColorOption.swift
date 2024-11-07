// Created by Rig22
// 05.11.2024
import SwiftUICore

enum BackgroundColorOption: String, CaseIterable, Identifiable, Encodable {
    case darkBlue
    case blue
    case teal
    case darkGreen
    case black
    case gray
    case blackBerry
    case red
    case burntOrange
    case purple

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .darkBlue:
            return Color(red: 0.08, green: 0.15, blue: 0.20)
        case .blue:
            return Color(red: 0.10, green: 0.20, blue: 0.50)
        case .teal:
            return Color(red: 0.00, green: 0.36, blue: 0.36)
        case .darkGreen:
            return Color(red: 0.00, green: 0.39, blue: 0.00)
        case .black:
            return Color(red: 0.00, green: 0.00, blue: 0.00)
        case .gray:
            return Color(red: 0.12, green: 0.14, blue: 0.14)
        case .blackBerry:
            return Color(red: 0.23, green: 0.04, blue: 0.14)
        case .red:
            return Color(red: 0.4, green: 0.0, blue: 0.0)
        case .burntOrange:
            return Color(red: 0.45, green: 0.22, blue: 0.12)
        case .purple:
            return Color(red: 0.36, green: 0.20, blue: 0.72)
        }
    }
}
