import Combine
import SwiftUI

struct RoundedBackground: ViewModifier {
    private let color: Color

    init(color: Color = Color("CapsuleColor")) {
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                Rectangle()
                    // RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill()
                    .foregroundColor(color)
            )
    }
}

struct BoolTag: ViewModifier {
    let bool: Bool
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 4).padding(.horizontal, 6)
            .background((bool ? Color.green : Color.red).opacity(colorScheme == .light ? 0.8 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6)).padding(.vertical, 3).padding(.trailing, 3)
    }
}

struct CompactSectionSpacing: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listSectionSpacing(.compact)
    }
}

struct CarveOrDrop: ViewModifier {
    let carve: Bool
    func body(content: Content) -> some View {
        if carve {
            return content
                .foregroundStyle(.shadow(.inner(color: .black, radius: 0.01, y: 1)))
        } else {
            return content
                .foregroundStyle(.shadow(.drop(color: .black, radius: 0.02, y: 1)))
        }
    }
}

struct ScrollTargetLayoutModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            return content
                .scrollTargetLayout()
        } else {
            return content }
    }
}

struct ScrollPositionModifier: ViewModifier {
    @Binding var id: Int?
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            return content
                .scrollPosition(id: $id)
        } else {
            return content }
    }
}

struct AddShadow: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.white
                    .opacity(
                        colorScheme == .dark ? IAPSconfig.shadowOpacity : IAPSconfig.shadowOpacity / IAPSconfig
                            .shadowFraction
                    ),
                radius: colorScheme == .dark ? 3 : 2.5
            )
    }
}

struct RaisedRectangle: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Rectangle().fill(colorScheme == .dark ? .white : .white)
            .frame(height: 1)
            .addShadows()
    }
}

struct TestTube: View {
    let opacity: CGFloat
    let amount: CGFloat
    let colourOfSubstance: Color
    let materialOpacity: CGFloat
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        UnevenRoundedRectangle.testTube
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        Gradient.Stop(color: .white.opacity(opacity), location: amount),
                        Gradient.Stop(color: colourOfSubstance, location: amount)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                FrostedGlass(opacity: materialOpacity)
            }
            .shadow(
                color: Color.white
                    .opacity(
                        colorScheme == .dark ? IAPSconfig.glassShadowOpacity : IAPSconfig.glassShadowOpacity / IAPSconfig
                            .shadowFraction
                    ),
                radius: colorScheme == .dark ? 2.2 : 3
            )
    }
}

struct FrostedGlass: View {
    let opacity: CGFloat
    var body: some View {
        UnevenRoundedRectangle.testTube
            .fill(.ultraThinMaterial.opacity(opacity))
    }
}

struct NonStandardInsulin: View {
    let concentration: Double
    let pod: Bool

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(.red)
                .frame(width: 33, height: 15)
                .overlay {
                    Text("U" + (formatter.string(from: concentration * 100 as NSNumber) ?? ""))
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                }
        }
        .offset(x: pod ? -15 : -5, y: pod ? -24 : 7)
    }
}

struct TooOldValue: View {
    var body: some View {
        ZStack {
            Image(systemName: "circle.fill")
                .resizable()
                .frame(maxHeight: 20)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(.warning).opacity(0.5))
                .offset(x: 5, y: -13)
                .overlay {
                    Text("Old").font(.caption)
                }
        }
    }
}

// Atrium Lights START

extension Color {
    static let NorthernLights = Color(red: 0.50, green: 1.00, blue: 0.00)
}

// Atrium Lights ENDE

extension Color {
    static let rig22Background = Color(red: 0.10, green: 0.10, blue: 0.10)
}

extension Color {
    static let rig22BGGlucoseWheel = Color(red: 0.17, green: 0.21, blue: 0.24)
}

extension Color {
    static let iconColor = (red: 0.49, green: 0.55, blue: 0.96, alpha: 1.00)
}

extension Color {
    static let connectionStatusOff = Color(red: 1.00, green: 0.00, blue: 0.00)
}

extension Color {
    static let connectionStatusConnected = Color(red: 0.00, green: 1.00, blue: 0.00)
}

struct ColouredRoundedBackground: View {
    var body: some View {
        Rectangle() // Oder RoundedRectangle für gerundete Ecken
            .fill(Color.rig22Background)
    }
}

/* struct ColouredRoundedBackground: View {
  @Environment(\.colorScheme) var colorScheme
  var body: some View {
      Rectangle()
          .fill(
              colorScheme == .dark ? IAPSconfig.previewBackgroundDark :
                  IAPSconfig.previewBackgroundLight
          )
  }
 } */

struct addColouredBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.rig22Background)
        // .shadow(color: Color.black.opacity(0.5), radius: 10, x: 5, y: 5) // Kräftigerer Schatten
    }
}

/* struct ColouredBackground: View {
     var body: some View {
         RoundedRectangle(cornerRadius: 10)
             .fill(Color.rig22Background)
             // .fill(Color.darkGray.opacity(1.0))
             .shadow(color: Color.black.opacity(0.3), radius: 5, x: 5, y: 5)
             .shadow(color: Color.black.opacity(0.3), radius: 10, x: 3, y: 3)
     }
 } */

struct ColouredBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.3))
    }
}

