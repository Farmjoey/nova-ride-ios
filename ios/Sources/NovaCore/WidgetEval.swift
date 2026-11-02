import Foundation

/// Values a design can show. nil = not available (never invented).
public struct LiveValues {
    public var speed: Double?, power: Double?, battery: Double?, volt: Double?, current: Double?, temp: Double?, motortemp: Double?
    public var trip: Double?, total: Double?, fault: Double?, maxspeed: Double?, maxpower: Double?, minvolt: Double?
    public var energy: Double?, ridetime: Double?
    public var mode: Int?                    // 0 walk, 1 eco, 2 drive, 3 sport
    public var ble = false, phone = false, limit = false, demo = false
    public init() {}

    /// Port of `valueOf` in app/widgetlib.js.
    public func value(_ src: String?) -> Double? {
        switch src ?? "none" {
        case "speed": return speed
        case "power": return power
        case "battery": return battery
        case "volt": return volt
        case "current": return current
        case "temp": return temp
        case "motortemp": return motortemp
        case "trip": return trip
        case "total": return total
        case "fault": return fault
        case "maxspeed": return maxspeed
        case "maxpower": return maxpower
        case "minvolt": return minvolt
        case "energy": return energy
        case "ridetime": return ridetime
        case "mode": return mode.map(Double.init)
        case "ble": return ble ? 1 : 0
        case "phone": return phone ? 1 : 0
        case "limit": return limit ? 1 : 0
        case "demo": return demo ? 1 : 0
        case "alert": return (fault ?? 0) != 0 ? 1 : 0
        case "regen": return (power ?? 0) < 0 && power != nil ? 1 : 0
        case "moving": return (speed ?? 0) > 1 && speed != nil ? 1 : 0
        default: return nil
        }
    }

    /// Animated sample data (same model as `sample()` in the web app).
    public static func sample(t: Double, still: Bool = false, limit: Bool = false) -> LiveValues {
        var v = LiveValues()
        let sp = still ? 1 : 17 + 14 * sin(t * 0.5)
        let pw = still ? 1890 : (sp * 62 + 140 * sin(t * 1.3)).rounded()
        let pct = still ? 60 : Double(max(8, Int((86 - t * 0.2).rounded()) % 100))
        let volts = still ? 78.7 : 67.5 + pct * 0.19
        v.speed = sp; v.power = pw; v.battery = pct; v.volt = volts; v.current = still ? 22 : pw / volts
        v.temp = 40 + sp * 0.5; v.motortemp = 52 + sp * 0.6; v.trip = 12.4 + t * 0.01; v.total = 20660; v.fault = 0
        v.maxspeed = max(sp, 31.4); v.maxpower = max(pw, 2650); v.minvolt = 71.2; v.energy = 148 + t * 0.4
        v.ridetime = 18 + (t / 60).rounded(.down); v.mode = 2
        v.ble = true; v.phone = sin(t * 0.2) > -0.3; v.limit = limit; v.demo = true
        return v
    }

    /// From a live frame sent by the board (invalid fields stay nil).
    public init(frame f: LiveFrame, info: BoardInfo?) {
        self.init()
        if f.has(LiveFrame.speedBit) { speed = f.speed }
        if f.has(LiveFrame.batteryBit) { battery = Double(f.battery) }
        if f.has(LiveFrame.voltBit) { volt = f.volt }
        if f.has(LiveFrame.powerBit) { power = Double(f.power) }
        if f.has(LiveFrame.currentBit) { current = f.current }
        if f.has(LiveFrame.tempBit) { temp = Double(f.temp) }
        if f.has(LiveFrame.motorTempBit) { motortemp = Double(f.motorTemp) }
        if f.has(LiveFrame.odoBit) { total = f.odometer }
        mode = (0...3).contains(f.mode) ? f.mode : nil
        limit = f.cap == 1
        ble = info?.flags.contains(.scooterLinked) ?? false
        phone = info?.flags.contains(.phoneLinked) ?? false
    }
}

public enum WidgetEval {
    /// Port of `isVisible`.
    public static func isVisible(_ it: [String: Any], _ l: LiveValues, page: Int) -> Bool {
        var pg = 15
        if let p = it["page"] {
            if (p as? String) == "all" { pg = 15 } else if let n = Widget.number(p) { pg = Int(n) }
        }
        if pg != 15 && pg != page { return false }
        guard let sh = it["show"] as? [String: Any] else { return true }
        guard let v = l.value(sh["src"] as? String) else { return false }
        let c = Widget.numOr0(sh["val"])
        switch (sh["op"] as? String) ?? ">" {
        case ">": return v > c
        case "<": return v < c
        case "==": return v == c
        case "!=": return v != c
        case ">=": return v >= c
        case "<=": return v <= c
        default: return true
        }
    }

    /// Port of `ruleColor`: nil = keep the normal colour, otherwise "warn" or "bad".
    public static func severity(_ it: [String: Any], value v: Double?) -> String? {
        guard let v = v else { return nil }
        let warn = Widget.isNil(it["warn"]) ? nil : Widget.number(it["warn"])
        let badV = Widget.isNil(it["bad"]) ? nil : Widget.number(it["bad"])
        if warn == nil && badV == nil { return nil }
        let below = Widget.truthy(it["below"])
        if let b = badV, below ? v <= b : v >= b { return "bad" }
        if let w = warn, below ? v <= w : v >= w { return "warn" }
        return nil
    }

    /// Port of `frac`.
    public static func fraction(_ it: [String: Any], _ v: Double?) -> Double {
        guard let v = v else { return 0 }
        let mn = Widget.numOr0(it["min"])
        var mx = Widget.numOr0(it["max"]); if mx == 0 { mx = 1 }
        let f = (v - mn) / (mx - mn)
        return f < 0 ? 0 : (f > 1 ? 1 : f)
    }

    /// Port of `fmt`.
    public static func format(_ v: Double?, dp: Int) -> String {
        guard let v = v else { return "--" }
        if dp > 0 { return String(format: "%.\(dp)f", v) }
        return String(Int(Widget.jsRound(v)))
    }
}

/// Recent values per source for `spark` (graph) elements: the board keeps 60 samples, one every 2 seconds.
public struct WidgetHistory {
    public var series: [String: [Double]] = [:]
    public init() {}
    public static let sources = ["speed", "power", "battery", "volt", "current", "temp", "motortemp", "trip", "total",
                                 "maxspeed", "maxpower", "minvolt", "energy", "ridetime"]

    /// Adds one sample (call about every 2 seconds), keeping the newest 60.
    public mutating func add(_ v: LiveValues) {
        for s in WidgetHistory.sources {
            var a = series[s] ?? []
            a.append(v.value(s) ?? 0)
            if a.count > 60 { a.removeFirst(a.count - 60) }
            series[s] = a
        }
    }

    /// Made-up history for previews of designs (clearly sample data).
    public static func sample(count: Int = 60) -> WidgetHistory {
        var h = WidgetHistory()
        for i in 0..<count { h.add(LiveValues.sample(t: Double(i) * 0.7)) }
        return h
    }
}
