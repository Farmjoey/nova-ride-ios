import Foundation
#if canImport(NovaCore)
import NovaCore
#endif

// Usage: swift run NovaChecks <repository root>
// Checks NovaCore (the iPhone app's logic) against reference answers produced by the web app's JavaScript and the
// firmware's C++ (ios/Tests/golden, made by tools/gen_ios_golden.py). Exit code 1 if anything differs.

var failures = 0
var passed = 0

func check(_ ok: Bool, _ what: @autoclosure () -> String) {
    if ok { passed += 1 } else { failures += 1; print("FAIL  \(what())") }
}

func hexBytes(_ h: String) -> [UInt8] {
    var out: [UInt8] = []
    var i = h.startIndex
    while i < h.endIndex {
        let j = h.index(i, offsetBy: 2)
        out.append(UInt8(h[i..<j], radix: 16) ?? 0)
        i = j
    }
    return out
}
func hexString(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined() }

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let golden = root.appendingPathComponent("ios/Tests/golden")
func loadJSON(_ name: String) -> Any {
    guard let d = try? Data(contentsOf: golden.appendingPathComponent(name)), let j = try? JSONSerialization.jsonObject(with: d) else {
        print("FAIL  cannot read \(name)"); exit(1)
    }
    return j
}

// ------------------------------------------------------------------ CRC-32 and firmware file checks
check(CRC32.checksum(Array("123456789".utf8)) == 0xCBF4_3926, "CRC-32 of 123456789")
check(CRC32.checksum([]) == 0, "CRC-32 of nothing")
do {
    var img = [UInt8](repeating: 0, count: 70000); img[0] = 0xE9
    check(Firmware.check(img, fileName: "NOVA_RIDE_cyd_st7789.bin").ok, "plain .bin accepted")
    check(!Firmware.check(img, fileName: "NOVA_RIDE_cyd_st7789.factory.bin").ok, ".factory.bin refused")
    check(!Firmware.check([UInt8](repeating: 0xE9, count: 100)).ok, "too small refused")
    var wrong = img; wrong[0] = 0x00
    check(!Firmware.check(wrong).ok, "wrong magic refused")
    var chip = img; chip[13] = 5
    check(!Firmware.check(chip).ok, "wrong chip refused")
    check(!Firmware.check([UInt8](repeating: 0xE9, count: Nova.maxAppBytes + 1)).ok, "too big refused")
}

// ------------------------------------------------------------------ commands (bytes written to the board)
check(Frames.otaBegin(size: 1_310_720, crc: 0xDEAD_BEEF) == [0x10, 0x00, 0x00, 0x14, 0x00, 0xEF, 0xBE, 0xAD, 0xDE], "OTA begin bytes")
check(Frames.theme(7) == [0x20, 7], "theme command")
check(Frames.startCap(true) == [0x50, 1] && Frames.startCap(false) == [0x50, 0], "start cap command")
check(Frames.backlight(5) == [0x51, 10] && Frames.backlight(500) == [0x51, 100], "backlight is limited to 10...100")
check(Frames.arcMax(99) == [0x52, 24], "arc scale is limited")
check(Frames.accent(r: 1, g: 2, b: 300) == [0x53, 1, 2, 255], "accent colour")
check(Frames.music(1) == [0x30, 1], "music command")
check(Frames.layoutChunk(offset: 300, [9, 8][...]) == [0x41, 0x2C, 0x01, 9, 8], "layout chunk header")
check(Frames.imageChunk(offset: 128, [1][...]) == [0x24, 0x80, 0x00, 1], "image chunk header")
check(Frames.bootText("Hej æøå verden 1234567890") == [0x22] + Array("Hej  verden 123".utf8), "boot text is ASCII and 15 characters")

