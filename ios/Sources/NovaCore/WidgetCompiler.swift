import Foundation

/// Widget design compiler: JSON (v1 or v2) -> the compact binary the board stores (src/WidgetLayout.h, docs/WIDGETS.md).
/// This is a line-by-line port of `compile()` in app/widgetlib.js: same rules, same Danish error messages, same bytes.
/// `NovaChecks` compiles every starter design and compares the bytes with the JavaScript compiler's output.
public enum Widget {
    public static let types: [String: Int] = ["text": 1, "num": 2, "bar": 3, "arc": 4, "rect": 6, "circle": 7, "line": 8,
                                               "button": 9, "segbar": 10, "spark": 11, "dot": 12, "icon": 13]
    public static let sources: [String: Int] = ["none": 0, "speed": 1, "power": 2, "battery": 3, "volt": 4, "current": 5, "temp": 6,
                                                 "motortemp": 7, "trip": 8, "total": 9, "mode": 10, "fault": 11, "maxspeed": 12,
                                                 "maxpower": 13, "minvolt": 14, "energy": 15, "ridetime": 16, "ble": 17, "phone": 18,
                                                 "limit": 19, "demo": 20, "alert": 21, "regen": 22, "moving": 23]
    public static let palette: [String: Int] = ["text": 0, "neon": 1, "ok": 2, "warn": 3, "bad": 4, "dim": 5, "panel": 6, "bg": 7,
                                                 "glow": 8, "white": 9, "black": 10]
    public static let fonts: [String: Int] = ["1": 0, "2": 1, "4": 2, "6": 3, "7": 4, "8": 5]
    public static let aligns: [String: Int] = ["left": 0, "center": 1, "right": 2]
    public static let actions: [String: Int] = ["none": 0, "nextpage": 1, "prevpage": 2, "walk": 3, "eco": 4, "drive": 5, "sport": 6,
                                                 "prevtrack": 7, "playpause": 8, "nexttrack": 9, "settings": 10, "music": 12, "safety": 13]
    public static let icons: [String: Int] = ["bolt": 0, "battery": 1, "thermo": 2, "gauge": 3, "warning": 4, "lock": 5, "phone": 6, "light": 7]
    public static let ops: [String: Int] = ["none": 0, ">": 1, "<": 2, "==": 3, "!=": 4, ">=": 5, "<=": 6]
    public static let flagBits: [(String, Int)] = [("fill", 1), ("round", 2), ("border", 4), ("knob", 8), ("ticks", 16), ("caps", 32), ("bidir", 64), ("rev", 128)]
    public static let maxItems = 48, maxStrings = 24, stringLen = 16, maxColors = 16, headerLen = 12, itemLen = 32

    public static func isNumeric(_ s: Int) -> Bool { (s >= 1 && s <= 9) || (s >= 12 && s <= 16) }
    public static func isStatus(_ s: Int) -> Bool { s >= 17 && s <= 23 }

    public struct Result {
        public var ok: Bool
        public var bytes: [UInt8]
        public var errors: [String]
        public var pages: Int
    }

    // MARK: JavaScript-like helpers (so odd input behaves like it does in the JS compiler)

    /// JavaScript `Math.round`: halves go up (toward +infinity).
    static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

