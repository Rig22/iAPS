import SwiftUI

public struct BolusProgressViewStyle: ProgressViewStyle {
    @Environment(\.colorScheme) var colorScheme

    public func makeBody(configuration: Configuration) -> some View {
        let progress = CGFloat(configuration.fractionCompleted ?? 0)

        ZStack {
            GeometryReader { geometry in
                let frame = geometry.frame(in: .local)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3)) // Hintergrund
                    .frame(width: frame.width, height: 6)

                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: frame.width * progress, height: 6) // Fortschritt
            }
            .frame(width: 370, height: 6) // Gesamtgröße des Fortschrittsbalkens
        }
    }
}
