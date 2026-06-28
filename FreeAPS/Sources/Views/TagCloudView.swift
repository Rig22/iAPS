import Combine
import Foundation
import SwiftUI
import Swinject

struct TagCloudView: View {
    /// Visual treatment of the chips.
    /// - `compact`: the legacy iAPS look (small monospaced text, thin border) used in the
    ///   non-Aurora home popup.
    /// - `prominent`: Trio's Loop status look (larger system semibold text, 2pt border,
    ///   stronger fill) used in the Aurora Loop status sheet.
    enum Style {
        case compact
        case prominent
    }

    var tags: [String]
    var style: Style = .compact

    @Environment(\.colorScheme) private var colorScheme

    // Height-based variant: reports a definite height to the parent so the cloud also
    // lays out correctly inside a ScrollView/List (e.g. the Aurora Loop status sheet),
    // not only inside a tightly-sized overlay.
    @State private var totalHeight = CGFloat.zero
    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(self.tags, id: \.self) { tag in
                self.item(for: tag)
                    .padding([.horizontal, .vertical], 2)
                    .alignmentGuide(.leading, computeValue: { d in
                        if abs(width - d.width) > g.size.width
                        {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if tag == self.tags.last! {
                            width = 0 // last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if tag == self.tags.last! {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }.background(viewHeightReader($totalHeight))
    }

    private func item(for textTag: String) -> some View {
        var colorOfTag: Color {
            switch textTag {
            case textTag where textTag.contains("SMB Delivery Ratio:"):
                return .uam
            case textTag where textTag.contains("Bolus"),
                 textTag where textTag.contains("Insulin 24h:"):
                return .purple
            case textTag where textTag.contains("tdd_factor"),
                 textTag where textTag.contains("Sigmoid function"),
                 textTag where textTag.contains("Logarithmic function"),
                 textTag where textTag.contains("AF:"),
                 textTag where textTag.contains("Autosens/Dynamic Limit:"),
                 textTag where textTag.contains("Dynamic ISF/CR"),
                 textTag where textTag.contains("Dynamic Ratio"),
                 textTag where textTag.contains("Auto ISF"):
                return .purple
            case textTag where textTag.contains("Middleware:"):
                return .red
            default:
                return .insulin
            }
        }

        let isProminent = style == .prominent
        let tagFont: Font = isProminent
            ? .subheadline.weight(.semibold)
            : .system(size: 11, weight: .medium, design: .monospaced)
        let fillOpacity = isProminent ? (colorScheme == .dark ? 0.15 : 0.25) : 0.15
        let strokeOpacity = isProminent ? 0.4 : 0.3
        let strokeWidth: CGFloat = isProminent ? 2 : 1

        return Text(textTag)
            .padding(.vertical, isProminent ? 6 : 4)
            .padding(.horizontal, isProminent ? 11 : 8)
            .font(tagFont)
            .background(
                Capsule()
                    .fill(colorOfTag.opacity(fillOpacity))
            )
            .foregroundColor(colorOfTag)
            .overlay(
                Capsule()
                    .stroke(colorOfTag.opacity(strokeOpacity), lineWidth: strokeWidth)
            )
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

struct TestTagCloudView: View {
    var body: some View {
        VStack {
            Text("Header").font(.largeTitle)
            TagCloudView(tags: ["Ninetendo", "XBox", "PlayStation", "PlayStation 2", "PlayStation 3", "PlayStation 4"])
            Text("Some other text")
            Divider()
            Text("Some other cloud")
            TagCloudView(tags: ["Apple", "Google", "Amazon", "Microsoft", "Oracle", "Facebook"])
        }
    }
}
