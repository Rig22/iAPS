import SwiftUI

class PieSegmentViewModel: ObservableObject {
    @Published var progress: Double = 0.0

    func updateProgress(to newValue: CGFloat, animate: Bool) {
        if animate {
            withAnimation(.easeInOut(duration: 2.5)) {
                self.progress = Double(newValue)
            }
        } else {
            progress = Double(newValue)
        }
    }
}
