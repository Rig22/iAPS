import SwiftUI

struct AuroraSegmentedControl<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T

    @Environment(\.colorScheme) private var scheme

    @Namespace private var thumbNS

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { opt in
                ZStack {
                    if selection == opt.value {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(thumbFill)
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                            .matchedGeometryEffect(id: "thumb", in: thumbNS)
                    }
                    Text(opt.label)
                        .font(.system(size: 13, weight: selection == opt.value ? .bold : .medium))
                        .foregroundStyle(
                            selection == opt.value
                                ? AuroraPalette.textPrimary(scheme)
                                : AuroraPalette.textMuted(scheme)
                        )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selection = opt.value
                    }
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
        )
    }

    private var thumbFill: Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.white
    }
}
