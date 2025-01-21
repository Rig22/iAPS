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

struct CapsulaBackground: ViewModifier {
    private let color: Color

    init(color: Color = Color("CapsuleColor")) {
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                Rectangle()
                    // Capsule()
                    .fill()
                    .foregroundColor(Color.white)
            )
    }
}

struct CompactSectionSpacing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            return content
                .listSectionSpacing(.compact)
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
    static let rig22Background = Color(red: 0.08, green: 0.15, blue: 0.20)
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

struct ColouredBackground: View {
    // @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Rectangle()
            .fill(Color.rig22Background)
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

struct AdaptsToSoftwareKeyboard: ViewModifier {
    @State var currentHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, currentHeight).animation(.easeOut(duration: 0.25))
            .edgesIgnoringSafeArea(currentHeight == 0 ? Edge.Set() : .bottom)
            .onAppear(perform: subscribeToKeyboardChanges)
    }

    private let keyboardHeightOnOpening = Foundation.NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillShowNotification)
        .map { $0.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as! CGRect }
        .map(\.height)

    private let keyboardHeightOnHiding = Foundation.NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillHideNotification)
        .map { _ in CGFloat(0) }

    private func subscribeToKeyboardChanges() {
        _ = Publishers.Merge(keyboardHeightOnOpening, keyboardHeightOnHiding)
            .subscribe(on: DispatchQueue.main)
            .sink { height in
                if self.currentHeight == 0 || height == 0 {
                    self.currentHeight = height
                }
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

    func adaptsToSoftwareKeyboard() -> some View {
        modifier(AdaptsToSoftwareKeyboard())
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
        context.setFillColor(color.cgColor ?? UIColor(.insulin.opacity(portion <= 3 ? 0.8 : 1)).cgColor)
        let height: CGFloat = 1 - portion
        let rectToFill = CGRect(x: 0, y: size.height * portion, width: size.width, height: size.height * height)
        context.fill(rectToFill)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return Image(uiImage: newImage!)
    }
}