/* struct ColouredBackground: View {
  @Environment(\.colorScheme) var colorScheme
  var body: some View {
      Rectangle()
          .fill(
              colorScheme == .dark ? IAPSconfig.chartBackgroundDark :
                  IAPSconfig.chartBackgroundLight
          )
  }
 } */

struct ColouredBackground2: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.clear)
    }
}

struct LoopEllipse: View {
    @Environment(\.colorScheme) var colorScheme
    let stroke: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .stroke(stroke, lineWidth: colorScheme == .light ? 2 : 1)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.rig22Background)
            )
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct HeaderBackground: View {
    var body: some View {
        Rectangle()
            .fill(Color.rig22Background)
    }
}

/* struct HeaderBackground: View {
  @Environment(\.colorScheme) var colorScheme
  var body: some View {
      Rectangle()
          .fill(
              colorScheme == .light ? IAPSconfig.headerBackgroundLight : IAPSconfig.headerBackgroundDark
          )
  }
 } */

struct ClockOffset: View {
    let mdtPump: Bool
    var body: some View {
        ZStack {
            Image(systemName: "clock.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 20)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(.warning))
                .offset(x: 10, y: !mdtPump ? -20 : -13)
        }
    }
}

struct ChartBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color.rig22Background
            )
    }
}

private let navigationCache = LRUCache<Screen.ID, AnyView>(capacity: 10)

struct NavigationLazyView: View {
    let build: () -> AnyView
    let screen: Screen

    init(_ build: @autoclosure @escaping () -> AnyView, screen: Screen) {
        self.build = build
        self.screen = screen
    }

    var body: AnyView {
        if navigationCache[screen.id] == nil {
            navigationCache[screen.id] = build()
        }
        return navigationCache[screen.id]!
            .onDisappear {
                navigationCache[screen.id] = nil
            }.asAny()
    }
}

struct Link<T>: ViewModifier where T: View {
    private let destination: () -> T
    let screen: Screen

    init(destination: @autoclosure @escaping () -> T, screen: Screen) {
        self.destination = destination
        self.screen = screen
    }

    func body(content: Content) -> some View {
        NavigationLink(destination: NavigationLazyView(destination().asAny(), screen: screen)) {
            content
        }
    }
}

struct ClearButton: ViewModifier {
    @Binding var text: String
    func body(content: Content) -> some View {
        HStack {
            content
            if !text.isEmpty {
                Button { self.text = "" }
                label: {
                    Image(systemName: "delete.left")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

extension View {
    func roundedBackground() -> some View {
        modifier(RoundedBackground())
    }

    func carvingOrRelief(carve: Bool) -> some View {
        modifier(CarveOrDrop(carve: carve))
    }

    func addShadows() -> some View {
        modifier(AddShadow())
    }

    func addBackground() -> some View {
        ColouredRoundedBackground()
    }

    func boolTag(_ bool: Bool) -> some View {
        modifier(BoolTag(bool: bool))
    }

    /*  func addColouredBackground() -> some View {
         ColouredBackground()
     }*/

    func addHeaderBackground() -> some View {
        HeaderBackground()
    }

    func chartBackground() -> some View {
        modifier(ChartBackground())
    }

    func frostedGlassLayer(_ opacity: CGFloat) -> some View {
        FrostedGlass(opacity: opacity)
    }

    func navigationLink<V: BaseView>(to screen: Screen, from view: V) -> some View {
        modifier(Link(destination: view.state.view(for: screen), screen: screen))
    }

    func modal<V: BaseView>(for screen: Screen?, from view: V) -> some View {
        onTapGesture {
            view.state.showModal(for: screen)
        }
    }

    func compactSectionSpacing() -> some View {
        modifier(CompactSectionSpacing())
    }

    func scrollTargetLayoutiOS17() -> some View {
        modifier(ScrollTargetLayoutModifier())
    }

    func scrollPositioniOS17(id: Binding<Int?>) -> some View {
        modifier(ScrollPositionModifier(id: id))
    }

    func asAny() -> AnyView { .init(self) }
}

extension UnevenRoundedRectangle {
    static let testTube =
        UnevenRoundedRectangle(
            topLeadingRadius: 50,
            bottomLeadingRadius: 50,
            bottomTrailingRadius: 50,
            topTrailingRadius: 50
        )
}

// BlinkingModifier
struct BlinkingModifier: ViewModifier {
    let shouldBlink: Bool
    @State private var isBlinking = false

    func body(content: Content) -> some View {
        content
            .opacity(shouldBlink ? (isBlinking ? 0.3 : 1) : 1)
            .onAppear { startAnimation() }
            .onChange(of: shouldBlink) { // Neue iOS 17 Syntax
                startAnimation()
            }
    }

    private func startAnimation() {
        isBlinking = false
        guard shouldBlink else { return }

        withAnimation(
            Animation.easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
        ) {
            isBlinking = true
        }
    }
}

extension UIImage {
    func fillImageUpToPortion(color: Color, portion: Double) -> Image {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            draw(in: rect)
            let height: CGFloat = 1 - portion
            let rectToFill = CGRect(x: 0, y: size.height * portion, width: size.width, height: size.height * height)
            UIColor(color).setFill()
            context.fill(rectToFill, blendMode: .sourceIn)
        }
        return Image(uiImage: image)
    }
}
