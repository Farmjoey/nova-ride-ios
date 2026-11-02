import Foundation

public struct RGB: Equatable {
    public var r: Int, g: Int, b: Int
    public init(_ r: Int, _ g: Int, _ b: Int) { self.r = r; self.g = g; self.b = b }
    public init?(hex: String) {
        let u = Array(hex.unicodeScalars)
        guard u.count == 7, u[0] == "#", let v = Int(String(String.UnicodeScalarView(u[1...])), radix: 16) else { return nil }
        self.init((v >> 16) & 255, (v >> 8) & 255, v & 255)
    }
    public var hex: String { String(format: "#%02x%02x%02x", r, g, b) }
    /// Share `t` (0...1) of `other`.
    public func mixed(with other: RGB, _ t: Double) -> RGB {
        func m(_ a: Int, _ b: Int) -> Int { Int((Double(a) + (Double(b) - Double(a)) * t).rounded()) }
        return RGB(m(r, other.r), m(g, other.g), m(b, other.b))
    }
}

/// The eight themes of the board (src/Theme.h). Index = value sent with Op.theme.
public struct NovaTheme {
    public var name: String
    public var bg, panel, neon, glow, dim, warn, ok, bad, text: RGB

    public static let defaultIndex = 6
    public static let customIndex = 7

    public static let all: [NovaTheme] = [
        NovaTheme(name: "NOVA BLUE", bg: RGB(4, 8, 20), panel: RGB(10, 22, 48), neon: RGB(0, 170, 255), glow: RGB(0, 60, 100), dim: RGB(90, 110, 140), warn: RGB(255, 176, 0), ok: RGB(0, 220, 140), bad: RGB(255, 70, 90), text: RGB(225, 240, 255)),
        NovaTheme(name: "EMBER", bg: RGB(18, 6, 4), panel: RGB(44, 18, 10), neon: RGB(255, 110, 20), glow: RGB(110, 45, 0), dim: RGB(140, 110, 95), warn: RGB(255, 200, 0), ok: RGB(120, 220, 80), bad: RGB(255, 60, 60), text: RGB(255, 240, 225)),
        NovaTheme(name: "MATRIX", bg: RGB(2, 12, 6), panel: RGB(8, 36, 18), neon: RGB(0, 255, 110), glow: RGB(0, 90, 40), dim: RGB(80, 140, 100), warn: RGB(255, 200, 0), ok: RGB(120, 255, 160), bad: RGB(255, 80, 80), text: RGB(220, 255, 230)),
        NovaTheme(name: "VIOLET", bg: RGB(10, 4, 20), panel: RGB(28, 14, 52), neon: RGB(170, 90, 255), glow: RGB(70, 30, 120), dim: RGB(120, 100, 150), warn: RGB(255, 190, 60), ok: RGB(0, 220, 160), bad: RGB(255, 80, 120), text: RGB(240, 230, 255)),
        NovaTheme(name: "ROSE", bg: RGB(20, 4, 10), panel: RGB(48, 12, 28), neon: RGB(255, 60, 140), glow: RGB(110, 20, 60), dim: RGB(150, 100, 120), warn: RGB(255, 190, 40), ok: RGB(0, 220, 150), bad: RGB(255, 70, 70), text: RGB(255, 230, 240)),
        NovaTheme(name: "MONO", bg: RGB(0, 0, 0), panel: RGB(26, 26, 26), neon: RGB(235, 235, 235), glow: RGB(80, 80, 80), dim: RGB(120, 120, 120), warn: RGB(255, 190, 0), ok: RGB(0, 220, 120), bad: RGB(255, 70, 70), text: RGB(255, 255, 255)),
        NovaTheme(name: "STEEL", bg: RGB(48, 48, 48), panel: RGB(59, 59, 59), neon: RGB(111, 163, 168), glow: RGB(76, 110, 115), dim: RGB(154, 159, 162), warn: RGB(255, 176, 0), ok: RGB(143, 217, 168), bad: RGB(255, 90, 110), text: RGB(236, 236, 236)),
        NovaTheme(name: "CUSTOM", bg: RGB(48, 48, 48), panel: RGB(59, 59, 59), neon: RGB(111, 163, 168), glow: RGB(76, 110, 115), dim: RGB(154, 159, 162), warn: RGB(255, 176, 0), ok: RGB(143, 217, 168), bad: RGB(255, 90, 110), text: RGB(236, 236, 236)),
    ]

    public static func at(_ i: Int, accent: RGB? = nil) -> NovaTheme {
        var t = all[min(max(i, 0), all.count - 1)]
        if i == customIndex, let a = accent { t.neon = a; t.glow = t.bg.mixed(with: a, 130.0 / 255.0) }
        return t
    }

    /// A colour used by designs: the 11 named palette entries, or "#rrggbb".
    public func color(_ name: String?) -> RGB {
        guard let n = name else { return text }
        if let c = RGB(hex: n) { return c }
        switch n {
        case "text": return text
        case "neon": return neon
        case "ok": return ok
        case "warn": return warn
        case "bad": return bad
        case "dim": return dim
        case "panel": return panel
        case "bg": return bg
        case "glow": return glow
        case "white": return RGB(255, 255, 255)
        case "black": return RGB(0, 0, 0)
        default: return text
        }
    }
}
