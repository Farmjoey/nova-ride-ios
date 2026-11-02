import Foundation

/// Wire protocol between the phone app and the board (docs/APP_PROTOCOL.md). Same numbers as src/AppProtocol.h.
public enum Nova {
    public static let serviceUUID = "4E4F5641-5249-4445-0000-000000000001"
    public static let ctrlUUID = "4E4F5641-5249-4445-0000-000000000002"
    public static let dataUUID = "4E4F5641-5249-4445-0000-000000000003"
    public static let statUUID = "4E4F5641-5249-4445-0000-000000000004"
    public static let namePrefix = "NOVA RIDE"

    public static let bootImageBytes = 1024          // 128 x 64, 1 bit per pixel, row-major, MSB first
    public static let bootImageWidth = 128
    public static let bootImageHeight = 64
    public static let bootTextMax = 15
    public static let minAppBytes = 65536
    public static let maxAppBytes = 0x1E0000
    public static let layoutChunk = 120
    public static let imageChunk = 128
    public static let otaChunk = 160          // demo board / simulated link
    public static let wifiOtaChunk = 4096     // over the board's Wi-Fi
    public static let boardBaseURL = "http://192.168.4.1"
    public static let otaWindowBytes = 6144
}

/// First byte of a write to the CTRL characteristic.
public enum Op: UInt8 {
    case info = 0x01
    case otaBegin = 0x10, otaEnd = 0x11, otaAbort = 0x12
    case theme = 0x20, bootStyle = 0x21, bootText = 0x22
    case imgBegin = 0x23, imgChunk = 0x24, imgEnd = 0x25, preview = 0x26
    case music = 0x30
    case layoutBegin = 0x40, layoutChunk = 0x41, layoutEnd = 0x42, layoutUse = 0x43
    case startCap = 0x50, backlight = 0x51, arcMax = 0x52, accent = 0x53, live = 0x54
}

/// Flags byte of the INFO frame.
public struct BoardFlags: OptionSet {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let updateWindow = BoardFlags(rawValue: 1)
    public static let bootImage = BoardFlags(rawValue: 2)
    public static let phoneLinked = BoardFlags(rawValue: 4)
    public static let scooterLinked = BoardFlags(rawValue: 8)
    public static let customDesign = BoardFlags(rawValue: 16)
    public static let designStored = BoardFlags(rawValue: 32)
    public static let startCap = BoardFlags(rawValue: 64)
}

public struct BoardInfo: Equatable {
    public var proto: UInt8 = 1
    public var theme: Int = 0
    public var bootStyle: Int = 0
    public var flags: BoardFlags = []
    public var version = ""
    public var profile = ""
    public var bootText = ""
    /// Optional 4th text of newer firmware: "backlight,arc,r,g,b". The original firmware does not send it.
    public var extra: [Int]? = nil
    public init() {}
}

public enum OtaState: Int { case idle = 0, ready, receiving, verifying, done, error }

public struct OtaStatus: Equatable {
    public var state: OtaState
    public var error: Int
    public var received: Int
    public var total: Int
    public init(state: OtaState, error: Int, received: Int, total: Int) {
        self.state = state; self.error = error; self.received = received; self.total = total
    }
}

/// Live values from the board (answer to Op.live).
public struct LiveFrame: Equatable {
    public var valid: UInt8
    public var speed: Double, battery: Int, volt: Double, power: Int, current: Double
    public var temp: Int, motorTemp: Int, mode: Int, cap: Int, odometer: Double
    public func has(_ bit: UInt8) -> Bool { valid & bit != 0 }
    public static let speedBit: UInt8 = 1, batteryBit: UInt8 = 2, voltBit: UInt8 = 4, powerBit: UInt8 = 8
    public static let currentBit: UInt8 = 16, tempBit: UInt8 = 32, motorTempBit: UInt8 = 64, odoBit: UInt8 = 128
}

/// One frame from the STAT characteristic.
public enum Stat: Equatable {
    case info(BoardInfo)
    case ota(OtaStatus)
    case ack(op: UInt8, result: UInt8)
    case live(LiveFrame)
}

