import SwiftDate
import SwiftUI
import UIKit

// Pie Animation

var backgroundColor: Color = .clear

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
    var backgroundColor: Color

    @StateObject private var pieSegmentViewModel = PieSegmentViewModel()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack {
            var textColor: Color { // Neue Berechnung für Textfarbe
                guard actualSuggestion?.timestamp != nil else {
                    return .dynamicSecondaryText
                }
                guard manualTempBasal == false else {
                    return .loopManualTemp
                }
                let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

                if delta <= 6.minutes.timeInterval {
                    guard actualSuggestion?.deliverAt != nil else {
                        return .dynamicSecondaryText
                    }
                    return .dynamicPrimaryText
                } else if delta <= 9.minutes.timeInterval {
                    return .dynamicColorYellow
                } else {
                    return .dynamicColorRed
                }
            }

            VStack(spacing: 0) {
                ZStack {
                    FillablePieSegment(
                        pieSegmentViewModel: pieSegmentViewModel,
                        fillFraction: min(CGFloat(minutesAgo) / 5.0, 1.0),
                        color: pieColor,
                        backgroundColor: .clear,
                        displayText: "\(minutesAgo)min",
                        symbolSize: 25,
                        symbol: "arrow.trianglehead.2.clockwise.rotate.90",
                        animateProgress: true,
                        button3D: false,
                        symbolBackgroundColor: backgroundColor,
                        symbolColor: color
                    )
                    .offset(y: 1.5)

                    if isLooping {
                        Circle()
                            .fill(Color.dynamicBackground)
                            .frame(width: 40, height: 40)
                    }

                    if isLooping {
                        RotatingArrow(color: color)
                    }
                }
            }
        }
        .onAppear {
            pieSegmentViewModel.updateProgress(to: min(CGFloat(minutesAgo) / 5.0, 1.0), animate: true)
        }
        .onChange(of: minutesAgo) {
            pieSegmentViewModel.updateProgress(to: min(CGFloat(minutesAgo) / 5.0, 1.0), animate: true)
        }
    }

    struct RotatingArrow: View {
        var color: Color
        @State private var rotation: Double = 0

        var body: some View {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 25)
                .foregroundColor(color)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 1.0)
                            .repeatForever(autoreverses: false)
                    ) {
                        rotation = 360
                    }
                }
        }
    }

    private var color: Color {
        guard actualSuggestion?.timestamp != nil else {
            return .dynamicIconForeground
        }
        guard manualTempBasal == false else {
            return .loopManualTemp
        }
        let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

        if delta <= 6.minutes.timeInterval {
            guard actualSuggestion?.deliverAt != nil else {
                return .dynamicIconForeground
            }
            return .dynamicIconForeground
        } else if delta <= 9.minutes.timeInterval {
            return .dynamicColorOrange
        } else {
            return .dynamicColorRed
        }
    }

    private var minutesAgo: Int {
        let elapsedSeconds = timerDate.timeIntervalSince(lastLoopDate) - Config.lag
        return Int(elapsedSeconds / 60) // Wechselt bei exakt 60 Sekunden auf 1 Minute
    }

    private var pieColor: Color {
        let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

        if delta < 1.minutes.timeInterval {
            return .secondary.opacity(0.5) // unter 1 Minute
        } else if delta <= 6.minutes.timeInterval {
            return .secondary.opacity(0.5) // grün für 1-5 Minuten
        } else if delta < 10.minutes.timeInterval {
            return .secondary.opacity(0.5) // Gelb für 6-9 Minuten
        } else {
            return .secondary.opacity(0.5) // Rot ab Minute 10
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
