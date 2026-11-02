import Foundation

/// A simulated board that speaks the real protocol. Used for the app's demo mode (no hardware needed) and in tests.
public final class DemoBoard: BoardLink {
    public var onStat: (([UInt8]) -> Void)?
    public var onClose: (() -> Void)?

    // behaviour switches for tests
    public var replyDelay: UInt64 = 20_000_000          // ns before a reply arrives
    public var sendExtraInInfo = false                  // newer firmware: 4th INFO text with backlight/arc/accent
    public var windowOpen = true                        // firmware update window
    public var corruptFirmware = false                  // flips a byte so the CRC check fails
    public var mute = false                             // never answers (tests ACK time-outs)
    public var failWrites = 0                           // fail this many CTRL writes first (tests pairing retries)
    public private(set) var log: [UInt8] = []           // opcodes received on CTRL, in order

    private let lock = NSLock()
    private var theme = NovaTheme.defaultIndex, bootStyle = 0, bootText = "", imageStored = false
    private var layoutStored = false, layoutOn = false, startCap = false, backlight = 80, arcMax = 0
    private var accent = [111, 163, 168]
    private var imageBuf: [UInt8] = [], layoutBuf: [UInt8] = []
    private var otaState: OtaState = .idle, otaTotal = 0, otaCrc: UInt32 = 0, otaData: [UInt8] = [], otaReported = 0
    private var started = Date()
    private var connected = false

    public init() {}

    public func connect() async throws {
        try? await Task.sleep(nanoseconds: 100_000_000)
        lock.lock(); connected = true; started = Date(); lock.unlock()
    }

    public func disconnect() {
        lock.lock(); connected = false; lock.unlock()
        onClose?()
    }

