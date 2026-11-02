// Stand-in for the part of Apple's SwiftUI that the app uses, only to type-check on a PC. Signatures follow the real API.
@_exported import Foundation
import Combine
import UIKit
import UniformTypeIdentifiers

// ---- core
@preconcurrency @MainActor @resultBuilder public struct ViewBuilder {
    // (the real ViewBuilder is main-actor too; the stand-in builds values from anywhere)
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<C: View>(_ c: C) -> C { c }
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)> { TupleView((c0, c1)) }
    public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<(C0, C1, C2)> { TupleView((c0, c1, c2)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleView<(C0, C1, C2, C3)> { TupleView((c0, c1, c2, c3)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleView<(C0, C1, C2, C3, C4)> { TupleView((c0, c1, c2, c3, c4)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleView<(C0, C1, C2, C3, C4, C5)> { TupleView((c0, c1, c2, c3, c4, c5)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleView<(C0, C1, C2, C3, C4, C5, C6)> { TupleView((c0, c1, c2, c3, c4, c5, c6)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9)) }
    public static func buildIf<C: View>(_ c: C?) -> C? { c }
    public static func buildEither<T: View, F: View>(first: T) -> _Either<T, F> { .first(first) }
    public static func buildEither<T: View, F: View>(second: F) -> _Either<T, F> { .second(second) }
}
public enum _Either<T: View, F: View>: View { case first(T), second(F); public var body: Never { fatalError() } }
extension Optional: View where Wrapped: View { public var body: Never { fatalError() } }
public struct TupleView<T>: View { public init(_ t: T) {}; public var body: Never { fatalError() } }
public struct EmptyView: View { public init() {}; public var body: Never { fatalError() } }
extension Never: View { public var body: Never { fatalError() } }
@preconcurrency @MainActor public protocol View { associatedtype Body: View; @ViewBuilder var body: Self.Body { get } }
public protocol Scene {}
@preconcurrency @MainActor public protocol App { associatedtype Body: Scene; @SceneBuilderStub var body: Self.Body { get }; init() }
extension App { public static func main() {} }
@resultBuilder public struct SceneBuilderStub { public static func buildBlock<C: Scene>(_ c: C) -> C { c } }
public struct WindowGroup<Content: View>: Scene { public init(@ViewBuilder content: () -> Content) {} }

// ---- property wrappers
@propertyWrapper public struct State<Value> {
    final class Box { var v: Value; init(_ v: Value) { self.v = v } }
    private let box: Box
    public init(wrappedValue: Value) { box = Box(wrappedValue) }
    public var wrappedValue: Value { get { box.v } nonmutating set { box.v = newValue } }
    public var projectedValue: Binding<Value> { let b = box; return Binding(get: { b.v }, set: { b.v = $0 }) }
}
@propertyWrapper public struct StateObject<O: ObservableObject> {
    public var wrappedValue: O
    public init(wrappedValue thunk: @autoclosure @escaping () -> O) { wrappedValue = thunk() }
}
@propertyWrapper public struct EnvironmentObject<O: ObservableObject> {
    public var wrappedValue: O { fatalError() }
    public var projectedValue: Wrapper { Wrapper() }
    public init() {}
    @dynamicMemberLookup public struct Wrapper {
        public subscript<S>(dynamicMember keyPath: ReferenceWritableKeyPath<O, S>) -> Binding<S> { fatalError() }
    }
}
@propertyWrapper public struct AppStorage<Value> {
    final class Box { var v: Value; init(_ v: Value) { self.v = v } }
    private let box: Box
    public init(wrappedValue: Value, _ key: String) { box = Box(wrappedValue) }
    public var wrappedValue: Value { get { box.v } nonmutating set { box.v = newValue } }
    public var projectedValue: Binding<Value> { let b = box; return Binding(get: { b.v }, set: { b.v = $0 }) }
}
@propertyWrapper public struct Binding<Value> {
    public var wrappedValue: Value { get { getter() } nonmutating set { setter(newValue) } }
    private let getter: () -> Value, setter: (Value) -> Void
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { getter = get; setter = set }
    public var projectedValue: Binding<Value> { self }
}
// `$model.liveEnabled` on an EnvironmentObject
extension ObservableObject {}
@dynamicMemberLookup public struct ObservedBindings<O: ObservableObject> {
    public subscript<S>(dynamicMember keyPath: ReferenceWritableKeyPath<O, S>) -> Binding<S> { fatalError() }
}
extension EnvironmentObject { }

// ---- layout containers
public struct VStack<Content: View>: View { public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}; public var body: Never { fatalError() } }
public struct HStack<Content: View>: View { public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}; public var body: Never { fatalError() } }
public struct ZStack<Content: View>: View { public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {}; public var body: Never { fatalError() } }
public struct ScrollView<Content: View>: View { public init(@ViewBuilder content: () -> Content) {}; public var body: Never { fatalError() } }
public struct Spacer: View { public init(minLength: CGFloat? = nil) {}; public var body: Never { fatalError() } }
public struct GridItem { public struct Size { public static func flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity) -> Size { Size() }; public static func adaptive(minimum: CGFloat, maximum: CGFloat = .infinity) -> Size { Size() } }
    public init(_ size: Size = .flexible(), spacing: CGFloat? = nil) {} }
public struct LazyVGrid<Content: View>: View { public init(columns: [GridItem], spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}; public var body: Never { fatalError() } }
public struct ForEach<Data, ID: Hashable, Content: View>: View {
    public init(_ data: Range<Int>, id: KeyPath<Int, ID>, @ViewBuilder content: @escaping (Int) -> Content) where Data == Range<Int> {}
    public init(_ data: [Int], id: KeyPath<Int, ID>, @ViewBuilder content: @escaping (Int) -> Content) where Data == [Int] {}
    public init<E>(_ data: [E], id: KeyPath<E, ID>, @ViewBuilder content: @escaping (E) -> Content) where Data == [E] {}
    public var body: Never { fatalError() }
}
public struct TabView<Content: View>: View { public init<S: Hashable>(selection: Binding<S>?, @ViewBuilder content: () -> Content) {}; public var body: Never { fatalError() } }
public struct Picker<Content: View>: View { public init<S: Hashable>(_ title: String, selection: Binding<S>, @ViewBuilder content: () -> Content) {}; public var body: Never { fatalError() } }
public enum HorizontalAlignment { case leading, center, trailing }
public enum VerticalAlignment { case top, center, bottom }
public struct Alignment { public static let center = Alignment(); public static let leading = Alignment(); public static let bottomLeading = Alignment() }
public struct UnitPoint { public static let top = UnitPoint(), topLeading = UnitPoint(), topTrailing = UnitPoint(), center = UnitPoint() }
public enum ContentMode { case fit, fill }

// ---- controls and content
public struct Text: View {
    public init(_ s: String) {}
    public init(_ s: LocalizedStringKeyStub) {}
    public func font(_ f: Font?) -> Text { self }
    public func foregroundColor(_ c: Color?) -> Text { self }
    public func tracking(_ t: CGFloat) -> Text { self }
    public func bold() -> Text { self }
    public var body: Never { fatalError() }
}
public struct LocalizedStringKeyStub {}
public struct Image: View { public init(systemName: String) {}; public func font(_ f: Font?) -> Image { self }; public var body: Never { fatalError() } }
public struct Label<T: View, I: View>: View { public init(_ title: String, systemImage: String) where T == Text, I == Image {}; public var body: Never { fatalError() } }
public struct Button<Label: View>: View {
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {}
    public init(_ title: String, action: @escaping () -> Void) where Label == Text {}
    public var body: Never { fatalError() }
}
public struct Toggle<L: View>: View { public init(_ title: String, isOn: Binding<Bool>) where L == Text {}; public var body: Never { fatalError() } }
public struct Slider: View { public init(value: Binding<Double>, in range: ClosedRange<Double>) {}; public var body: Never { fatalError() } }
public struct ColorPicker<L: View>: View { public init(_ title: String, selection: Binding<Color>, supportsOpacity: Bool = true) where L == Text {}; public var body: Never { fatalError() } }
public struct TextField: View { public init(_ title: String, text: Binding<String>) {}; public var body: Never { fatalError() } }
public struct ProgressView: View { public init() {}; public init(value: Double?, total: Double = 1.0) {}; public var body: Never { fatalError() } }
public struct PickerStyleStub {}; public extension PickerStyleStub { static let segmented = PickerStyleStub() }
public struct TextFieldStyleStub {}; public extension TextFieldStyleStub { static let roundedBorder = TextFieldStyleStub() }

// ---- colour, fonts, shapes, drawing
public struct Color: Equatable {
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {}
    public init(_ uiColor: UIColor) {}
    public static let clear = Color(red: 0, green: 0, blue: 0, opacity: 0), black = Color(red: 0, green: 0, blue: 0), white = Color(red: 1, green: 1, blue: 1)
    public func opacity(_ o: Double) -> Color { self }
}
extension Color: View { public var body: Never { fatalError() } }
public struct Font {
    public static let title = Font(), title2 = Font(), title3 = Font(), headline = Font(), subheadline = Font(), caption = Font(), footnote = Font()
    public enum Weight { case regular, semibold, bold, heavy }
    public enum Design { case `default`, monospaced }
    public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font { Font() }
    public static func custom(_ name: String, fixedSize: CGFloat) -> Font { Font() }
    public func weight(_ w: Weight) -> Font { self }
}
public protocol Shape: View { func path(in rect: CGRect) -> Path }
extension Shape { public var body: Never { fatalError() } }
public extension Shape {
    func fill(_ c: Color) -> some View { self }
    func stroke(_ c: Color, lineWidth: CGFloat = 1) -> some View { self }
    func stroke(_ c: Color, style: StrokeStyle) -> some View { self }
    func trim(from: CGFloat, to: CGFloat) -> some Shape { self }
}
public struct Circle: Shape { nonisolated public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct Capsule: Shape { nonisolated public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct RoundedRectangle: Shape { nonisolated public init(cornerRadius: CGFloat) {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct StrokeStyle { public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter) {} }
public enum CGLineCap { case butt, round, square }
public enum CGLineJoin { case miter, round, bevel }
public struct Angle { public static func degrees(_ d: Double) -> Angle { Angle() } }
public struct Path {
    public init() {}
    public init(_ rect: CGRect) {}
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat) {}
    public init(ellipseIn rect: CGRect) {}
    public mutating func move(to p: CGPoint) {}
    public mutating func addLine(to p: CGPoint) {}
    public mutating func closeSubpath() {}
}
public struct GraphicsContext {
    public enum Shading { case color(Color); public static var clear: Shading { .color(.clear) } }
    public mutating func scaleBy(x: CGFloat, y: CGFloat) {}
    public mutating func translateBy(x: CGFloat, y: CGFloat) {}
    public func fill(_ path: Path, with shading: Shading) {}
    public func stroke(_ path: Path, with shading: Shading, lineWidth: CGFloat = 1) {}
    public func stroke(_ path: Path, with shading: Shading, style: StrokeStyle) {}
    public func draw(_ text: Text, at point: CGPoint, anchor: UnitPoint = .center) {}
}
public struct Canvas: View { public init(_ renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {}; public var body: Never { fatalError() } }

// ---- styles and modifiers
@preconcurrency @MainActor public protocol ViewModifier { associatedtype Body: View; typealias Content = _ModifiedContentStub; @ViewBuilder func body(content: Self.Content) -> Self.Body }
public struct _ModifiedContentStub: View { public var body: Never { fatalError() } }
@preconcurrency @MainActor public protocol ButtonStyle { associatedtype Body: View; typealias Configuration = ButtonStyleConfiguration; @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body }
@MainActor public struct ButtonStyleConfiguration { public struct Label: View { public var body: Never { fatalError() } }; public let label: Label = Label(); public let isPressed = false }
public protocol PreferredScheme {}
public enum ColorScheme { case dark, light }

public extension View {
    func modifier<M: ViewModifier>(_ m: M) -> some View { self }
    func padding(_ length: CGFloat = 8) -> some View { self }
    func padding(_ edges: Edge.Set, _ length: CGFloat = 8) -> some View { self }
    func frame(maxWidth: CGFloat? = nil, alignment: Alignment = .center) -> some View { self }
    func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View { self }
    func frame(height: CGFloat) -> some View { self }
    func background(_ c: Color) -> some View { self }
    func background<V: View>(_ v: V) -> some View { self }
    func overlay<V: View>(_ v: V) -> some View { self }
    func clipShape<S: Shape>(_ s: S) -> some View { self }
    func foregroundColor(_ c: Color?) -> some View { self }
    func font(_ f: Font?) -> some View { self }
    func tint(_ c: Color?) -> some View { self }
    func tabItem<V: View>(@ViewBuilder _ label: () -> V) -> some View { self }
    func tag<T: Hashable>(_ t: T) -> some View { self }
    func pickerStyle(_ s: PickerStyleStub) -> some View { self }
    func textFieldStyle(_ s: TextFieldStyleStub) -> some View { self }
    func buttonStyle<S: ButtonStyle>(_ s: S) -> some View { self }
    func onAppear(perform: (() -> Void)? = nil) -> some View { self }
    func onDisappear(perform: (() -> Void)? = nil) -> some View { self }
    func onChange<V: Equatable>(of value: V, perform: @escaping (V) -> Void) -> some View { self }
    func disabled(_ d: Bool) -> some View { self }
    func fixedSize(horizontal: Bool, vertical: Bool) -> some View { self }
    func opacity(_ o: Double) -> some View { self }
    func ignoresSafeArea() -> some View { self }
    func preferredColorScheme(_ s: ColorScheme?) -> some View { self }
    func environmentObject<O: ObservableObject>(_ o: O) -> some View { self }
    func aspectRatio(_ r: CGFloat, contentMode: ContentMode) -> some View { self }
    func rotationEffect(_ a: Angle) -> some View { self }
    func tracking(_ t: CGFloat) -> some View { self }
    func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View { self }
}
public enum Edge { public struct Set { public static let horizontal = Set(), vertical = Set(), bottom = Set() } }
public extension Edge.Set { static func + (a: Edge.Set, b: Edge.Set) -> Edge.Set { a } }
public extension View { func padding(_ edges: Edge.Set, _ length: CGFloat? = nil) -> some View { self } }
public extension UIColor { convenience init(_ color: Color) { self.init() } }
