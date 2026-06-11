import Foundation

enum AIHub {
    /// Features surfaced on the hub landing page.
    ///
    /// `foodSearch` ist kein eigener Hub-Screen, sondern springt in den
    /// bestehenden KI-Teil von AddCarbs (mode: .image) — kein Nachbau nötig.
    enum Feature: String, CaseIterable, Identifiable {
        case chat
        case therapyInsights
        case recap
        case presetDesigner
        case foodSearch

        var id: String { rawValue }
    }
}
