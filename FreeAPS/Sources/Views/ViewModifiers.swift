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

struct Sage: View {
    @Environment(\.colorScheme) var colorScheme
    let amount: Double
    let expiration: Double
    var body: some View {
        let fill = max(amount / expiration, 0.07)
        let colour: Color = amount <= 8.64E4 ? .red.opacity(0.9) : amount <= 2 * 8.64E4 ? .loopYellow
            .opacity(0.9) : colorScheme == .light ? .white.opacity(0.7) : .black.opacity(0.8)
        RoundedRectangle(cornerRadius: 15)
            .stroke(colorScheme == .dark ? Color(.clear) : Color(.clear), lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                Gradient.Stop(
                                    color: colour,
                                    location: fill
                                ),
                                Gradient.Stop(color: Color.clear, location: fill)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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

/* struct ColouredRoundedBackground: View {
     @Environment(\.colorScheme) var colorScheme

     var body: some View {
         Rectangle()
             // RoundedRectangle(cornerRadius: 15)
             .fill(
                 Color.black
             )
     }
 } */
extension Color {
    static let rig22Background = Color(red: 0.10, green: 0.10, blue: 0.10)
}

extension Color {
    static let rig22bottomPanel = Color(red: 0.08, green: 0.15, blue: 0.20)
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

/* struct ColouredBackground: View {
     var body: some View {
         RoundedRectangle(cornerRadius: 15)
             .fill(Color.rig22Background)
     }
 } */

struct addColouredBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.rig22Background)
        // .shadow(color: Color.black.opacity(0.5), radius: 10, x: 5, y: 5) // Kräftigerer Schatten
    }
}

struct ColouredBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.rig22Background)
            .shadow(color: Color.black.opacity(0.8), radius: 10, x: 5, y: 5) // Kräftigerer Schatten
    }
}

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

struct TimeEllipse: View {
    @Environment(\.colorScheme) var colorScheme
    let characters: Int
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.gray).opacity(0.2)
            .frame(width: CGFloat(characters * 7), height: 25)
    }
}

struct TimeEllipseBig: View {
    @Environment(\.colorScheme) var colorScheme
    let characters: Int
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.gray).opacity(0.2)
            .frame(width: CGFloat(characters * 10), height: 30)
    }
}

struct TimeEllipseSensorAge: View {
    var remainingDays: Int
    var totalDays: Int
    let characters: Int = 10 // Fixe Basisbreite für den Hintergrund

    var body: some View {
        let progress = CGFloat(remainingDays) / CGFloat(totalDays)
        let maxWidth = CGFloat(characters * 10)

        ZStack(alignment: .leading) {
            // Hintergrund bleibt konstant
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.gray.opacity(0.2))
                .frame(width: maxWidth, height: 30)

            // Farbverlauf für die verbleibenden Tage
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            Gradient.Stop(
                                color: remainingDays == 1 ? .red : (remainingDays == 2 ? .orange : .white.opacity(0.1)),
                                location: progress
                            ),
                            Gradient.Stop(color: Color.clear, location: progress)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: maxWidth * progress, height: 30)
        }
        .clipShape(RoundedRectangle(cornerRadius: 15)) // Verhindert Überlauf
    }
}

// Pillenform bei der Entleerung
/* struct TimeEllipseSensorAge: View {
     var remainingDays: Int
     var totalDays: Int
     let characters: Int = 10 // Fixe Basisbreite für den Hintergrund

     var body: some View {
         let progress = CGFloat(remainingDays) / CGFloat(totalDays)
         let fillColor: Color = remainingDays == 1 ? .red
             .opacity(1.0) : (remainingDays == 2 ? .orange.opacity(1.0) : .white.opacity(0.1))
         let maxWidth = CGFloat(characters * 10)

         ZStack(alignment: .leading) {
             RoundedRectangle(cornerRadius: 15)
                 .fill(Color.gray.opacity(0.2))
                 .frame(width: maxWidth, height: 30)

             RoundedRectangle(cornerRadius: 15)
                 .fill(fillColor)
                 .frame(width: maxWidth * progress, height: 30)
         }
         .clipShape(RoundedRectangle(cornerRadius: 15)) // Verhindert Überlauf
     }
 } */

struct HeaderBackground: View {
    var body: some View {
        Rectangle()
            .fill(Color.rig22Background)
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

extension UIImage {
    /// Code suggested by Mamad Farrahi, but slightly modified. Need to find some newer version later.
    func fillImageUpToPortion(color: Color, portion: Double) -> Image {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: rect)
        let context = UIGraphicsGetCurrentContext()!
        context.setBlendMode(CGBlendMode.sourceIn)
        context
            .setFillColor(
                color.cgColor ?? UIColor(portion > 0.75 ? .red.opacity(0.8) : .insulin.opacity(portion <= 3 ? 0.8 : 1))
                    .cgColor
            )
        let height: CGFloat = 1 - portion
        let rectToFill = CGRect(x: 0, y: size.height * portion, width: size.width, height: size.height * height)
        context.fill(rectToFill)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return Image(uiImage: newImage!)
    }
}
