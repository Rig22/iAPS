import SwiftUI

/// Solid accent-colored primary action button.
struct AuroraPrimaryButton: View {
    let title: String
    let accent: Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            action()
        }, label: {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent)
                        .shadow(color: accent.opacity(0.35), radius: 12, x: 0, y: 6)
                )
                .scaleEffect(pressed ? 0.97 : 1.0)
        })
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in withAnimation(.easeOut(duration: 0.1)) { pressed = true } }
                    .onEnded { _ in withAnimation(.easeOut(duration: 0.2)) { pressed = false } }
            )
    }
}
