import SwiftUI

public struct TimeEllipse: View {
    var button3D: Bool = false
    var minHeight: CGFloat = 25 // Standard-Höhe, aber anpassbar
    var cornerRadius: CGFloat = 15
    var horizontalPadding: CGFloat = 10 // Standard-Padding für Breite
    var minWidth: CGFloat = 80 // Mindestbreite

    public init(
        button3D: Bool = false,
        minHeight: CGFloat = 25,
        cornerRadius: CGFloat = 15,
        horizontalPadding: CGFloat = 10,
        minWidth: CGFloat = 80
    ) {
        self.button3D = button3D
        self.minHeight = minHeight
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.minWidth = minWidth
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                let ellipseWidth = max(geometry.size.width + horizontalPadding, minWidth)
                let ellipseHeight = max(geometry.size.height, minHeight)

                if button3D {
                    // Immer gefüllte Hintergrundfarbe
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.dynamicIconBackground)
                        .frame(width: ellipseWidth, height: ellipseHeight)

                    // 3D-Rand-Glow
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .dynamicTopGlow.opacity(0.5),
                                    .dynamicTopGlow.opacity(0.3),
                                    Color.clear,
                                    .dynamicBottomShadow.opacity(0.3),
                                    .dynamicBottomShadow
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: ellipseWidth, height: ellipseHeight)
                        .shadow(color: .dynamicTopGlow.opacity(0.3), radius: 1, x: -1, y: -1)
                        .shadow(color: .dynamicBottomShadow.opacity(0.6), radius: 1, x: 1, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.dynamicIconBackground)
                        .frame(width: ellipseWidth, height: ellipseHeight)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.dynamicIconForeground, lineWidth: 0)
                        .frame(width: ellipseWidth, height: ellipseHeight)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(minHeight: minHeight)
    }
}

// Preview für bessere Entwicklung
struct TimeEllipse_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Kleine Version (wie in HomeRootView)
            TimeEllipse(button3D: false, minHeight: 25)
                .overlay(
                    Text("Klein - 25pt")
                        .foregroundColor(.dynamicIconForeground)
                )
                .frame(width: 100)

            // Mittlere Version
            TimeEllipse(button3D: true, minHeight: 35)
                .overlay(
                    Text("Mittel - 35pt")
                        .foregroundColor(.dynamicIconForeground)
                )
                .frame(width: 120)

            // Große Version (für PumpView)
            TimeEllipse(button3D: true, minHeight: 45, cornerRadius: 20)
                .overlay(
                    Text("Groß - 45pt")
                        .foregroundColor(.dynamicIconForeground)
                )
                .frame(width: 150)
        }
        .padding()
    }
}