// ------------------------------------------------------------------ STAT frames built by the firmware's C++
do {
    let f = loadJSON("frames.json") as! [String: String]
    func frame(_ k: String) -> [UInt8] { hexBytes(f[k]!) }
    if case .info(let i)? = Frames.parse(frame("info")) {
        check(i.theme == 6 && i.bootStyle == 2 && i.flags.rawValue == 0x4F && i.version == "1.4.0" && i.profile == "cyd_st7789" && i.bootText == "NOVA" && i.extra == nil, "INFO frame fields")
        check(i.flags.contains(.updateWindow) && i.flags.contains(.scooterLinked) && !i.flags.contains(.designStored), "INFO flags")
    } else { check(false, "INFO frame parses") }
    if case .info(let i)? = Frames.parse(frame("info_extra")) {
        check(i.theme == 7 && i.bootText == "" && i.extra == [80, 10, 111, 163, 168] && i.flags.rawValue == 0x21 && i.flags.contains(.designStored) && !i.flags.contains(.startCap), "INFO frame with extra text: \(i)")
    } else { check(false, "INFO(extra) parses") }
    check(Frames.parse(frame("ota_recv")) == .ota(OtaStatus(state: .receiving, error: 0, received: 12288, total: 1_310_720)), "OTA progress frame")
    check(Frames.parse(frame("ota_error")) == .ota(OtaStatus(state: .error, error: 5, received: 0, total: 65536)), "OTA error frame")
    check(Frames.parse(frame("ack_ok")) == .ack(op: 0x20, result: 0), "ACK ok")
    check(Frames.parse(frame("ack_nodata")) == .ack(op: 0x54, result: 3), "ACK no data")
    if case .live(let l)? = Frames.parse(frame("live_all")) {
        check(l.speed == 25.3 && l.battery == 60 && l.volt == 78.7 && l.power == -120 && l.current == -4.5 && l.temp == 47 && l.motorTemp == 58 && l.mode == 3 && l.cap == 1 && l.odometer == 20660, "live frame (all valid): \(l)")
    } else { check(false, "live frame parses") }
    if case .live(let l)? = Frames.parse(frame("live_partial")) {
        let v = LiveValues(frame: l, info: nil)
        check(v.speed == 0 && v.battery == 85 && v.volt == nil && v.power == nil && v.mode == nil && !v.limit, "live frame: invalid fields stay empty")
    } else { check(false, "partial live frame parses") }
    check(Frames.parse([]) == nil && Frames.parse([0x01]) == nil && Frames.parse([0x99, 1, 2]) == nil && Frames.parse([0x10, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0]) == nil, "garbage is rejected")
    let full = frame("live_all")
    var anyShortAccepted = false
    for n in 0..<(full.count - 1) where Frames.parse(Array(full.prefix(n))) != nil { anyShortAccepted = true }
    check(!anyShortAccepted, "truncated live frames are rejected")
}

// ------------------------------------------------------------------ widget compiler vs the JavaScript compiler
do {
    let cases = loadJSON("compile_errors.json") as! [String: [String: Any]]
    var n = 0
    for (name, c) in cases.sorted(by: { $0.key < $1.key }) {
        n += 1
        let design = c["design"] as? [String: Any]
        let r = Widget.compile(design)
        let wantOk = c["ok"] as! Bool
        check(r.ok == wantOk, "\(name): ok \(r.ok) vs JavaScript \(wantOk) errors \(r.errors)")
        let wantErr = c["errors"] as! [String]
        check(r.errors == wantErr, "\(name): errors \(r.errors) vs \(wantErr)")
        if wantOk {
            check(hexString(r.bytes) == (c["hex"] as! String), "\(name): bytes differ from the JavaScript compiler")
            check(r.pages == (c["pages"] as! Int), "\(name): page count")
        }
        let wantFile = c["file"] as! [String]
        check(Widget.validateFile(design) == wantFile, "\(name): file validation \(Widget.validateFile(design)) vs \(wantFile)")
    }
    check(n >= 40, "compile cases loaded (\(n))")
}

// ------------------------------------------------------------------ the bundled starter designs
do {
    let dir = root.appendingPathComponent("app/widgets/starter")
    let starters = StarterLibrary.load(directory: dir)
    check(starters.count == 11, "11 starter designs found (\(starters.count))")
    for s in starters {
        let r = Widget.compile(s.json)
        check(r.ok && r.bytes.count <= Widget.headerLen + Widget.maxStrings * Widget.stringLen + Widget.maxColors * 2 + Widget.maxItems * Widget.itemLen, "starter \(s.id) compiles: \(r.errors)")
        check(Widget.validateFile(s.json).isEmpty, "starter \(s.id) passes file validation: \(Widget.validateFile(s.json))")
    }
    check(starters.first?.id == "standard", "standard design is first")
}