    /// JavaScript `Number(v)`; nil when the result is NaN.
    static func number(_ v: Any?) -> Double? {
        guard let v = v else { return nil }
        if v is NSNull { return 0 }
        if type(of: v) == Bool.self, let b = v as? Bool { return b ? 1 : 0 }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return 0 }
            return Double(t)
        }
        return nil
    }
    /// `+v || 0`
    static func numOr0(_ v: Any?) -> Double { let n = number(v) ?? 0; return n.isNaN ? 0 : n }
    static func isNil(_ v: Any?) -> Bool { v == nil || v is NSNull }
    static func truthy(_ v: Any?) -> Bool {
        guard let v = v, !(v is NSNull) else { return false }
        if let n = v as? NSNumber { return n.doubleValue != 0 }
        if let s = v as? String { return !s.isEmpty }
        return true
    }
    static func intOf(_ d: Double) -> Int {
        if d.isNaN || d.isInfinite { return 0 }
        return Int(max(-1e9, min(1e9, d)))
    }
    static func clampi(_ v: Any?, _ a: Int, _ b: Int) -> Int {
        let n = jsRound(number(v) ?? 0)
        let i = intOf(n)
        return i < a ? a : (i > b ? b : i)
    }
    static func str(_ v: Any?) -> String? { v as? String }
    static func isASCIIText(_ s: String) -> Bool { s.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value <= 0x7E } }

    static func rgb565(_ hex: String) -> Int {
        let u = Array(hex.unicodeScalars)
        func h(_ a: Int) -> Int { Int(String(String.UnicodeScalarView(u[a..<a + 2])), radix: 16) ?? 0 }
        let r = h(1), g = h(3), b = h(5)
        return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
    }
    static func isHexColor(_ s: String) -> Bool {
        let u = Array(s.unicodeScalars)
        guard u.count == 7, u[0] == "#" else { return false }
        return u[1...].allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) || ("A"..."F").contains($0) }
    }

    // MARK: v1 -> v2

    /// Old (v1) files are upgraded: ring -> arc, bar/rect get a border, `pages` = 1.
    public static func upgrade(_ w: [String: Any]) -> [String: Any] {
        if let v = number(w["v"]), v == 2 { return w }
        var o: [String: Any] = ["v": 2, "pages": 1]
        if let n = w["name"] { o["name"] = n }
        if let a = w["author"] { o["author"] = a }
        if let d = w["desc"] { o["desc"] = d }
        var items: [[String: Any]] = []
        for case var it as [String: Any] in (w["items"] as? [Any] ?? []) {
            let t = it["t"] as? String
            if t == "ring" { it["t"] = "arc"; it["a0"] = 135; it["sweep"] = 270; it["color2"] = "panel" }
            if t == "bar" { it["border"] = true; it["color2"] = "panel" }
            if t == "rect" { it["border"] = true; it["rad"] = 4 }
            items.append(it)
        }
        o["items"] = items
        return o
    }

    // MARK: compile

    private struct Packed {
        var t = 0, s = 0, color = 0, color2 = 0, font = 0, al = 0, dp = 0, pg = 0, str = 255, str2 = 255
        var max = 0, min = 0, x = 0, y = 0, w = 0, h = 0
        var flags = 0, a0 = 0, sw = 0, th = 0, showSrc = 0, showOp = 0, showVal = 0, warn = 0, bad = 0
    }

    public static func compile(_ w0: [String: Any]?) -> Result {
        var err: [String] = []
        func bad(_ i: Int, _ m: String) { err.append((i < 0 ? "" : "Element \(i + 1): ") + m) }
        guard let w0 = w0 else { return Result(ok: false, bytes: [], errors: ["Ingen widget"], pages: 1) }
        let w = upgrade(w0)
        guard let rawItems = w["items"] as? [Any], rawItems.count >= 1 else {
            return Result(ok: false, bytes: [], errors: ["Widget skal have mindst ét element"], pages: 1)
        }
        let pages = clampi(isNil(w["pages"]) ? 1 : w["pages"], 1, 4)
        var strs: [String] = []
        var cols: [Int] = []
        var out: [Packed] = []

        func strIdx(_ v: Any?, _ i: Int, _ what: String) -> Int {
            var s = ""
            if let t = v as? String { s = t } else if let n = v, !(n is NSNull) {
                if type(of: n) == Bool.self, let b = n as? Bool { s = b ? "true" : "false" }
                else if let num = number(n) { s = num == num.rounded() ? String(Int(num)) : String(num) }
            }
            if !isASCIIText(s) { bad(i, what + " må kun have almindelige tegn (ASCII)"); return 255 }
            if s.isEmpty { return 255 }
            if s.count > stringLen - 1 { bad(i, what + " maks \(stringLen - 1) tegn"); return 255 }
            var k = strs.firstIndex(of: s) ?? -1
            if k < 0 {
                if strs.count >= maxStrings { bad(i, "For mange forskellige tekster (maks \(maxStrings))"); return 255 }
                strs.append(s); k = strs.count - 1
            }
            return k
        }
        func colIdx(_ c: Any?, _ def: String, _ i: Int, _ what: String) -> Int {
            let cc: Any? = isNil(c) ? def : c
            if let s = cc as? String, s.hasPrefix("#") {
                if !isHexColor(s) { bad(i, what + ": farve skal være #rrggbb"); return 0 }
                let v = rgb565(s)
                var k = cols.firstIndex(of: v) ?? -1
                if k < 0 {
                    if cols.count >= maxColors { bad(i, "For mange egne farver (maks \(maxColors))"); return 0 }
                    cols.append(v); k = cols.count - 1
                }
                return 16 + k
            }
            if let s = cc as? String, let p = palette[s] { return p }
            bad(i, what + ": ukendt farve")
            return 0
        }

        let bg = colIdx(w["bg"], "bg", -1, "Baggrund")

        // old mode bar: four real buttons along the bottom
        var expanded: [[String: Any]] = []
        for raw in rawItems {
            guard let it = raw as? [String: Any] else { expanded.append([:]); continue }
            if (it["t"] as? String) == "modebar" {
                for (k, m) in ["walk", "eco", "drive", "sport"].enumerated() {
                    expanded.append(["t": "button", "x": 4 + k * 79, "y": 206, "w": 75, "h": 30, "action": m, "text": m.uppercased(),
                                     "font": "2", "rad": 9, "color": "text", "color2": "panel"])
                }
            } else { expanded.append(it) }
        }
        if expanded.count > maxItems { return Result(ok: false, bytes: [], errors: ["Højst \(maxItems) elementer"], pages: pages) }

        for (i, var it) in expanded.enumerated() {
            let tn0 = it["t"] as? String
            let tn = tn0 == "ring" ? "arc" : tn0
            guard let tnn = tn, let t = types[tnn] else { bad(i, "Ukendt type"); continue }
            var s: Int? = nil
            do {
                let sv: Any? = isNil(it["src"]) ? "none" : it["src"]
                if let ss = sv as? String { s = sources[ss] }
            }
            if (it["action"] as? String) == "messages" { it["action"] = "none" }
            if t == 9 {
                let av: Any? = isNil(it["action"]) ? "none" : it["action"]
                guard let a = (av as? String).flatMap({ actions[$0] }) else { bad(i, "Ukendt handling"); continue }
                s = a
            } else if s == nil { bad(i, "Ukendt kilde"); continue }
            let sv = s ?? 0
            let color = colIdx(it["color"], "text", i, "Farve")
            let color2 = colIdx(it["color2"], tnn == "button" ? "neon" : "panel", i, "Farve 2")
            let fontKey: String
            if isNil(it["font"]) { fontKey = "2" } else if let f = it["font"] as? String { fontKey = f } else if let n = number(it["font"]) { fontKey = String(intOf(n)) } else { fontKey = "?" }
            guard let font = fonts[fontKey] else { bad(i, "Ukendt skrifttype (1, 2, 4, 6, 7, 8)"); continue }
            let alKey: String = isNil(it["align"]) ? "left" : ((it["align"] as? String) ?? "?")
            guard let al = aligns[alKey] else { bad(i, "Ukendt justering"); continue }
            let dp = isNil(it["dp"]) ? 0 : intOf((number(it["dp"]) ?? 0).rounded(.towardZero))
            if dp < 0 || dp > 2 { bad(i, "Decimaler 0-2"); continue }
            var pg = 15
            if !isNil(it["page"]) {
                if (it["page"] as? String) == "all" { pg = 15 } else { pg = intOf((number(it["page"]) ?? 0).rounded(.towardZero)) }
            }
            if pg != 15 && (pg < 0 || pg >= pages) { bad(i, "Side findes ikke (siderne er 0-\(pages - 1))"); continue }

            let x = intOf(jsRound(numOr0(it["x"]))), y = intOf(jsRound(numOr0(it["y"])))
            var wd = intOf(jsRound(numOr0(it["w"]))), ht = intOf(jsRound(numOr0(it["h"])))
            let mn = isNil(it["min"]) ? 0 : intOf(jsRound(number(it["min"]) ?? 0))
            let mx = isNil(it["max"]) ? 0 : intOf(jsRound(number(it["max"]) ?? 0))
            var th = intOf(jsRound(numOr0(it["rad"])))
            let a0src: Double = { if let n = number(it["a0"]) { return n } else { return 135 } }()
            let a0m = (a0src.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let a0 = intOf(jsRound(a0m / 2))
            let sw = intOf(jsRound((isNil(it["sweep"]) ? 270 : (number(it["sweep"]) ?? 0)) / 2))
            var flags = 0
            for (k, bit) in flagBits where truthy(it[k]) { flags |= bit }
            let strSource: Any? = ((it["t"] as? String) == "text" || t == 9) ? it["text"] : it["unit"]
            let str = strIdx(strSource, i, "Tekst")
            let str2 = strIdx(it["pre"], i, "Præfiks")

            switch t {
            case 1:
                if sv != 0 { bad(i, "Tekst har ingen kilde") }
                if font > 2 { bad(i, "Tekst kan kun bruge skrift 1, 2 eller 4") }
                if str == 255 { bad(i, "Tekst mangler") }
            case 2:
                if sv == 0 { bad(i, "Tal skal have en kilde") }
                if sv == sources["mode"]! && font > 2 { bad(i, "Tilstandsnavn kan kun bruge skrift 1, 2 eller 4") }
                if font > 2 && (str != 255 || str2 != 255) { bad(i, "Skrift 6, 7 og 8 kan kun vise tal - brug en tekst ved siden af i stedet for enhed/præfiks") }
            case 3:
                if !isNumeric(sv) { bad(i, "Bjælke skal have en talkilde") }
                if mx <= mn { bad(i, "max skal være større end min") }
                if wd < 4 || wd > 320 || ht < 2 || ht > 200 { bad(i, "Bjælke: bredde 4-320, højde 2-200") }
                if Double(th) > Double(min(wd, ht)) / 2 { bad(i, "Afrunding er for stor") }
            case 4:
                let r = intOf(jsRound(numOr0(it["r"]))), tk = intOf(jsRound(numOr0(it["th"])))
                wd = r; ht = tk
                if !isNumeric(sv) { bad(i, "Bue skal have en talkilde") }
                if mx <= mn { bad(i, "max skal være større end min") }
                if r < 8 || r > 160 || tk < 1 || tk >= r { bad(i, "Bue: radius 8-160, tykkelse 1 til under radius") }
                if sw < 1 || sw > 180 { bad(i, "Bue: åbning 2-360 grader") }
            case 6:
                if wd < 2 || wd > 640 || ht < 2 || ht > 640 { bad(i, "Firkant: bredde og højde 2-640") }
                if Double(th) > Double(min(wd, ht)) / 2 { bad(i, "Afrunding er for stor") }
            case 7:
                let cr = intOf(jsRound(numOr0(it["r"]))); wd = cr; ht = 0
                if cr < 2 || cr > 160 { bad(i, "Cirkel: radius 2-160") }
                th = intOf(jsRound(numOr0(it["th"])))
                if th > cr { bad(i, "Kant er tykkere end cirklen") }
            case 8:
                th = isNil(it["th"]) ? 2 : intOf(jsRound(number(it["th"]) ?? 0))
                if th < 1 || th > 12 { bad(i, "Linje: tykkelse 1-12") }
                if wd < 0 || ht < 0 || wd > 640 || ht > 640 || (wd == 0 && ht == 0) { bad(i, "Linje: længde skal være 1-640") }
            case 9:
                if wd < 16 || wd > 320 || ht < 12 || ht > 200 { bad(i, "Knap: bredde 16-320, højde 12-200") }
                if str == 255 { bad(i, "Knap skal have tekst") }
                if Double(th) > Double(min(wd, ht)) / 2 { bad(i, "Afrunding er for stor") }
                if font > 2 { bad(i, "Knap kan kun bruge skrift 1, 2 eller 4") }
            case 10:
                th = intOf(jsRound(numOr0(it["n"])))
                if !isNumeric(sv) { bad(i, "Segmenter skal have en talkilde") }
                if mx <= mn { bad(i, "max skal være større end min") }
                if th < 2 || th > 40 { bad(i, "Segmenter: 2-40") }
                if ht < 2 || ht > 100 || wd < th * 2 || wd > 320 { bad(i, "Segmenter: bredde (mindst 2 pr. segment) og højde 2-100") }
            case 11:
                th = isNil(it["th"]) ? 2 : intOf(jsRound(number(it["th"]) ?? 0))
                if !isNumeric(sv) { bad(i, "Graf skal have en talkilde") }
                if mx <= mn { bad(i, "max skal være større end min") }
                if wd < 16 || wd > 320 || ht < 8 || ht > 200 { bad(i, "Graf: bredde 16-320, højde 8-200") }
                if th < 1 || th > 6 { bad(i, "Graf: stregtykkelse 1-6") }
            case 12:
                let dr = intOf(jsRound(numOr0(it["r"]))); wd = dr; ht = 0
                if sv < 1 || sv > 23 || sv == sources["mode"]! { bad(i, "Prik skal have en kilde") }
                if dr < 2 || dr > 40 { bad(i, "Prik: radius 2-40") }
            case 13:
                let iconKey: String = isNil(it["icon"]) ? "bolt" : ((it["icon"] as? String) ?? "?")
                let ic = icons[iconKey]
                th = ic ?? 0
                wd = intOf(jsRound(numOr0(it["size"]))); ht = 0
                if ic == nil { bad(i, "Ukendt ikon") }
                if wd < 8 || wd > 96 { bad(i, "Ikon: størrelse 8-96") }
            default: break
            }
            if x < -200 || x > 520 || y < -200 || y > 520 { bad(i, "Ligger for langt uden for skærmen") }

            var showSrc = 0, showOp = 0, showVal = 0, warn = 0, badv = 0
            if truthy(it["show"]), let sh = it["show"] as? [String: Any] {
                showSrc = (sh["src"] as? String).flatMap { sources[$0] } ?? 0
                if showSrc == 0 || showSrc == sources["mode"]! { bad(i, "Vis kun når: ukendt kilde") }
                let opKey: String = isNil(sh["op"]) ? ">" : ((sh["op"] as? String) ?? "?")
                let op = ops[opKey] ?? 0
                if op == 0 { bad(i, "Vis kun når: ukendt sammenligning") } else { showOp = op }
                let sval: Any? = truthy(sh["val"]) ? sh["val"] : 0
                showVal = clampi(sval, -32768, 32767)
            } else if truthy(it["show"]) {
                bad(i, "Vis kun når: ukendt kilde")
            }
            if !isNil(it["warn"]) || !isNil(it["bad"]) {
                showOp |= 8
                let below = truthy(it["below"])
                if below { showOp |= 16 }
                warn = clampi(isNil(it["warn"]) ? (below ? -32768 : 32767) : it["warn"], -32768, 32767)
                badv = clampi(isNil(it["bad"]) ? (below ? -32768 : 32767) : it["bad"], -32768, 32767)
            }
            out.append(Packed(t: t, s: sv, color: color, color2: color2, font: font, al: al, dp: dp, pg: pg, str: str, str2: str2,
                              max: mx, min: mn, x: x, y: y, w: wd, h: ht, flags: flags, a0: a0, sw: sw, th: th,
                              showSrc: showSrc, showOp: showOp, showVal: showVal, warn: warn, bad: badv))
        }
        if !err.isEmpty { return Result(ok: false, bytes: [], errors: err, pages: pages) }

        let n = out.count
        let total = headerLen + strs.count * stringLen + cols.count * 2 + n * itemLen
        var b = [UInt8](repeating: 0, count: total)
        b[0] = 0x4E; b[1] = 0x57; b[2] = 2; b[3] = UInt8(truncatingIfNeeded: n); b[4] = UInt8(truncatingIfNeeded: strs.count)
        b[5] = UInt8(truncatingIfNeeded: cols.count); b[6] = UInt8(total & 255); b[7] = UInt8((total >> 8) & 255)
        b[8] = UInt8(pages); b[9] = UInt8(truncatingIfNeeded: bg)
        b[10] = (w["dots"] as? Bool) == false ? 0 : 1
        b[11] = 0
        for (i, s) in strs.enumerated() {
            for (k, u) in s.unicodeScalars.enumerated() { b[headerLen + i * stringLen + k] = UInt8(truncatingIfNeeded: u.value) }
        }
        let co = headerLen + strs.count * stringLen
        for (i, c) in cols.enumerated() { b[co + i * 2] = UInt8(c & 255); b[co + i * 2 + 1] = UInt8((c >> 8) & 255) }
        let o = co + cols.count * 2
        func p16(_ p: Int, _ v: Int) { let u = UInt16(truncatingIfNeeded: v); b[p] = UInt8(u & 255); b[p + 1] = UInt8(u >> 8) }
        for (i, it) in out.enumerated() {
            let p = o + i * itemLen
            b[p] = UInt8(truncatingIfNeeded: it.t); b[p + 1] = UInt8(truncatingIfNeeded: it.s); b[p + 2] = UInt8(truncatingIfNeeded: it.color)
            b[p + 3] = UInt8(truncatingIfNeeded: it.color2); b[p + 4] = UInt8(truncatingIfNeeded: it.font)
            b[p + 5] = UInt8(truncatingIfNeeded: it.al | (it.dp << 2) | (it.pg << 4))
            b[p + 6] = UInt8(truncatingIfNeeded: it.str); b[p + 7] = UInt8(truncatingIfNeeded: it.str2)
            p16(p + 8, it.max); p16(p + 10, it.min); p16(p + 12, it.x); p16(p + 14, it.y); p16(p + 16, it.w); p16(p + 18, it.h)
            b[p + 20] = UInt8(truncatingIfNeeded: it.flags); b[p + 21] = UInt8(truncatingIfNeeded: it.a0)
            b[p + 22] = UInt8(truncatingIfNeeded: it.sw); b[p + 23] = UInt8(truncatingIfNeeded: it.th)
            b[p + 24] = UInt8(truncatingIfNeeded: it.showSrc); b[p + 25] = UInt8(truncatingIfNeeded: it.showOp)
            p16(p + 26, it.showVal); p16(p + 28, it.warn); p16(p + 30, it.bad)
        }
        return Result(ok: true, bytes: b, errors: [], pages: pages)
    }

    /// Header and file-level checks used when a design is imported or shared.
    public static func validateFile(_ w: [String: Any]?) -> [String] {
        guard let w = w else { return ["Ikke et JSON-objekt"] }
        var e: [String] = []
        let v = number(w["v"])
        if v != 1 && v != 2 { e.append("v skal være 1 eller 2") }
        if let n = w["name"] as? String, n.count >= 2, n.count <= 24, isASCIIText(n) {} else { e.append("name: 2-24 almindelige tegn") }
        if let a = w["author"] as? String, a.count >= 1, a.count <= 24, isASCIIText(a) {} else { e.append("author: 1-24 almindelige tegn") }
        if !isNil(w["desc"]) { if let d = w["desc"] as? String, d.count <= 120 {} else { e.append("desc: højst 120 tegn") } }
        let c = compile(w)
        if !c.ok { e.append(contentsOf: c.errors) }
        return e
    }

    /// Parses JSON text into a design dictionary.
    public static func parse(json: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
    }
}
