import SwiftUI

/// Draws a widget design (docs/WIDGETS.md) the way the board does: a port of `render()` / `drawItem()` in app/widgetlib.js.
/// Used for the live dashboard on Home and for the previews in the design gallery.
enum WidgetPainter {
    static let boxHeight: [CGFloat] = [8, 16, 26, 48, 48, 75]     // glyph box of the board's fonts 1, 2, 4, 6, 7, 8
    static let width: CGFloat = 320, height: CGFloat = 240

    static func color(_ rgb: RGB) -> Color { Color(red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255) }

    // MARK: small accessors for JSON items
    private static func n(_ it: [String: Any], _ k: String, _ d: Double = 0) -> CGFloat {
        guard !Widget.isNil(it[k]) else { return CGFloat(d) }
        let v = Widget.number(it[k]) ?? d
        return CGFloat(v.isNaN ? d : v)
    }
    private static func has(_ it: [String: Any], _ k: String) -> Bool { !Widget.isNil(it[k]) }
    private static func flag(_ it: [String: Any], _ k: String) -> Bool { Widget.truthy(it[k]) }
    private static func s(_ it: [String: Any], _ k: String) -> String? { it[k] as? String }
    private static func fontIndex(_ it: [String: Any]) -> Int {
        let key: String
        if let f = it["font"] as? String { key = f } else if let d = Widget.number(it["font"]) { key = String(Int(d)) } else { key = "2" }
        return Widget.fonts[key] ?? 1
    }

    // MARK: entry point

    static func paint(_ context: GraphicsContext, size: CGSize, design: [String: Any], live: LiveValues, page: Int,
                      theme: NovaTheme, mode: Int?, history: WidgetHistory?) {
        var ctx = context
        let k = size.width / width
        ctx.scaleBy(x: k, y: k)
        let w = Widget.upgrade(design)
        let bg: RGB = theme.color((w["bg"] as? String) ?? "bg")
        ctx.fill(Path(CGRect(x: 0, y: 0, width: width, height: height)), with: .color(color(bg)))
        var list: [[String: Any]] = []
        for case let it as [String: Any] in (w["items"] as? [Any] ?? []) {
            if (it["t"] as? String) == "modebar" {
                for (i, m) in ["walk", "eco", "drive", "sport"].enumerated() {
                    list.append(["t": "button", "x": 4 + i * 79, "y": 206, "w": 75, "h": 30, "action": m, "text": m.uppercased(),
                                 "font": "2", "rad": 9, "color": "text", "color2": "neon"])
                }
            } else { list.append(it) }
        }
        for it in list where WidgetEval.isVisible(it, live, page: page) {
            drawItem(ctx, it, live, theme, mode ?? live.mode, history)
        }
    }

    // MARK: text, shapes

    private static func drawText(_ ctx: GraphicsContext, _ str: String, _ x: CGFloat, _ y: CGFloat, _ font: Int, _ align: String?, _ col: RGB) {
        let h = boxHeight[min(max(font, 0), 5)]
        let size = (h * (font == 0 ? 1.0 : 0.82)).rounded()
        var f: Font
        if font == 4 { f = .system(size: size, weight: .bold, design: .monospaced) }
        else { f = .custom(font == 0 ? "Poppins-Medium" : "Poppins-Bold", fixedSize: size) }
        if font == 0 { f = .custom("Poppins-Medium", fixedSize: size) }
        let t = Text(str).font(f).foregroundColor(color(col))
        let anchor: UnitPoint = align == "center" ? .top : (align == "right" ? .topTrailing : .topLeading)
        ctx.draw(t, at: CGPoint(x: x, y: y + h * 0.08), anchor: anchor)
    }

    private static func rrPath(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        let rr = max(0, min(r, w / 2, h / 2))
        return Path(roundedRect: CGRect(x: x, y: y, width: max(0, w), height: max(0, h)), cornerRadius: rr)
    }

    /// Open arc as a polyline (no dependence on how SwiftUI interprets arc direction). Angles in degrees, clockwise from 3 o'clock.
    private static func arcPath(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat) -> Path {
        var p = Path()
        let steps = max(6, Int(abs(a1 - a0) / 3))
        for i in 0...steps {
            let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)) * .pi / 180
            let pt = CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    private static func strokeArc(_ ctx: GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ ro: CGFloat, _ ri: CGFloat,
                                  _ a0: CGFloat, _ a1: CGFloat, _ caps: Bool, _ col: RGB) {
        let rm = (ro + ri) / 2, tk = ro - ri
        ctx.stroke(arcPath(cx, cy, rm, a0, a1), with: .color(color(col)), style: StrokeStyle(lineWidth: tk, lineCap: caps ? .round : .butt))
    }