    private func emit(_ bytes: [UInt8]) {
        if mute { return }
        let d = replyDelay
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: d)
            self?.onStat?(bytes)
        }
    }

    public var infoFrame: [UInt8] {
        lock.lock(); defer { lock.unlock() }
        var flags: UInt8 = 1 | 4 | 8
        if imageStored { flags |= 2 }
        if layoutOn { flags |= 16 }
        if layoutStored { flags |= 32 }
        if startCap { flags |= 64 }
        let extra = sendExtraInInfo ? "\(backlight),\(arcMax),\(accent[0]),\(accent[1]),\(accent[2])" : ""
        return Frames.buildInfo(theme: theme, bootStyle: bootStyle, flags: flags, version: "0.8.0 (demo)", profile: "demo", bootText: bootText, extra: extra)
    }

    private func liveFrame() -> [UInt8] {
        lock.lock(); let t = Date().timeIntervalSince(started); let cap = startCap; lock.unlock()
        var sp = 14 + 12 * sin(t * 0.5)
        if cap && sp > 20 { sp = 20 }
        let pct = max(5, Int((86 - t * 0.05).rounded()))
        let pw = Int((sp * 58 + 120 * sin(t)).rounded())
        let v = 67.5 + Double(pct) * 0.19
        return Frames.buildLive(valid: 0xFF, speed10: Int((sp * 10).rounded()), battery: pct, volt10: Int((v * 10).rounded()), power: pw,
                                current10: Int((Double(pw) / v * 10).rounded()), temp: Int((34 + sp * 0.5).rounded()), motorTemp: Int((45 + sp * 0.5).rounded()),
                                mode: 2, cap: cap ? 1 : 0, odo10: 206600)
    }

    public func writeCtrl(_ b: [UInt8]) async throws {
        lock.lock()
        if failWrites > 0 { failWrites -= 1; lock.unlock(); throw SessionError.message("Forbindelsen kræver parring") }
        lock.unlock()
        guard let opByte = b.first else { return }
        lock.lock(); log.append(opByte); lock.unlock()
        guard let op = Op(rawValue: opByte) else { emit(Frames.buildAck(op: opByte, result: 2)); return }
        func ack(_ r: UInt8 = 0) { emit(Frames.buildAck(op: opByte, result: r)) }
        lock.lock()
        switch op {
        case .info:
            lock.unlock(); emit(infoFrame); return
        case .theme:
            if b.count >= 2 && Int(b[1]) < NovaTheme.all.count { theme = Int(b[1]); lock.unlock(); ack() } else { lock.unlock(); ack(1) }
        case .bootStyle:
            if b.count >= 2 && b[1] < 4 { bootStyle = Int(b[1]); lock.unlock(); ack() } else { lock.unlock(); ack(1) }
        case .bootText:
            bootText = String(decoding: b.dropFirst().prefix(Nova.bootTextMax), as: UTF8.self); lock.unlock(); ack()
        case .imgBegin:
            imageBuf = []; lock.unlock(); ack()
        case .imgChunk:
            if b.count >= 3 { imageBuf.append(contentsOf: b.dropFirst(3)) }
            lock.unlock(); ack()
        case .imgEnd:
            let ok = imageBuf.count == Nova.bootImageBytes
            if ok { imageStored = true }
            lock.unlock(); ack(ok ? 0 : 3)
        case .preview, .music:
            lock.unlock(); ack()
        case .layoutBegin:
            layoutBuf = []; lock.unlock(); ack()
        case .layoutChunk:
            var res: UInt8 = 0
            if b.count >= 3 {
                let off = Int(b[1]) | Int(b[2]) << 8
                if off == layoutBuf.count { layoutBuf.append(contentsOf: b.dropFirst(3)) } else { res = 1 }
            } else { res = 1 }
            lock.unlock(); ack(res)
        case .layoutEnd:
            let l = layoutBuf
            let ok = l.count >= 12 && l[0] == 0x4E && l[1] == 0x57 && (l[2] == 1 || l[2] == 2) && l.count <= Widget.headerLen + Widget.maxStrings * Widget.stringLen + Widget.maxColors * 2 + Widget.maxItems * Widget.itemLen
                && (l[2] == 1 || (Int(l[6]) | Int(l[7]) << 8) == l.count)
            if ok { layoutStored = true; layoutOn = true }
            lock.unlock(); ack(ok ? 0 : 3)
        case .layoutUse:
            if b.count >= 2 && b[1] < 2 && (b[1] == 0 || layoutStored) { layoutOn = b[1] == 1; lock.unlock(); ack() } else { lock.unlock(); ack(1) }
        case .startCap:
            if b.count >= 2 && b[1] < 2 { startCap = b[1] == 1; lock.unlock(); ack() } else { lock.unlock(); ack(1) }
        case .backlight:
            if b.count >= 2 && b[1] >= 10 && b[1] <= 100 { backlight = Int(b[1]); lock.unlock(); ack() } else { lock.unlock(); ack(1) }
        case .arcMax:
            if b.count >= 2 && b[1] <= 24 { arcMax = Int(b[1]); lock.unlock(); ack() } else { lock.unlock(); ack(1) }
        case .accent:
            if b.count >= 4 { accent = [Int(b[1]), Int(b[2]), Int(b[3])]; lock.unlock(); ack() } else { lock.unlock(); ack(1) }
        case .live:
            lock.unlock(); emit(liveFrame())
        case .otaBegin:
            otaData = []; otaReported = 0
            if !windowOpen { otaState = .error; lock.unlock(); emit(Frames.buildOta(state: .error, error: 1, received: 0, total: 0)); return }
            if b.count >= 9 {
                let size = Int(Frames.le32(b, 1)); otaCrc = Frames.le32(b, 5); otaTotal = size
                if size < Nova.minAppBytes || size > Nova.maxAppBytes { otaState = .error; lock.unlock(); emit(Frames.buildOta(state: .error, error: 3, received: 0, total: size)); return }
                otaState = .receiving; lock.unlock(); emit(Frames.buildOta(state: .receiving, error: 0, received: 0, total: size))
            } else { otaState = .error; lock.unlock(); emit(Frames.buildOta(state: .error, error: 3, received: 0, total: 0)) }
        case .otaEnd:
            lock.unlock()
        case .otaAbort:
            otaState = .idle; otaData = []; lock.unlock(); emit(Frames.buildOta(state: .idle, error: 0, received: 0, total: 0))
        }
    }

    public func writeData(_ bytes: [UInt8]) async throws {
        lock.lock()
        guard otaState == .receiving else { lock.unlock(); return }
        otaData.append(contentsOf: bytes)
        let got = otaData.count, total = otaTotal
        var report = false
        if got - otaReported >= 4096 || got >= total { otaReported = got; report = true }
        let finished = got >= total
        if finished { otaState = .verifying }
        lock.unlock()
        if report { emit(Frames.buildOta(state: finished ? .verifying : .receiving, error: 0, received: min(got, total), total: total)) }
        if finished {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard let self = self else { return }
                self.lock.lock()
                var data = self.otaData
                if self.corruptFirmware, !data.isEmpty { data[data.count / 2] ^= 0xFF }
                let good = CRC32.checksum(data) == self.otaCrc
                self.otaState = good ? .done : .error
                let total = self.otaTotal
                self.lock.unlock()
                self.emit(Frames.buildOta(state: good ? .done : .error, error: good ? 0 : 5, received: total, total: total))
            }
        }
    }
}
