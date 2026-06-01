import SwiftUI

/// A grouped-list row with a colored icon tile, title, value, and optional chevron.
struct AuroraListRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String? = nil
    var showsChevron: Bool = true
    var onTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: {
            if let onTap = onTap {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }
        }, label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(iconColor))

                Text(title)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(AuroraPalette.textPrimary(scheme))

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AuroraPalette.textMuted(scheme))
                        .monospacedDigit()
                }

                if showsChevron, onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AuroraPalette.textFaint(scheme))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        })
            .buttonStyle(.plain)
            .disabled(onTap == nil)
    }
}

/// Grouped section with title + glass card containing rows separated by hairlines.
struct AuroraListSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title.uppercased())
                    .font(.system(size: 12.5, weight: .semibold))
                    .kerning(0.4)
                    .foregroundStyle(AuroraPalette.textMuted(scheme))
                    .padding(.leading, 6)
            }
            VStack(spacing: 0) {
                content()
            }
            .auroraGlass(radius: 22)
        }
    }
}
