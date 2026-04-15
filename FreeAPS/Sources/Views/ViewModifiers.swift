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

struct ActiveOverride: ViewModifier {
    var override: Bool = false
    func body(content: Content) -> some View {
        content
            .overlay {
                override ?

                    Image(systemName: "person.2.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.purple.opacity(0.3), Color.green.opacity(0.3))
                    .font(.system(size: 10))
                    .offset(x: 20)
                    .frame(maxHeight: .infinity, alignment: .leading)

                    : nil
            }
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

struct InfoPanelBackground: View {
    let colorScheme: ColorScheme
    var body: some View {
        Rectangle()
            .stroke(.gray, lineWidth: 2)
            .fill(colorScheme == .light ? .white : .black)
            .frame(height: 24)
    }
}

struct AddShadow: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.black
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
        Rectangle().fill(colorScheme == .dark ? .black : .white)
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
                color: Color.black
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

struct ColouredRoundedBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Rectangle()
            .fill(
                colorScheme == .dark ? IAPSconfig.previewBackgroundDark :
                    IAPSconfig.previewBackgroundLight
            )
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

struct LoopEllipse: View {
    @Environment(\.colorScheme) var colorScheme
    let stroke: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .stroke(stroke, lineWidth: colorScheme == .light ? 2 : 0.7)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .light ? .white : .black)
            )
    }
}

struct Sage: View {
    @Environment(\.colorScheme) var colorScheme
    let amount: Double
    let expiration: Double
    let lineColour: Color
    let sensordays: TimeInterval
    var body: some View {
        let fill = max(expiration / amount, 0.15)
        let colour: Color = (expiration < 0.5 * 8.64E4) ? .red
            .opacity(0.9) : (expiration < 2 * 8.64E4) ? .orange.opacity(0.8) : colorScheme == .light ? Color.white : Color
            .black // Color.white
            .opacity(0.9)
        let scheme = colorScheme == .light ? Color(.systemGray5) : Color(.systemGray2)

        Circle()
            .stroke(scheme, lineWidth: 5)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                Gradient.Stop(
                                    color: colour,
                                    location: fill
                                ),
                                Gradient.Stop(
                                    color: colorScheme == .light ? Color.white : Color.black, // Color.white.opacity(0.9),
                                    location: fill
                                )
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(radius: 4)
            )
    }
}

struct TimeEllipse: View {
    let characters: Int
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.gray).opacity(0.2)
            .frame(width: CGFloat(characters * 7), height: 25)
    }
}

struct HeaderBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Rectangle()
            .fill(
                colorScheme == .light ? IAPSconfig.headerBackgroundLight : IAPSconfig.headerBackgroundDark
            )
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

struct NonStandardInsulin: View {
    let concentration: Double
    let pump: HeaderPump
    let position: BadgePosition = .topTrailing

    enum BadgePosition {
        case topLeading
        case topTrailing
        case custom(CGPoint)
    }

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
        .offset(x: offsetX, y: offsetY)
    }

    private var offsetX: CGFloat {
        switch pump {
        case .pod:
            return 12
        case .medtrum:
            return 13
        default:
            return 10
        }
    }

    private var offsetY: CGFloat {
        switch pump {
        case .pod:
            return -26
        case .medtrum:
            return -24
        default:
            return -20
        }
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

struct ChartBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .light ? .gray.opacity(0.05) : .black).brightness(colorScheme == .dark ? 0.05 : 0)
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

    func addShadows() -> some View {
        modifier(AddShadow())
    }

    func carvingOrRelief(carve: Bool) -> some View {
        modifier(CarveOrDrop(carve: carve))
    }

    func boolTag(_ bool: Bool) -> some View {
        modifier(BoolTag(bool: bool))
    }

    func addBackground() -> some View {
        ColouredRoundedBackground()
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

    func activeOverride(_ override: Bool) -> some View {
        modifier(ActiveOverride(override: override))
    }

    func asAny() -> AnyView { .init(self) }
}

extension UnevenRoundedRectangle {
    static let testTube =
        UnevenRoundedRectangle(
            topLeadingRadius: 1.5,
            bottomLeadingRadius: 50,
            bottomTrailingRadius: 50,
            topTrailingRadius: 1.5
        )
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

struct ElegantBackground: ViewModifier {
    var colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if colorScheme != .dark {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(ZenPalette.strokeLight, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.01))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(ZenPalette.strokeDark, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
            )
    }
}

// Optional: Eine Extension für einfachere Schreibweise
extension View {
    func elegantShadow(scheme: ColorScheme) -> some View {
        modifier(ElegantBackground(colorScheme: scheme))
    }
}

// Ein schönerer, organischer Tropfen
struct BolusDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX - rect.width * 0.2, y: rect.maxY * 0.6),
            control2: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY),
            control2: CGPoint(x: rect.maxX + rect.width * 0.2, y: rect.maxY * 0.6)
        )
        return path
    }
}

struct ModernBolusDrop: View {
    @Environment(\.colorScheme) var colorScheme
    let size: CGFloat

    var body: some View {
        // Definition der adaptiven Farben innerhalb des body
        let lightBlue = colorScheme == .dark
            ? Color(red: 0.45, green: 0.65, blue: 0.95) // Leuchtend für Dark Mode
            : Color(red: 0.60, green: 0.80, blue: 1.00) // Sanfter/Heller für Light Mode

        let darkBlue = colorScheme == .dark
            ? Color(red: 0.15, green: 0.35, blue: 0.65) // Tiefblau für Dark Mode
            : Color(red: 0.30, green: 0.50, blue: 0.80) // Frisches Blau für Light Mode

        ZStack {
            // 1. Hauptform mit radialem Verlauf für Tiefe
            BolusDropShape()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [lightBlue, darkBlue]),
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: size * 0.1,
                        endRadius: size * 1.2
                    )
                )
                // Schatten im Light Mode dezenter machen
                .shadow(
                    color: darkBlue.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    radius: 2,
                    x: 0,
                    y: 2
                )

            // 2. Das Glanzlicht (Spiegelung)
            Capsule()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6))
                .frame(width: size * 0.15, height: size * 0.4)
                .rotationEffect(.degrees(20))
                .offset(x: -size * 0.15, y: -size * 0.1)

            // 3. Lichtpunkt unten rechts
            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3))
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: size * 0.2, y: size * 0.3)
        }
        .frame(width: size, height: size * 1.35)
    }
}

// Styling für die schwebenden Labels (die weißen Boxen)
struct ChartLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
    }
}

extension View {
    func chartLabelStyle() -> some View {
        modifier(ChartLabelStyle())
    }
}

enum HeaderPump {
    case medtrum
    case pod
    case dana
    case medtronic
    case other
}
