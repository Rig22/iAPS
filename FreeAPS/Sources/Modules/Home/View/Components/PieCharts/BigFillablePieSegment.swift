import SwiftUI

struct BigFillablePieSegment: View {
    @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

    var fillFraction: CGFloat
    var backgroundColor: Color?
    var color: Color
    var animateProgress: Bool
    var button3D: Bool

    var body: some View {
        ZStack {
            if button3D {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .dynamicTopGlow.opacity(0.9),
                                .dynamicTopGlow.opacity(0.6),
                                .clear,
                                .dynamicBottomShadow.opacity(0.3),
                                .dynamicBottomShadow
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: .dynamicTopGlow.opacity(0.6), radius: 2, x: -1, y: -1)
                    .shadow(color: .dynamicBottomShadow.opacity(0.8), radius: 2, x: 1, y: 1)
            }

            // Fortschrittsanzeige
            PieSliceView(
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
            )
            .fill(color)
            .frame(width: 120, height: 120)
            .opacity(1.0)
        }
        .onAppear {
            pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
        }
        .onChange(of: fillFraction) { _, newValue in
            pieSegmentViewModel.updateProgress(to: newValue, animate: true)
        }
    }
}