public enum Frames {
    /// Parses a STAT notification. Returns nil for anything that is not a complete, known frame (never guesses).
    public static func parse(_ d: [UInt8]) -> Stat? {
        guard let t = d.first else { return nil }
        switch t {
        case 0x01:
            guard d.count >= 5 else { return nil }
            var info = BoardInfo()
            info.proto = d[1]; info.theme = Int(d[2]); info.bootStyle = Int(d[3]); info.flags = BoardFlags(rawValue: d[4])
            var parts: [String] = []
            var cur: [UInt8] = []
            for b in d[5...] {
                if b == 0 { parts.append(String(decoding: cur, as: UTF8.self)); cur = [] } else { cur.append(b) }
            }
            if !cur.isEmpty { parts.append(String(decoding: cur, as: UTF8.self)) }
            info.version = parts.count > 0 ? parts[0] : ""
            info.profile = parts.count > 1 ? parts[1] : ""
            info.bootText = parts.count > 2 ? parts[2] : ""
            if parts.count > 3, !parts[3].isEmpty {
                let nums = parts[3].split(separator: ",").compactMap { Int($0) }
                if nums.count >= 5 { info.extra = Array(nums.prefix(5)) }
            }
            return .info(info)
        case 0x10:
            guard d.count >= 11, let s = OtaState(rawValue: Int(d[1])) else { return nil }
            return .ota(OtaStatus(state: s, error: Int(d[2]), received: Int(le32(d, 3)), total: Int(le32(d, 7))))
        case 0x30:
            guard d.count >= 3 else { return nil }
            return .ack(op: d[1], result: d[2])
        case 0x40:
            guard d.count >= 19 else { return nil }
            func i16(_ a: Int) -> Int { Int(Int16(bitPattern: UInt16(d[a]) | UInt16(d[a + 1]) << 8)) }
            func u16(_ a: Int) -> Int { Int(UInt16(d[a]) | UInt16(d[a + 1]) << 8) }
            return .live(LiveFrame(valid: d[1], speed: Double(u16(2)) / 10, battery: Int(d[4]), volt: Double(u16(5)) / 10,
                                   power: i16(7), current: Double(i16(9)) / 10, temp: Int(Int8(bitPattern: d[11])),
                                   motorTemp: Int(Int8(bitPattern: d[12])), mode: Int(d[13]), cap: Int(d[14]),
                                   odometer: Double(le32(d, 15)) / 10))
        default:
            return nil
        }
    }