// ------------------------------------------------------------------ boot picture packing
do {
    let g = loadJSON("bootimage.json") as! [String: Any]
    var gray = [UInt8]()
    for y in 0..<64 { for x in 0..<128 { gray.append(UInt8((x * 2 + y * 3) % 256)) } }
    for c in g["cases"] as! [[String: Any]] {
        let thr = c["thr"] as! Int, inv = c["inv"] as! Bool
        let bits = BootImage.pack(gray: gray, threshold: thr, invert: inv)
        check(hexString(bits) == (c["hex"] as! String), "boot picture threshold \(thr) invert \(inv)")
        check(bits.count == Nova.bootImageBytes, "boot picture size")
    }
    let bits = BootImage.pack(gray: gray, threshold: 128, invert: false)
    check(BootImage.pixel(bits, x: 127, y: 0) == (gray[127] > 128) && !BootImage.pixel(bits, x: 200, y: 0), "boot picture pixel access")
}

// ------------------------------------------------------------------ evaluation helpers vs the JavaScript library
do {
    let e = loadJSON("eval.json") as! [String: Any]
    var l = LiveValues()
    l.speed = 21.5; l.power = -120; l.battery = 15; l.volt = 78.7; l.current = nil; l.temp = 47; l.motortemp = nil
    l.trip = 12.4; l.total = 20660; l.fault = 0; l.maxspeed = 31.4; l.maxpower = 2650; l.minvolt = 71.2; l.energy = 148
    l.ridetime = 18; l.mode = 2; l.ble = true; l.phone = false; l.limit = true; l.demo = false
    for (src, want) in e["values"] as! [String: Any] {
        let got = l.value(src)
        if want is NSNull { check(got == nil, "value(\(src)) should be unavailable, got \(String(describing: got))") }
        else { check(got != nil && abs(got! - (want as! Double)) < 1e-9, "value(\(src)) = \(String(describing: got)) vs \(want)") }
    }
    for c in e["vis"] as! [[String: Any]] {
        var item: [String: Any] = ["show": c["show"]!]
        if (c["item_page"] as? String) == "all" { item["page"] = "all" }
        check(WidgetEval.isVisible(item, l, page: c["page"] as! Int) == (c["visible"] as! Bool), "visibility \(c)")
    }
    for c in e["pages"] as! [[String: Any]] {
        check(WidgetEval.isVisible(["page": c["page"]!], l, page: c["cur"] as! Int) == (c["visible"] as! Bool), "page visibility \(c)")
    }
    for c in e["sev"] as! [[String: Any]] {
        let v: Double? = (c["value"] is NSNull) ? nil : (c["value"] as! Double)
        let want = c["result"] as? String
        check(WidgetEval.severity(c["item"] as! [String: Any], value: v) == want, "colour rule \(c)")
    }
    for c in e["frac"] as! [[String: Any]] {
        let v: Double? = (c["value"] is NSNull) ? nil : (c["value"] as! Double)
        let got = WidgetEval.fraction(c["item"] as! [String: Any], v)
        check(abs(got - (c["result"] as! Double)) < 1e-12, "fraction \(c) got \(got)")
    }
    for c in e["fmt"] as! [[String: Any]] {
        let v: Double? = (c["value"] is NSNull) ? nil : (c["value"] as! Double)
        let got = WidgetEval.format(v, dp: c["dp"] as! Int)
        check(got == (c["result"] as! String), "number format \(c) got \(got)")
    }
}

// ------------------------------------------------------------------ themes vs src/Theme.h
do {
    let th = loadJSON("themes.json") as! [[String: Any]]
    check(th.count == NovaTheme.all.count, "theme count")
    func rgb(_ a: Any?) -> RGB { let v = a as! [Int]; return RGB(v[0], v[1], v[2]) }
    for (i, t) in th.enumerated() {
        let m = NovaTheme.all[i]
        check(m.name == (t["name"] as! String) && m.bg == rgb(t["bg"]) && m.panel == rgb(t["panel"]) && m.neon == rgb(t["neon"]) && m.glow == rgb(t["glow"])
              && m.dim == rgb(t["dim"]) && m.warn == rgb(t["warn"]) && m.ok == rgb(t["ok"]) && m.bad == rgb(t["bad"]) && m.text == rgb(t["text"]), "theme \(i) \(m.name) differs from src/Theme.h")
    }
    check(NovaTheme.at(7, accent: RGB(1, 2, 3)).neon == RGB(1, 2, 3) && NovaTheme.at(99).name == "CUSTOM", "custom theme takes the accent colour")
    check(RGB(hex: "#6fa3a8") == RGB(111, 163, 168) && RGB(hex: "6fa3a8") == nil && RGB(111, 163, 168).hex == "#6fa3a8", "hex colours")
}


