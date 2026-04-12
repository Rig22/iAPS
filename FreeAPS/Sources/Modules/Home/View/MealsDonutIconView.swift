import SwiftUI

struct MealsDonutIconView: View {
    let carbs: Double
    let fat: Double
    let protein: Double

    private let lineWidth: CGFloat = 4 //Donut Stärke
    private let gap: Double = 15 //Lücke zwischen den Segmenten

    private var total: Double {
        carbs + fat + protein
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - lineWidth / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                segment(center: center, radius: radius, value: carbs, start: 0, color: .orange)
                segment(center: center, radius: radius, value: fat, start: carbs, color: .red)
                segment(center: center, radius: radius, value: protein, start: carbs + fat, color: .yellow)
            }
        }
    }

    private func segment(
        center: CGPoint,
        radius: CGFloat,
        value: Double,
        start: Double,
        color: Color
    ) -> some View {
        guard total > 0 else { return AnyView(EmptyView()) }

        let startAngle = (start / total) * 360
        let endAngle = ((start + value) / total) * 360

        let adjustedStart = startAngle + gap
        let adjustedEnd = endAngle - gap

        return AnyView(
            Path { path in
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(adjustedStart - 90),
                    endAngle: .degrees(adjustedEnd - 90),
                    clockwise: false
                )
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
        )
    }
}
