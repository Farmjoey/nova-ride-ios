// Stand-in for Apple's Combine, only to type-check the app on a PC. Not shipped.
import Foundation
public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