    public static func le32(_ d: [UInt8], _ at: Int) -> UInt32 {
        UInt32(d[at]) | UInt32(d[at + 1]) << 8 | UInt32(d[at + 2]) << 16 | UInt32(d[at + 3]) << 24
    }
    public static func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 255), UInt8((v >> 8) & 255), UInt8((v >> 16) & 255), UInt8((v >> 24) & 255)]
    }

    // ---- command builders (what is written to CTRL / DATA)
    public static func command(_ op: Op, _ args: [UInt8] = []) -> [UInt8] { [op.rawValue] + args }
    public static func otaBegin(size: Int, crc: UInt32) -> [UInt8] { command(.otaBegin, le32(UInt32(size)) + le32(crc)) }
    public static func theme(_ i: Int) -> [UInt8] { command(.theme, [UInt8(clamping: i)]) }
    public static func bootStyle(_ i: Int) -> [UInt8] { command(.bootStyle, [UInt8(clamping: i)]) }
    public static func bootText(_ s: String) -> [UInt8] { command(.bootText, Array(sanitizeBootText(s).utf8)) }
    public static func startCap(_ on: Bool) -> [UInt8] { command(.startCap, [on ? 1 : 0]) }
    public static func backlight(_ pct: Int) -> [UInt8] { command(.backlight, [UInt8(clamping: min(100, max(10, pct)))]) }
    public static func arcMax(_ steps: Int) -> [UInt8] { command(.arcMax, [UInt8(clamping: min(24, max(0, steps)))]) }
    public static func accent(r: Int, g: Int, b: Int) -> [UInt8] { command(.accent, [UInt8(clamping: r), UInt8(clamping: g), UInt8(clamping: b)]) }
    public static func music(_ key: Int) -> [UInt8] { command(.music, [UInt8(clamping: key)]) }
    public static func layoutChunk(offset: Int, _ bytes: ArraySlice<UInt8>) -> [UInt8] {
        command(.layoutChunk, [UInt8(offset & 255), UInt8((offset >> 8) & 255)] + bytes)
    }
    public static func imageChunk(offset: Int, _ bytes: ArraySlice<UInt8>) -> [UInt8] {
        command(.imgChunk, [UInt8(offset & 255), UInt8((offset >> 8) & 255)] + bytes)
    }

    // ---- frames the board sends (used by the demo board; byte-identical to src/AppProtocol.h, checked in NovaChecks)
    public static func buildInfo(theme: Int, bootStyle: Int, flags: UInt8, version: String, profile: String, bootText: String, extra: String = "") -> [UInt8] {
        var f: [UInt8] = [0x01, 1, UInt8(clamping: theme), UInt8(clamping: bootStyle), flags]
        f.append(contentsOf: Array(version.utf8)); f.append(0)
        f.append(contentsOf: Array(profile.utf8)); f.append(0)
        f.append(contentsOf: Array(bootText.utf8)); f.append(0)
        if !extra.isEmpty { f.append(contentsOf: Array(extra.utf8)); f.append(0) }
        return f
    }
    public static func buildAck(op: UInt8, result: UInt8) -> [UInt8] { [0x30, op, result] }
    public static func buildOta(state: OtaState, error: Int, received: Int, total: Int) -> [UInt8] {
        var f: [UInt8] = [0x10, UInt8(state.rawValue), UInt8(clamping: error)]
        f.append(contentsOf: le32(UInt32(received)))
        f.append(contentsOf: le32(UInt32(total)))
        return f
    }
    public static func buildLive(valid: UInt8, speed10: Int, battery: Int, volt10: Int, power: Int, current10: Int, temp: Int, motorTemp: Int, mode: Int, cap: Int, odo10: Int) -> [UInt8] {
        func u16(_ v: Int) -> [UInt8] { let u = UInt16(truncatingIfNeeded: v); return [UInt8(u & 255), UInt8(u >> 8)] }
        var f: [UInt8] = [0x40, valid]
        f.append(contentsOf: u16(speed10))
        f.append(UInt8(clamping: battery))
        f.append(contentsOf: u16(volt10))
        f.append(contentsOf: u16(power))
        f.append(contentsOf: u16(current10))
        f.append(UInt8(bitPattern: Int8(clamping: temp)))
        f.append(UInt8(bitPattern: Int8(clamping: motorTemp)))
        f.append(UInt8(clamping: mode))
        f.append(UInt8(clamping: cap))
        f.append(contentsOf: le32(UInt32(truncatingIfNeeded: odo10)))
        return f
    }

    /// Board text: printable ASCII only, at most 15 characters.
    public static func sanitizeBootText(_ s: String) -> String {
        String(s.unicodeScalars.filter { $0.value >= 0x20 && $0.value <= 0x7E }.prefix(Nova.bootTextMax).map(Character.init))
    }
}

public enum OtaText {
    public static let errors = ["", "Opdateringsvinduet er lukket på boardet", "Løbehjulet kører", "Filstørrelsen accepteres ikke",
                                "Ikke en ESP32-firmware (.bin)", "CRC-fejl", "Skrivefejl i flash", "Kunne ikke starte opdatering",
                                "Dataoverløb – prøv igen", "Boardet er optaget", "Timeout"]
    public static func error(_ code: Int) -> String { code >= 0 && code < errors.count && code > 0 ? errors[code] : "Fejl på boardet" }
    public static let states = ["Klar", "Klar", "Sender…", "Kontrollerer…", "Færdig – genstarter", "Fejl"]
}
