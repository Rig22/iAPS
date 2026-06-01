import SwiftUI

enum AuroraPalette {
    // MARK: - Status (glucose-driven accent)

    enum Status {
        static let lowMain = Color(red: 255 / 255, green: 77 / 255, blue: 109 / 255) // #FF4D6D
        static let inMain = Color(red: 40 / 255, green: 199 / 255, blue: 111 / 255) // #28C76F
        static let highMain = Color(red: 255 / 255, green: 176 / 255, blue: 32 / 255) // #FFB020

        static let lowGlow = lowMain.opacity(0.55)
        static let inGlow = inMain.opacity(0.50)
        static let highGlow = highMain.opacity(0.52)

        static let lowSoft = lowMain.opacity(0.16)
        static let inSoft = inMain.opacity(0.15)
        static let highSoft = highMain.opacity(0.16)
    }

    // MARK: - Category accents (dark/light pairs)

    static func drop(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 90 / 255, green: 200 / 255, blue: 250 / 255) // #5AC8FA
            : Color(red: 10 / 255, green: 132 / 255, blue: 199 / 255) // #0A84C7
    }

    static func carbs(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 255 / 255, green: 159 / 255, blue: 64 / 255) // #FF9F40
            : Color(red: 232 / 255, green: 130 / 255, blue: 26 / 255) // #E8821A
    }

    static let pump = Color(red: 155 / 255, green: 120 / 255, blue: 255 / 255) // #9B78FF
    static let sensor = Color(red: 90 / 255, green: 200 / 255, blue: 250 / 255) // #5AC8FA

    // MARK: - Surfaces

    /// Screen background. Light = vertical gradient, dark = near-black solid.
    static func screenBackground(_ scheme: ColorScheme) -> AnyShapeStyle {
        if scheme == .dark {
            return AnyShapeStyle(Color(red: 6 / 255, green: 7 / 255, blue: 11 / 255)) // #06070b
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 238 / 255, green: 242 / 255, blue: 248 / 255), // #eef2f8
                        Color(red: 230 / 255, green: 236 / 255, blue: 245 / 255) // #e6ecf5
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Text

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(red: 22 / 255, green: 24 / 255, blue: 29 / 255) // #16181d
    }

    static func textMuted(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.55)
            : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.55)
    }

    static func textFaint(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.4)
            : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.5)
    }

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.09)
            : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.1)
    }

    // MARK: - Aurora background glows

    enum Glow {
        static func green(_ scheme: ColorScheme) -> Color {
            Color(red: 40 / 255, green: 199 / 255, blue: 111 / 255)
                .opacity(scheme == .dark ? 0.30 : 0.22)
        }

        static func blue(_ scheme: ColorScheme) -> Color {
            Color(red: 64 / 255, green: 156 / 255, blue: 255 / 255)
                .opacity(scheme == .dark ? 0.22 : 0.16)
        }

        static func violet(_ scheme: ColorScheme) -> Color {
            Color(red: 155 / 255, green: 120 / 255, blue: 255 / 255)
                .opacity(scheme == .dark ? 0.16 : 0.14)
        }
    }
}