// ------------------------------------------------------------------ frames built by Swift equal the firmware's C++ bytes
do {
    let f = loadJSON("frames.json") as! [String: String]
    check(hexString(Frames.buildInfo(theme: 6, bootStyle: 2, flags: 0x4F, version: "1.4.0", profile: "cyd_st7789", bootText: "NOVA")) == f["info"], "buildInfo bytes")
    check(hexString(Frames.buildInfo(theme: 7, bootStyle: 0, flags: 0x21, version: "1.4.0", profile: "cyd_st7789_basic", bootText: "", extra: "80,10,111,163,168")) == f["info_extra"], "buildInfo (extra) bytes")
    check(hexString(Frames.buildOta(state: .receiving, error: 0, received: 12288, total: 1_310_720)) == f["ota_recv"], "buildOta bytes")
    check(hexString(Frames.buildOta(state: .error, error: 5, received: 0, total: 65536)) == f["ota_error"], "buildOta error bytes")
    check(hexString(Frames.buildAck(op: 0x20, result: 0)) == f["ack_ok"] && hexString(Frames.buildAck(op: 0x54, result: 3)) == f["ack_nodata"], "buildAck bytes")
    check(hexString(Frames.buildLive(valid: 0xFF, speed10: 253, battery: 60, volt10: 787, power: -120, current10: -45, temp: 47, motorTemp: 58, mode: 3, cap: 1, odo10: 206600)) == f["live_all"], "buildLive bytes")
    check(hexString(Frames.buildLive(valid: 0x03, speed10: 0, battery: 85, volt10: 0, power: 0, current10: 0, temp: -5, motorTemp: 0, mode: 255, cap: 2, odo10: 0)) == f["live_partial"], "buildLive (partial) bytes")
}

