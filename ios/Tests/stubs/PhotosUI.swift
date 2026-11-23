import Foundation
import SwiftUI
public struct PhotosPickerItem: Equatable { public func loadTransferable<T>(type: T.Type) async throws -> T? { nil } }
public struct PHPickerFilter { public static let images = PHPickerFilter() }
public struct PhotosPicker<Label: View>: View {
    public init(selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil, @ViewBuilder label: () -> Label) {}
    public var body: Never { fatalError() }
}
