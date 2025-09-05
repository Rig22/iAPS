import Combine
import SwiftUI

// MARK: - ViewModifier mit dynamischen Farben

struct RoundedBackground: ViewModifier {
    private let color: Color

    init(color: Color = .dynamicBackground) { // Dynamische Farbe
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                Rectangle()
                    .fill()
                    .foregroundColor(color)
            )
    }
}

struct CompactSectionSpacing: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listSectionSpacing(.compact)
    }
}

struct FrostedGlass: View {
    let opacity: CGFloat
    var body: some View {
        UnevenRoundedRectangle.testTube
            .fill(.ultraThinMaterial.opacity(opacity))
    }
}

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
                .offset(x: !mdtPump ? 10 : 12, y: !mdtPump ? -20 : -22)
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

struct AddShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .dynamicButtonShadow, radius: 3) // Dynamischer Schatten
    }
}

struct ColouredBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Rectangle()
            .fill(
                colorScheme == .dark ? IAPSconfig.chartBackgroundDark :
                    IAPSconfig.chartBackgroundLight
            )
    }
}

struct ChartBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.dynamicChartBackground) // Dynamischer Hintergrund
    }
}

struct HeaderBackground: View {
    var body: some View {
        Rectangle()
            .fill(Color.dynamicHeaderBackground) // Dynamischer Header-Hintergrund
    }
}

struct ColouredRoundedBackground: View {
    var body: some View {
        Rectangle()
            .fill(Color.dynamicCardBackground) // Dynamische Kartenhintergrundfarbe
    }
}

struct InfoPanelBackground: View {
    var body: some View {
        Rectangle()
            .stroke(Color.dynamicSecondaryText, lineWidth: 2) // Dynamischer Rand
            .fill(Color.dynamicCardBackground) // Dynamischer Hintergrund
            .frame(height: 24)
    }
}

struct LoopEllipse: View {
    let stroke: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .stroke(stroke, lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.dynamicBackground)
            )
    }
}

struct TestTube: View {
    let opacity: CGFloat
    let amount: CGFloat
    let colourOfSubstance: Color
    let materialOpacity: CGFloat

    var body: some View {
        UnevenRoundedRectangle.testTube
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        Gradient.Stop(color: .dynamicTopGlow.opacity(opacity), location: amount),
                        Gradient.Stop(color: colourOfSubstance, location: amount)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                FrostedGlass(opacity: materialOpacity)
            }
            .shadow(color: .dynamicButtonShadow, radius: 3) // Dynamischer Schatten
    }
}

struct Sage: View {
    let amount: Double
    let expiration: Double
    let lineColour: Color
    let sensordays: TimeInterval

    private let strokeColor = Color.dynamicIconBackground.opacity(0.4)
    private let normalFillColor = Color.dynamicIconForeground.opacity(0.4)
    private let backgroundFillColor = Color.dynamicIconBackground

    var body: some View {
        let fill = min(max(expiration / amount, 0.15), 1.0)

        let fillColor: Color = {
            switch expiration {
            case ..<(0.5 * 8.64E4):
                return .red.opacity(0.9)
            case ..<(2 * 8.64E4):
                return .yellow.opacity(0.8)
            default:
                return normalFillColor
            }
        }()

        Circle()
            .stroke(strokeColor, lineWidth: 2)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                Gradient.Stop(color: fillColor, location: 0),
                                Gradient.Stop(color: fillColor, location: fill),
                                Gradient.Stop(color: backgroundFillColor, location: fill),
                                Gradient.Stop(color: backgroundFillColor, location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                // .shadow(radius: 4)
            )
    }
}

// MARK: - Dynamische Farben

// Initializer für dynamische Farben
extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor(
            light: UIColor(light),
            dark: UIColor(dark)
        ))
    }
}

extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark,
                 .unspecified:
                return dark
            case .light:
                return light
            @unknown default:
                return light
            }
        }
    }
}

extension Color {
    // 3D-Effekte
    static let dynamicTopGlow = Color(
        light: Color(red: 1.00, green: 1.00, blue: 1.00, opacity: 0.8),
        dark: Color(red: 1.00, green: 1.00, blue: 1.00, opacity: 0.7)
    )

    static let dynamicBottomShadow = Color(
        light: Color(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.3),
        dark: Color(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.6)
    )

    static let dynamicButtonShadow = Color(
        light: Color(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.3),
        dark: Color(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.5)
    )

    /// Alle Chart und App Hintergründe