// ------------------------------------------------------------------ the session logic against the simulated board
func sessionChecks() async {
    func fresh(extra: Bool = false) -> (BoardSession, DemoBoard) {
        let b = DemoBoard(); b.sendExtraInInfo = extra
        let s = BoardSession(link: b); s.ackTimeout = 1; s.infoRetryDelay = 0.05
        return (s, b)
    }
    func throwsMessage(_ body: () async throws -> Void) async -> String? {
        do { try await body(); return nil } catch { return (error as? SessionError).flatMap { e -> String? in if case .message(let m) = e { return m } else { return "\(e)" } } ?? "\(error)" }
    }

    // connect + commands
    do {
        let (s, _) = fresh()
        do { try await s.connect() } catch { check(false, "demo connect: \(error)") }
        check(s.connected && s.info?.version == "0.8.0 (demo)" && s.info?.theme == NovaTheme.defaultIndex, "connected, INFO received")
        try? await s.setTheme(2); check(s.info?.theme == 2, "theme changes")
        try? await s.setBootStyle(3); check(s.info?.bootStyle == 3, "boot style changes")
        try? await s.setBootText("Hello æ"); check(s.info?.bootText == "Hello ", "boot text sanitised")
        try? await s.setStartCap(true); check(s.info?.flags.contains(.startCap) == true, "start cap on")
        try? await s.setStartCap(false); check(s.info?.flags.contains(.startCap) == false, "start cap off")
        var refused: UInt8 = 0
        do { try await s.send([Op.theme.rawValue, 99]) } catch SessionError.refused(let r) { refused = r } catch {}
        check(refused == 1, "bad argument is refused (\(refused))")
        refused = 0
        do { try await s.send([0x77]) } catch SessionError.refused(let r) { refused = r } catch {}
        check(refused == 2, "unknown command is refused (\(refused))")
        // two commands at once
        async let a: Void = s.setTheme(4)
        async let b: Void = s.setBackLightSafe()
        _ = try? await a; _ = try? await b
        check(s.connected, "two commands in flight do not break the session")
        s.disconnect()
        check(!s.connected && s.info == nil, "disconnect clears state")
        let m = await throwsMessage { try await s.setTheme(1) }
        check(m != nil, "no commands after disconnect")
    }

    // settings read back from newer firmware
    do {
        let (s, _) = fresh(extra: true)
        try? await s.connect()
        check(s.info?.extra == [80, 0, 111, 163, 168], "extra settings from INFO")
        try? await s.setBacklight(40); try? await s.setArcMax(10); try? await s.setAccent(RGB(10, 20, 30))
        check(s.info?.extra == [40, 10, 10, 20, 30], "brightness, arc scale and accent read back: \(String(describing: s.info?.extra))")
        s.disconnect()
    }

    // design install
    do {
        let (s, board) = fresh()
        try? await s.connect()
        let std = StarterLibrary.load(directory: root.appendingPathComponent("app/widgets/starter")).first!
        let expected = Widget.compile(std.json).bytes.count
        do { try await s.installDesign(std.json) } catch { check(false, "install design: \(error)") }
        check(s.info?.flags.contains(.designStored) == true && s.info?.flags.contains(.customDesign) == true, "design stored and switched on")
        let chunks = (expected + Nova.layoutChunk - 1) / Nova.layoutChunk
        let want: [UInt8] = [0x01] + [0x40] + [UInt8](repeating: 0x41, count: chunks) + [0x42, 0x01]
        check(board.log == want, "install sequence begin/chunks/end/INFO (\(board.log.count) vs \(want.count))")
        try? await s.useOwnDesign(false)
        check(s.info?.flags.contains(.customDesign) == false && s.info?.flags.contains(.designStored) == true, "standard design can be shown again")
        let bad = await throwsMessage { try await s.installDesign(["v": 2, "items": [["t": "arc", "x": 1, "y": 1, "r": 5, "th": 9, "src": "speed", "max": 10]]]) }
        check(bad == "Element 1: Bue: radius 8-160, tykkelse 1 til under radius", "invalid design is rejected with the compiler's message: \(String(describing: bad))")
        s.disconnect()
    }

    // boot picture
    do {
        let (s, _) = fresh()
        try? await s.connect()
        var gray = [UInt8](); for i in 0..<(128 * 64) { gray.append(UInt8(i % 256)) }
        try? await s.sendBootImage(BootImage.pack(gray: gray, threshold: 100, invert: false))
        check(s.info?.flags.contains(.bootImage) == true, "boot picture stored")
        let m = await throwsMessage { try await s.sendBootImage([1, 2, 3]) }
        check(m != nil, "wrong picture size refused")
        s.disconnect()
    }

    // time-out and pairing retries
    do {
        let (s, b) = fresh()
        try? await s.connect()
        s.ackTimeout = 0.2; b.mute = true
        var timedOut = false
        do { try await s.setTheme(1) } catch SessionError.noAnswer { timedOut = true } catch {}
        check(timedOut, "no answer => time-out error")
        s.disconnect()

        let (s2, b2) = fresh(); b2.failWrites = 2
        var hints = 0
        s2.onStatus = { _ in hints += 1 }
        do { try await s2.connect(); check(s2.connected && s2.info != nil, "connects after two failed first writes") } catch { check(false, "retry connect: \(error)") }
        check(hints == 2, "user is told to accept the pairing request (\(hints) hints)")
        s2.disconnect()

        let (s3, b3) = fresh(); b3.failWrites = 1000; s3.infoAttempts = 3
        let m = await throwsMessage { try await s3.connect() }
        check(m?.contains("Ingen forbindelse til boardet") == true && !s3.connected, "gives up with a clear message: \(String(describing: m))")
    }

    // live data
    do {
        let (s, _) = fresh()
        try? await s.connect()
        try? await s.setStartCap(true)
        s.startPolling(interval: 0.08)
        try? await Task.sleep(nanoseconds: 700_000_000)
        s.stopPolling()
        check(s.live != nil && (s.live?.speed ?? 99) <= 20.0 && s.live?.battery != nil && s.live?.limit == true, "live data arrives, capped at 20 km/h with the start cap on: \(String(describing: s.live?.speed))")
        s.disconnect()
    }

    // firmware update
    do {
        var image = [UInt8](); var x: UInt32 = 12345
        for _ in 0..<70000 { x = x &* 1664525 &+ 1013904223; image.append(UInt8(x >> 24)) }
        image[0] = 0xE9; image[12] = 0; image[13] = 0
        let (s, _) = fresh()
        try? await s.connect()
        var calls = 0
        do { try await s.updateFirmware(image, progress: { _ in calls += 1 }); check(s.ota.state == .done && s.ota.total == 70000, "update completes (\(s.ota.state))") }
        catch { check(false, "update: \(error)") }
        check(calls > 100, "progress is reported (\(calls))")
        s.disconnect()

        let (s2, b2) = fresh(); b2.corruptFirmware = true
        try? await s2.connect()
        let m = await throwsMessage { try await s2.updateFirmware(image) }
        check(m == "CRC-fejl", "corrupted image is caught by the board's CRC check: \(String(describing: m))")
        s2.disconnect()

        let (s3, b3) = fresh(); b3.windowOpen = false
        try? await s3.connect()
        let m3 = await throwsMessage { try await s3.updateFirmware(image) }
        check(m3 == "Opdateringsvinduet er lukket på boardet", "closed update window explained: \(String(describing: m3))")
        s3.disconnect()

        let (s4, _) = fresh()
        try? await s4.connect()
        var wrong = image; wrong[0] = 0x00
        let m4 = await throwsMessage { try await s4.updateFirmware(wrong) }
        check(m4 == "Ikke en ESP32-firmware (.bin)", "wrong file refused before anything is sent: \(String(describing: m4))")
        s4.disconnect()
    }
}
await sessionChecks()

