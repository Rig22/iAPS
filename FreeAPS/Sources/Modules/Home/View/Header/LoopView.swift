import SwiftDate
import SwiftUI
import UIKit

// Pie Animation

struct PieSliceView: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(startAngle.degrees, endAngle.degrees)
        }
        set {
            startAngle = Angle(degrees: newValue.first)
            endAngle = Angle(degrees: newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(
            center: center,
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

class PieSegmentViewModel: ObservableObject {
    @Published var progress: Double = 0.0

    func updateProgress(to newValue: CGFloat, animate: Bool) {
        if animate {
            withAnimation(.easeInOut(duration: 2.5)) { // Beispiel: Dauer der Animation anpassen
                self.progress = Double(newValue)
            }
        } else {
            progress = Double(newValue)
        }
    }
}

struct FillablePieSegment: View {
    @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

    var fillFraction: CGFloat
    var color: Color
    var backgroundColor: Color
    var displayText: String
    var animateProgress: Bool

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .opacity(0.3)
                    .frame(width: 45, height: 45)

                PieSliceView(
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                )
                .fill(color)
                .frame(width: 45, height: 45)
                .opacity(0.7)
            }

            Text(displayText)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.top, 0)
        }
        .offset(y: 10)
        .onAppear {
            pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
        }
        .onChange(of: fillFraction) { newValue in
            pieSegmentViewModel.updateProgress(to: newValue, animate: true)
        }
    }
}

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

    @StateObject private var pieSegmentViewModel = PieSegmentViewModel()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack {
            ZStack {
                VStack {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)

                    /* if closedLoop {
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
                     }*/
                }
                .offset(y: 0) // widget nach oben verschieben

                if isLooping {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .frame(width: 45, height: 45)
                }

                FillablePieSegment(
                    pieSegmentViewModel: pieSegmentViewModel,
                    fillFraction: min(CGFloat(minutesAgo) / 8.0, 1.0),
                    color: pieColor,
                    backgroundColor: .gray,
                    displayText: "\(minutesAgo) min",
                    animateProgress: true
                )
                Image("Loop")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 67, height: 67)
            }
        }
        .onAppear {
            // Update progress abhängig von "current minutes ago"
            pieSegmentViewModel.updateProgress(to: min(CGFloat(minutesAgo) / 8.0, 1.0), animate: true)
        }
        .onChange(of: minutesAgo) { _ in
            // Rekalkuliert den pie progress "as time passes"
            pieSegmentViewModel.updateProgress(to: min(CGFloat(minutesAgo) / 8.0, 1.0), animate: true)
        }
    }

    private var color: Color {
        guard actualSuggestion?.timestamp != nil else {
            return .white
        }
        guard manualTempBasal == false else {
            return .loopManualTemp
        }
        let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

        if delta <= 5.minutes.timeInterval {
            guard actualSuggestion?.deliverAt != nil else {
                return .loopYellow
            }
            return .green
        } else if delta <= 8.minutes.timeInterval {
            return .loopYellow
        } else {
            return .loopRed
        }
    }

    private var minutesAgo: Int {
        let minAgo = Int((timerDate.timeIntervalSince(lastLoopDate) - Config.lag) / 60) + 1
        return minAgo
    }

    private var pieColor: Color {
        let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

        if delta <= 5.minutes.timeInterval {
            return .green.opacity(0.7) // Grün für 0-8 Minuten
        } else if delta <= 8.minutes.timeInterval {
            return .yellow.opacity(0.7) // Gelb für 8-12 Minuten
        } else {
            return .red.opacity(0.7) // Rot für mehr als 12 Minuten
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