    // MARK: icons

    private static func drawIcon(_ context: GraphicsContext, _ id: Int, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ col: RGB, _ fraction: CGFloat) {
        var ctx = context
        ctx.translateBy(x: x, y: y)
        let c = Color(red: Double(col.r) / 255, green: Double(col.g) / 255, blue: Double(col.b) / 255)
        let u = size / 24
        let lw = max(1.5, size / 12)
        let st = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
        func poly(_ pts: [(CGFloat, CGFloat)], close: Bool) -> Path {
            var p = Path()
            for (i, q) in pts.enumerated() {
                let pt = CGPoint(x: q.0 * u, y: q.1 * u)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            if close { p.closeSubpath() }
            return p
        }
        func rect(_ a: CGFloat, _ b: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path { Path(CGRect(x: a * u, y: b * u, width: w * u, height: h * u)) }
        switch id {
        case 0:
            ctx.fill(poly([(14, 1), (5, 14), (11, 14), (9, 23), (19, 9), (13, 9)], close: true), with: .color(c))
        case 1:
            ctx.stroke(rrPath(1 * u, 6 * u, 19 * u, 12 * u, 3 * u), with: .color(c), style: st)
            ctx.fill(rect(21, 10, 2.5, 4), with: .color(c))
            ctx.fill(rect(3.5, 8.5, 14 * max(0, min(1, fraction)), 7), with: .color(c))
        case 2:
            ctx.stroke(rrPath(9 * u, 1 * u, 6 * u, 15 * u, 3 * u), with: .color(c), style: st)
            ctx.fill(Path(ellipseIn: CGRect(x: (12 - 4.5) * u, y: (19 - 4.5) * u, width: 9 * u, height: 9 * u)), with: .color(c))
            ctx.fill(rect(11, 8, 2, 11), with: .color(c))
        case 3:
            ctx.stroke(arcPath(12 * u, 14 * u, 10 * u, 0.85 * 180, 2.15 * 180), with: .color(c), style: st)
            ctx.stroke(poly([(12, 14), (18, 7)], close: false), with: .color(c), style: st)
        case 4:
            ctx.stroke(poly([(12, 2), (23, 21), (1, 21)], close: true), with: .color(c), style: st)
            ctx.fill(rect(11, 8, 2, 7), with: .color(c)); ctx.fill(rect(11, 17, 2, 2), with: .color(c))
        case 5:
            ctx.fill(rrPath(4 * u, 11 * u, 16 * u, 11 * u, 2 * u), with: .color(c))
            ctx.stroke(arcPath(12 * u, 10 * u, 5 * u, 180, 360), with: .color(c), style: st)
        case 6:
            ctx.stroke(rrPath(6 * u, 1 * u, 12 * u, 22 * u, 3 * u), with: .color(c), style: st)
            ctx.fill(rect(10, 19, 4, 1.5), with: .color(c))
        default:
            ctx.fill(Path(ellipseIn: CGRect(x: 7 * u, y: 7 * u, width: 10 * u, height: 10 * u)), with: .color(c))
            for k in 0..<8 {
                let a = CGFloat(k) * .pi / 4
                var p = Path()
                p.move(to: CGPoint(x: 12 * u + cos(a) * 8 * u, y: 12 * u + sin(a) * 8 * u))
                p.addLine(to: CGPoint(x: 12 * u + cos(a) * 11 * u, y: 12 * u + sin(a) * 11 * u))
                ctx.stroke(p, with: .color(c), style: st)
            }
        }
    }

    // MARK: one item

    private static func drawItem(_ ctx: GraphicsContext, _ it: [String: Any], _ live: LiveValues, _ th: NovaTheme, _ mode: Int?, _ history: WidgetHistory?) {
        let t = (it["t"] as? String) ?? ""
        let src = it["src"] as? String
        let srcNo = Widget.sources[src ?? "none"] ?? 0
        let isStatus = Widget.isStatus(srcNo)
        let v: Double? = (t == "button" || (t == "icon" && src == nil)) ? nil : live.value(src)
        var col: RGB = th.color(s(it, "color") ?? "text")
        let col2: RGB = th.color(s(it, "color2") ?? "panel")
        if v != nil && !isStatus, let sev = WidgetEval.severity(it, value: v) { col = sev == "bad" ? th.bad : th.warn }
        let x = n(it, "x"), y = n(it, "y"), w = n(it, "w"), h = n(it, "h"), rad = n(it, "rad")

        switch t {
        case "text":
            drawText(ctx, (it["text"] as? String) ?? "", x, y, fontIndex(it), s(it, "align"), col)

        case "num":
            var str: String
            if src == "mode" { str = live.mode.map { ["WALK", "ECO", "DRIVE", "SPORT"][min(max($0, 0), 3)] } ?? "--" }
            else if isStatus { str = (v ?? 0) != 0 ? "ON" : "OFF" }
            else { str = WidgetEval.format(v, dp: Int(n(it, "dp"))) }
            var ft = fontIndex(it)
            if v == nil && src != "mode" { col = th.dim; if ft > 2 { ft = 2 } }
            let unit = (v != nil || src == "mode") ? ((it["unit"] as? String) ?? "") : ""
            drawText(ctx, ((it["pre"] as? String) ?? "") + str + unit, x, y, ft, s(it, "align"), col)

        case "bar":
            let f = CGFloat(WidgetEval.fraction(it, v)), vert = h > w
            let r = rad
            ctx.fill(rrPath(x, y, w, h, r), with: .color(color(col2)))
            let border = flag(it, "border")
            if border {
                ctx.stroke(rrPath(x + 0.5, y + 0.5, w - 1, h - 1, r), with: .color(color(th.bg.mixed(with: th.text, 0.5))), lineWidth: 1)
            }
            let ix: CGFloat = border ? 2 : 0
            let fw = (vert ? h : w) - ix * 2
            var a: CGFloat = 0, b: CGFloat = f
            let mn = CGFloat(Widget.numOr0(it["min"])); var mx = CGFloat(Widget.numOr0(it["max"])); if mx == 0 { mx = 1 }
            if flag(it, "bidir") {
                let z = (-mn) / (mx - mn)
                let vv: CGFloat = v == nil ? 0 : (CGFloat(v!) - mn) / (mx - mn)
                a = min(z, vv); b = max(z, vv)
            } else if flag(it, "rev") { a = 1 - f; b = 1 } else { a = 0; b = f }
            if b - a > 0.002 {
                let p: Path
                if vert { p = rrPath(x + ix, y + ix + fw * (1 - b), w - ix * 2, max(1, fw * (b - a)), max(0, r - ix)) }
                else { p = rrPath(x + ix + fw * a, y + ix, max(1, fw * (b - a)), h - ix * 2, max(0, r - ix)) }
                ctx.fill(p, with: .color(color(col)))
            }

        case "arc":
            let r2 = n(it, "r"), tk = n(it, "th")
            let a0 = has(it, "a0") ? n(it, "a0") : 135, sw = has(it, "sweep") ? n(it, "sweep") : 270
            let fr = CGFloat(WidgetEval.fraction(it, v))
            let caps = flag(it, "caps"), rev = flag(it, "rev")
            strokeArc(ctx, x, y, r2, r2 - tk, a0, a0 + sw, caps, col2)
            if fr > 0.003 {
                if rev { strokeArc(ctx, x, y, r2, r2 - tk, a0 + sw - sw * fr, a0 + sw, caps, col) }
                else { strokeArc(ctx, x, y, r2, r2 - tk, a0, a0 + sw * fr, caps, col) }
            }
            if flag(it, "ticks") {
                let tc = color(th.bg.mixed(with: th.text, 0.55))
                for k in 0...10 {
                    let q = (a0 + sw * CGFloat(k) / 10) * .pi / 180
                    var p = Path()
                    p.move(to: CGPoint(x: x + cos(q) * (r2 + 3), y: y + sin(q) * (r2 + 3)))
                    p.addLine(to: CGPoint(x: x + cos(q) * (r2 + 8), y: y + sin(q) * (r2 + 8)))
                    ctx.stroke(p, with: .color(tc), lineWidth: 1.5)
                }
            }
            if flag(it, "knob") {
                let qa = (rev ? a0 + sw - sw * fr : a0 + sw * fr) * .pi / 180, rm = r2 - tk / 2, kr = max(4, tk * 0.8)
                ctx.fill(Path(ellipseIn: CGRect(x: x + cos(qa) * rm - kr, y: y + sin(qa) * rm - kr, width: kr * 2, height: kr * 2)), with: .color(color(th.text)))
            }

        case "rect":
            let p = rrPath(x, y, w, h, rad)
            let fill = flag(it, "fill"), border = flag(it, "border")
            if fill || !border { ctx.fill(p, with: .color(color(fill ? col : col2))) }
            if border { ctx.stroke(rrPath(x + 1, y + 1, w - 2, h - 2, max(0, rad - 1)), with: .color(color(col)), lineWidth: 2) }

        case "circle":
            let cr = n(it, "r"), fill = flag(it, "fill"), border = flag(it, "border")
            if fill || !border { ctx.fill(Path(ellipseIn: CGRect(x: x - cr, y: y - cr, width: cr * 2, height: cr * 2)), with: .color(color(col))) }
            if border {
                let tk = has(it, "th") && n(it, "th") != 0 ? n(it, "th") : 2
                let rr = max(1, cr - tk / 2)
                ctx.stroke(Path(ellipseIn: CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2)), with: .color(color(col)), lineWidth: max(1, tk))
            }

        case "line":
            var p = Path()
            if flag(it, "rev") { p.move(to: CGPoint(x: x, y: y + h)); p.addLine(to: CGPoint(x: x + w, y: y)) }
            else { p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + w, y: y + h)) }
            ctx.stroke(p, with: .color(color(col)), style: StrokeStyle(lineWidth: has(it, "th") ? n(it, "th") : 2, lineCap: .round))

        case "button":
            let act = (it["action"] as? String) ?? "none"
            let modeOf = ["walk": 0, "eco": 1, "drive": 2, "sport": 3]
            let selected = modeOf[act] != nil && mode == modeOf[act]
            let r = rad != 0 ? rad : 9
            let selCol: RGB = th.color(s(it, "color2") ?? "neon")
            if selected || flag(it, "fill") { ctx.fill(rrPath(x, y, w, h, r), with: .color(selected ? color(selCol) : .clear)) }
            ctx.stroke(rrPath(x + 1, y + 1, w - 2, h - 2, max(0, r - 1)), with: .color(color(col)), lineWidth: 2)
            let bf = fontIndex(it)
            let lum = (Double(selCol.r) * 299 + Double(selCol.g) * 587 + Double(selCol.b) * 114) / 255000
            let tc: RGB = selected ? (lum > 0.55 ? th.bg : th.text) : col
            drawText(ctx, (it["text"] as? String) ?? "", x + w / 2, y + h / 2 - boxHeight[min(bf, 5)] / 2, bf, "center", tc)

        case "segbar":
            let cnt = max(2, has(it, "n") ? Int(n(it, "n")) : 10)
            let gap = max(1, (w / CGFloat(cnt) * 0.18).rounded())
            let sw2 = (w - gap * CGFloat(cnt - 1)) / CGFloat(cnt)
            let lit = Int((WidgetEval.fraction(it, v) * Double(cnt)).rounded())
            for j in 0..<cnt {
                let rr: CGFloat = flag(it, "round") ? min(3, sw2 / 2) : 0
                ctx.fill(rrPath(x + CGFloat(j) * (sw2 + gap), y, sw2, h, rr), with: .color(color(j < lit ? col : col2)))
            }

        case "spark":
            let hs = history?.series[src ?? ""] ?? []
            let tk = has(it, "th") ? n(it, "th") : 2
            ctx.stroke(Path(CGRect(x: x + 0.5, y: y + 0.5, width: max(0, w - 1), height: max(0, h - 1))), with: .color(color(col2)), lineWidth: 1)
            if hs.count > 1 {
                func pt(_ k: Int, _ q: Double) -> CGPoint {
                    CGPoint(x: x + (w - 1) * CGFloat(k) / CGFloat(hs.count - 1), y: y + h - 1 - (h - 2) * CGFloat(WidgetEval.fraction(it, q)))
                }
                var line = Path()
                for (k, q) in hs.enumerated() { if k == 0 { line.move(to: pt(k, q)) } else { line.addLine(to: pt(k, q)) } }
                if flag(it, "fill") {
                    var area = line
                    area.addLine(to: CGPoint(x: x + w - 1, y: y + h - 1)); area.addLine(to: CGPoint(x: x, y: y + h - 1)); area.closeSubpath()
                    ctx.fill(area, with: .color(color(th.bg.mixed(with: col, 0.35))))
                }
                ctx.stroke(line, with: .color(color(col)), style: StrokeStyle(lineWidth: tk, lineCap: .butt, lineJoin: .round))
            }

        case "dot":
            let on = v != nil && v! > 0
            let r = has(it, "r") ? n(it, "r") : 4
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color(on ? col : col2)))

        case "icon":
            let name = (it["icon"] as? String) ?? "bolt"
            let id = Widget.icons[name] ?? 0
            let frac: CGFloat = (name == "battery" && src != nil) ? CGFloat(WidgetEval.fraction(it, v)) : 1
            drawIcon(ctx, id, x, y, has(it, "size") ? n(it, "size") : 24, col, frac)

        default: break
        }
    }
}
