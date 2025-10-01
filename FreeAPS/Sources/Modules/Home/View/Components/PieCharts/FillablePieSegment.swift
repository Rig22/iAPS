import SwiftUI

public struct FillablePieSegment: View {
    @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

    var fillFraction: CGFloat
    var color: Color
    var backgroundColor: Color
    var displayText: String
    var symbolSize: CGFloat
    var symbol: String
    var animateProgress: Bool
    var button3D: Bool = false // Standardwert setzen
    var symbolRotation: Double = 0
    var symbolBackgroundColor: Color = .clear
    var symbolColor: Color? = nil

    public var body: some View {
        VStack {
            ZStack {
                if button3D {
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .dynamicTopGlow.opacity(0.9),
                                    .dynamicTopGlow.opacity(0.4),
                                    .dynamicBottomShadow.opacity(0.3),
                                    .dynamicBottomShadow
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: .dynamicTopGlow.opacity(0.6), radius: 2, x: -1, y: -1)
                        .shadow(color: .dynamicBottomShadow.opacity(0.8), radius: 2, x: 1, y: 1)
                }

                // Fortschrittsanzeige
                PieSliceView(
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                )
                .fill(color.opacity(0.0))
                .frame(width: 50, height: 50)
                .opacity(0.5)

                // Symbol-Hintergrund
                if symbolBackgroundColor != .clear {
                    Circle()
                        .fill(Color.dynamicIconBackground)
                        .frame(width: 50, height: 50)
                }

                // Symbol
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: symbolSize, height: symbolSize)
                    .foregroundColor(symbolColor ?? .dynamicIconForeground)
                    .rotationEffect(.degrees(symbolRotation))
            }

            // Text
            Text(displayText)
                .font(.system(size: 15))
                .foregroundColor(.dynamicSecondaryText)
        }
        .offset(y: 10)
        .onAppear {
            pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
        }
        .onChange(of: fillFraction) { _, newValue in
            pieSegmentViewModel.updateProgress(to: newValue, animate: true)
        }
    }
}
