import SwiftUI
import UIKit

enum ImageTools {
    /// Fits a picture into 128 x 64 on black and returns its luminance (0...255), row by row from the top.
    static func gray128x64(from image: UIImage) -> [UInt8]? {
        let w = Nova.bootImageWidth, h = Nova.bootImageHeight
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt)
        let fitted = renderer.image { rc in
            UIColor.black.setFill()
            rc.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let sz = image.size
            guard sz.width > 0, sz.height > 0 else { return }
            let sc = min(CGFloat(w) / sz.width, CGFloat(h) / sz.height)
            let dw = sz.width * sc, dh = sz.height * sc
            image.draw(in: CGRect(x: (CGFloat(w) - dw) / 2, y: (CGFloat(h) - dh) / 2, width: dw, height: dh))
        }
        guard let cg = fitted.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h)
        let ok: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? pixels : nil
    }

    static func rgb(of color: Color) -> RGB {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        _ = ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// Reads a file the user picked (inside the sandbox permission the picker grants).
    static func readFile(_ url: URL) -> (name: String, bytes: [UInt8])? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let d = try? Data(contentsOf: url) else { return nil }
        return (url.lastPathComponent, [UInt8](d))
    }
}
