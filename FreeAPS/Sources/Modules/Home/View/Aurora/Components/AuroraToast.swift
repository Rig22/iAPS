import SwiftUI

/// Transient glass pill shown near the top of the screen.
/// Caller manages the binding; the toast auto-dismisses after ~1.9s.
struct AuroraToast: View {
    @Binding var message: String?

    var body: some View {
        VStack {
            if let msg = message {
                Text(msg)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .auroraGlass(radius: 20)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                            withAnimation(.easeOut(duration: 0.25)) { message = nil }
                        }
                    }
            }
            Spacer()
        }
        .animation(.easeOut(duration: 0.25), value: message)
        .allowsHitTesting(false)
    }
}