// ------------------------------------------------------------------ the HTTP transport against a stand-in for the board's web server
func httpChecks() async {
    guard let url = ProcessInfo.processInfo.environment["NOVA_FAKE_BOARD"], let base = URL(string: url) else {
        print("(HTTP checks skipped: set NOVA_FAKE_BOARD, run_host_tests.sh does)"); return
    }
    let link = HttpLink(base: base)
    let session = BoardSession(link: link)
    session.ackTimeout = 3
    do { try await session.connect() } catch { check(false, "HTTP connect: \(error)") }
    check(session.connected && session.info?.version == "1.4.0" && session.info?.profile == "cyd_st7789", "connected over HTTP; INFO decoded from the board's own frame")
    check(link.dataChunk == Nova.wifiOtaChunk, "firmware goes in big blocks over Wi-Fi")
    do { try await session.setTheme(2); check(true, "") } catch { check(false, "theme over HTTP: \(error)") }
    var refused: UInt8 = 0
    do { try await session.send([0x77]) } catch SessionError.refused(let r) { refused = r } catch {}
    check(refused == 2, "an unknown command is refused with the board's own answer (\(refused))")
    await session.fetchLive()
    check(session.live?.speed == 25.3 && session.live?.battery == 60, "live data over HTTP")
    // the commands really arrived as POSTs with the right bytes
    if let d = try? Data(contentsOf: base.appendingPathComponent("log")), let log = (try? JSONSerialization.jsonObject(with: d)) as? [[Any]] {
        let ctrl = log.filter { ($0[0] as? String) == "/api/ctrl" }
        check(ctrl.contains { ($0[1] as? [Int]) == [0x20, 2] }, "theme command arrived as POST /api/ctrl [20 02]")
        check(ctrl.contains { ($0[1] as? [Int]) == [0x54] }, "live request arrived as POST /api/ctrl [54]")
    } else { check(false, "could not read the stand-in board's log") }
    try? await link.writeData([1, 2, 3])
    check(session.ota.state == .receiving, "a data block returns the update status")
    session.disconnect()
    check(!session.connected, "disconnected")
    // nobody home: a clear message, not a hang
    let dead = BoardSession(link: HttpLink(base: URL(string: "http://127.0.0.1:1")!))
    dead.infoAttempts = 1
    var msg = ""
    do { try await dead.connect() } catch { msg = error.localizedDescription }
    check(msg.contains("Ingen forbindelse til boardet"), "unreachable board gives a clear message: \(msg)")
}
await httpChecks()


print("\(passed) checks passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
