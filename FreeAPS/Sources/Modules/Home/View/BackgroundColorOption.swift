//
//  BackgroundColorOption.swift
//  FreeAPS
//
//  Created by Richard on 05.11.24.
//
import SwiftUICore

enum BackgroundColorOption: String, CaseIterable, Identifiable, Encodable {
    case deepSkyBlue3
    case darkSlateGray4
    case teal
    case darkGreen
    case black
    case darkGray
    case snow4
    case slateGray4
    case rosyBrown4
    case indianRed4
    case burntOrange
    case autumnLeaf
    case sienna3
    case navajoWhite4
    case goldenRod4

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .deepSkyBlue3:
            return Color(red: 0.00, green: 0.60, blue: 0.80)
        case .darkSlateGray4:
            return Color(red: 0.32, green: 0.55, blue: 0.55)
        case .teal:
            return Color(red: 0.00, green: 0.32, blue: 0.32)
        case .darkGreen:
            return Color(red: 0.10, green: 0.25, blue: 0.15)
        case .black:
            return Color(red: 0.00, green: 0.00, blue: 0.00)
        case .darkGray:
            return Color(red: 0.12, green: 0.14, blue: 0.14)
        case .snow4:
            return Color(red: 0.55, green: 0.55, blue: 0.54)
        case .slateGray4:
            return Color(red: 0.42, green: 0.48, blue: 0.55)
        case .rosyBrown4:
            return Color(red: 0.55, green: 0.41, blue: 0.41)
        case .indianRed4:
            return Color(red: 0.55, green: 0.23, blue: 0.23)
        case .burntOrange:
            return Color(red: 0.45, green: 0.22, blue: 0.12)
        case .autumnLeaf:
            return Color(red: 0.58, green: 0.33, blue: 0.09)
        case .sienna3:
            return Color(red: 0.80, green: 0.41, blue: 0.22)
        case .navajoWhite4:
            return Color(red: 0.55, green: 0.47, blue: 0.39)
        case .goldenRod4:
            return Color(red: 0.55, green: 0.41, blue: 0.08)
        }
    }
}