    /// Der Haupt App Hintergrund
    static let dynamicBackground = Color(
        // light: Color(red: 0.92, green: 0.92, blue: 0.92),
        light: Color(red: 1.0, green: 1.0, blue: 1.0),

        // dark: Color(red: 0.15, green: 0.15, blue: 0.15)
        dark: Color(red: 0.11, green: 0.11, blue: 0.12)
    )

    static let dynamicChartBackground = Color(
        light: Color(red: 0.9, green: 0.9, blue: 0.9),
        dark: Color(red: 0.2, green: 0.2, blue: 0.2)
    )

    static let dynamicCardBackground = Color(
        light: Color(red: 1.00, green: 1.00, blue: 1.00),
        dark: Color(red: 0.20, green: 0.20, blue: 0.20)
    )

    static let dynamicHeaderBackground = Color(
        light: Color(red: 0.98, green: 0.98, blue: 0.98),
        dark: Color(red: 0.15, green: 0.15, blue: 0.15)
    )

    /// Texte
    static let dynamicPrimaryText = Color(
        light: Color(red: 0.10, green: 0.10, blue: 0.10),
        dark: Color(red: 0.95, green: 0.95, blue: 0.95)
    )

    static let dynamicSecondaryText = Color(
        light: Color(red: 0.40, green: 0.40, blue: 0.40),
        dark: Color(red: 0.90, green: 0.90, blue: 0.90)
    )

    /// Dynamische Farben
    static let dynamicColorBlue = Color(
        light: Color(red: 0.45, green: 0.70, blue: 0.95),
        dark: Color(red: 0.29, green: 0.55, blue: 0.91)
    )

    static let dynamicColorRed = Color(
        light: Color(red: 1.0, green: 0.65, blue: 0.65),
        dark: Color(red: 0.96, green: 0.47, blue: 0.47)
    )

    static let dynamicColorGreen = Color(
        light: Color(red: 0.50, green: 0.85, blue: 0.60),
        dark: Color(red: 0.25, green: 0.73, blue: 0.44)
    )

    static let dynamicColorYellow = Color(
        light: Color(red: 1.00, green: 0.90, blue: 0.50),
        dark: Color(red: 0.95, green: 0.77, blue: 0.25)
    )

    static let dynamicColorBrown = Color(
        light: Color(red: 0.80, green: 0.65, blue: 0.54),
        dark: Color(red: 0.60, green: 0.50, blue: 0.42)
    )

    static let dynamicColorOrange = Color(
        light: Color(red: 1.00, green: 0.70, blue: 0.40),
        dark: Color(red: 0.95, green: 0.55, blue: 0.20)
    )

    /// Icons und Akzente
    static let dynamicIconBackground = Color(
        // light: Color(red: 0.85, green: 0.85, blue: 0.85),
        light: Color(red: 0.90, green: 0.90, blue: 0.93),
        dark: Color(red: 0.17, green: 0.17, blue: 0.18)
    )

    static let dynamicIconForeground = Color(
        light: Color(red: 0.50, green: 0.50, blue: 0.50),
        dark: Color(red: 0.90, green: 0.90, blue: 0.90)
    )

    static let dynamicAccent = Color(
        light: Color(red: 0.00, green: 0.47, blue: 0.85),
        dark: Color(red: 0.00, green: 0.60, blue: 1.00)
    )
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

    func addColouredBackground() -> some View {
        ColouredBackground()
    }

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

struct GradientMaskAnimationModifier: ViewModifier {
    let isActive: Bool
    @State private var animate = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 60)
                    .offset(x: animate ? -60 : 60)
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: animate)
                    .mask(content)
                    .onAppear { animate = true }
                    .onDisappear { animate = false }
                }
            }
    }
}

extension View {
    func loopingGradientMask(isActive: Bool) -> some View {
        modifier(GradientMaskAnimationModifier(isActive: isActive))
    }
}

struct VerticalFillMaskModifier: ViewModifier {
    let fillFraction: CGFloat
    let fillColor: Color

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let height = geometry.size.height * fillFraction
                    fillColor
                        .frame(height: height)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .mask(content)
                }
                .allowsHitTesting(false)
            }
    }
}

extension View {
    func verticalFillMask(fillFraction: CGFloat, gradient: LinearGradient) -> some View {
        overlay(
            GeometryReader { geo in
                gradient
                    .frame(height: geo.size.height * fillFraction)
                    .position(
                        x: geo.size.width / 2,
                        y: geo.size.height * (1 - fillFraction / 2)
                    )
                    .clipped()
            }
            .mask(self)
        )
    }
}
