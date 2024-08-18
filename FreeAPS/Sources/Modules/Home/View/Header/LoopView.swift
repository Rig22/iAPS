import SwiftDate
import SwiftUI
import UIKit

struct LoopView: View {
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

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) private var fontSize

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 54, height: 54)
                Circle()
                    .stroke(lineWidth: 0)
                    .foregroundColor(color)
                    .frame(width: 54, height: 54)

                VStack(spacing: 5) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .offset(y: 0)
                    if closedLoop {
                        if !isLooping, actualSuggestion?.timestamp != nil {
                            if minutesAgo > 1440 {
                                Text("--")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(.leading, 5)
                            } else {
                                let timeString = "\(minutesAgo) " +
                                    NSLocalizedString("min", comment: "Minutes ago since last loop")
                                Text(timeString)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                        }
                    } else if !isLooping {
                        Text("Open")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
                .offset(y: 0) // widget nach oben verschieben

                if isLooping {
                    ProgressView() // Zeigt die Fortschrittsanzeige an, wenn isLooping aktiv ist
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .frame(width: 40, height: 40)
                }
            }
        }
    }

    private var gradientColors: [Color] {
        if isLooping {
            return [.black, .purple]
        } else if closedLoop {
            return [.purple, .black]
        } else {
            return [.red]
        }
    }

    private var minutesAgo: Int {
        let minAgo = Int((timerDate.timeIntervalSince(lastLoopDate) - Config.lag) / 60) + 1
        return minAgo
    }

    private var color: Color {
        guard actualSuggestion?.timestamp != nil else {
            return .white
        }
        guard manualTempBasal == false else {
            return .loopManualTemp
        }
        let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

        if delta <= 8.minutes.timeInterval {
            guard actualSuggestion?.deliverAt != nil else {
                return .loopYellow
            }
            return .green
        } else if delta <= 12.minutes.timeInterval {
            return .loopYellow
        } else {
            return .loopRed
        }
    }

    private var actualSuggestion: Suggestion? {
        if closedLoop, enactedSuggestion?.recieved == true {
            return enactedSuggestion ?? suggestion
        } else {
            return suggestion
        }
    }
}

extension View {
    func animateForever(
        using animation: Animation = Animation.easeInOut(duration: 1),
        autoreverses: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        let repeated = animation.repeatForever(autoreverses: autoreverses)

        return onAppear {
            withAnimation(repeated) {
                action()
            }
        }
    }
}
