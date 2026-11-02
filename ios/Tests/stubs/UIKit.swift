// Stand-in for the part of UIKit that the app uses, only to type-check on a PC.
@_exported import Foundation
public class CGColorSpace {}
public func CGColorSpaceCreateDeviceGray() -> CGColorSpace { CGColorSpace() }
public enum CGImageAlphaInfo: UInt32 { case none = 0 }
public class CGImage {}
public class CGContext {
    public init?(data: UnsafeMutableRawPointer?, width: Int, height: Int, bitsPerComponent: Int, bytesPerRow: Int, space: CGColorSpace, bitmapInfo: UInt32) {}
    public func draw(_ image: CGImage, in rect: CGRect) {}
}
public class UIColor { public init() {}; public static let black = UIColor(); public func setFill() {}
    public func getRed(_ r: UnsafeMutablePointer<CGFloat>?, green g: UnsafeMutablePointer<CGFloat>?, blue b: UnsafeMutablePointer<CGFloat>?, alpha a: UnsafeMutablePointer<CGFloat>?) -> Bool { true } }
public class UIImage { public init?(data: Data) {}; public var size: CGSize { CGSize(width: 1, height: 1) }; public var cgImage: CGImage? { nil }; public func draw(in rect: CGRect) {} }
public class UIGraphicsImageRendererFormat { public init() {}; public var scale: CGFloat = 1; public var opaque = false }
public class UIGraphicsImageRendererContext { public func fill(_ r: CGRect) {} }
public class UIGraphicsImageRenderer { public init(size: CGSize, format: UIGraphicsImageRendererFormat) {}; public func image(actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage { UIImage(data: Data())! } }
extension URL {
    public func startAccessingSecurityScopedResource() -> Bool { true }
    public func stopAccessingSecurityScopedResource() {}
}
