
import SwiftDate
import SwiftUI
import UIKit

struct LoopView2: View {
    private enum Config {
        static let lag: TimeInterval = 30
    }

    @Binding var suggestion: Suggestion?
    @Binding var enactedSuggestion: Suggestion?
    @Binding var closedLoop: Bool
    @Binding var timerDate: Date
    @Binding var isLooping: Bool
    @Binding var lastLoopDate: Date
    @Binding var manualTempBasal: Bool
    @State private var scale: CGFloat = 1.0

    @Binding var button3DBackground: Bool

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private let rect = CGRect(x: 0, y: 0, width: 46, height: 46)

    var body: some View {
        VStack(alignment: .center) {
            ZStack {
                if isLooping {
                    CircleProgress(button3DBackground: button3DBackground)
                } else {
                    Circle()
                        .strokeBorder(color, lineWidth: 6)
                        .frame(width: rect.width, height: rect.height, alignment: .center)
                        .scaleEffect(1)
                        .mask(mask(in: rect).fill(style: FillStyle(eoFill: true)))
                }
            }
            if isLooping {
                /* Text("looping").font(.caption2) */
                Text(timeString).font(.system(size: 14))
                    .foregroundColor(.white)
            } else if manualTempBasal {
                Text("Manual").font(.system(size: 14))
            } else if actualSuggestion?.timestamp != nil {
                Text(timeString).font(.system(size: 14))
                    .foregroundColor(.white)
            } else {
                Text("--").font(.caption2).foregroundColor(.white)
            }
        }
    }

    private var timeString: String {
        let minAgo = Int((timerDate.timeIntervalSince(lastLoopDate) - Config.lag) / 60) + 1
        if minAgo > 1440 {
            return "--"
        }
        return "\(minAgo) " + NSLocalizedString("min", comment: "Minutes ago since last loop")
    }

    private var color: Color {
        guard actualSuggestion?.timestamp != nil else {
            return .loopGray
        }
        guard manualTempBasal == false else {
            return .loopManualTemp
        }
        let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

        if delta <= 5.minutes.timeInterval {
            guard actualSuggestion?.deliverAt != nil else {
                return .loopYellow.opacity(0.8)
            }
            // Farbe des Rings ohne isLooping
            return button3DBackground ? .black.opacity(0.3) : .black.opacity(0.1)
        } else if delta <= 10.minutes.timeInterval {
            return .loopYellow.opacity(0.8)
        } else {
            return .loopRed.opacity(0.8)
        }
    }

    func mask(in rect: CGRect) -> Path {
        var path = Rectangle().path(in: rect)
        if !closedLoop || manualTempBasal {
            path.addPath(Rectangle().path(in: CGRect(x: rect.minX, y: rect.midY - 5, width: rect.width, height: 10)))
        }
        return path
    }

    private var actualSuggestion: Suggestion? {
        if closedLoop, enactedSuggestion?.recieved == true {
            return enactedSuggestion ?? suggestion
        } else {
            return suggestion
        }
    }
}

struct CircleProgress: View {
    @State private var rotationAngle = 0.0
    @State private var pulse = false

    let button3DBackground: Bool // <- Übergabe

    private let rect = CGRect(x: 0, y: 0, width: 45, height: 45)

    private var backgroundGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(
                colors: [
                    Color(red: 81 / 255, green: 81 / 255, blue: 81 / 255, opacity: 0.5),
                    Color(red: 255 / 255, green: 255 / 255, blue: 255 / 255, opacity: 0.5)
                ]
            ),
            center: .center,
            startAngle: .degrees(rotationAngle),
            endAngle: .degrees(rotationAngle + 360)
        )
    }

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 1)
                .stroke(backgroundGradient, style: StrokeStyle(lineWidth: pulse ? 8 : 6))
                .scaleEffect(pulse ? 0.95 : 1)
                .animation(
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: pulse
                )
                .onReceive(timer) { _ in
                    rotationAngle = (rotationAngle + 24).truncatingRemainder(dividingBy: 360)
                }
                .onAppear {
                    self.pulse = true
                }
        }
        .frame(width: rect.width, height: rect.height, alignment: .center)
    }
}

struct CircleProgress_Previews: PreviewProvider {
    static var previews: some View {
        CircleProgress(button3DBackground: false)
    }
}
