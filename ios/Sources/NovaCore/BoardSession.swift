import Foundation

/// Everything the app does with a connected board, independent of screens and of the network: connecting,
/// commands with acknowledgements, live data, boot picture, design install and firmware update.
/// (The web app does the same in index.template.html; this is the native version.)
public final class BoardSession {
    public let link: BoardLink
    public private(set) var connected = false
    public private(set) var info: BoardInfo?
    public private(set) var live: LiveValues?
    public private(set) var ota = OtaStatus(state: .idle, error: 0, received: 0, total: 0)

    /// Called after anything visible changed (UI refresh).
    public var onChange: (() -> Void)?
    /// A short progress/hint line for the user (pairing prompts, upload progress).
    public var onStatus: ((String) -> Void)?

    // tunables (tests shorten them)
    public var ackTimeout: TimeInterval = 4
    public var infoAttempts = 4
    public var infoRetryDelay: TimeInterval = 1.5

    private let lock = NSLock()
    // Everyone waiting for an answer, per opcode, oldest first. Replies come back in the order requests were sent, so a reply
    // resolves the oldest waiter of its opcode. (A single slot per opcode lost answers when two requests overlapped.)
    private var waiters: [UInt8: [(id: Int, cb: (Result<UInt8, Error>) -> Void)]] = [:]
    private var nextWaiter = 0
    private var busyCount = 0
    private var polling: Task<Void, Never>?

    public init(link: BoardLink) { self.link = link }

    public var isBusy: Bool { lock.lock(); defer { lock.unlock() }; return busyCount > 0 }
    private func busy(_ on: Bool) { lock.lock(); busyCount += on ? 1 : -1; lock.unlock() }

    // MARK: connect

    /// Connects, then sends INFO until the board answers. The first write makes the phone pair (the user must accept the
    /// pairing request), so this retries for about 40 seconds and tells the user what to do.
    public func connect() async throws {
        link.onStat = { [weak self] d in self?.handle(d) }
        link.onClose = { [weak self] in self?.closed() }
        try await link.connect()
        connected = true
        onChange?()
        let start = Date()
        var last: Error = SessionError.noAnswer
        for k in 0..<max(1, infoAttempts) {
            do { try await requestInfo(); return }
            catch {
                last = error
                onStatus?("Forbinder til boardet… (\(Int(Date().timeIntervalSince(start))) s)")
                if k < infoAttempts - 1 { try? await Task.sleep(nanoseconds: UInt64(infoRetryDelay * 1e9)) }
            }
        }
        link.disconnect()
        connected = false
        onChange?()
        throw SessionError.message("Ingen forbindelse til boardet. Er telefonen på Wi-Fi-netværket NOVA RIDE (se QR-koden under Settings > PHONE APP på boardet)? [\(last.localizedDescription)]")
    }

    public func disconnect() {
        stopPolling()
        link.disconnect()
        closed()
    }

    private func closed() {
        stopPolling()
        let was = connected
        connected = false; info = nil; live = nil
        lock.lock(); let all = waiters; waiters = [:]; lock.unlock()
        for (_, list) in all { for w in list { w.cb(.failure(SessionError.notConnected)) } }
        if was { onChange?() }
    }

    // MARK: frames from the board

    func handle(_ d: [UInt8]) {
        guard let s = Frames.parse(d) else { return }
        switch s {
        case .info(let i):
            info = i
            finish(Op.info.rawValue, .success(0))
            onChange?()
        case .ack(let op, let res):
            finish(op, .success(res))
        case .ota(let o):
            ota = o
            onChange?()
        case .live(let f):
            live = LiveValues(frame: f, info: info)
            finish(Op.live.rawValue, .success(0))
            onChange?()
        }
    }

    /// A reply arrived: resolve the oldest waiter of this opcode.
    private func finish(_ op: UInt8, _ r: Result<UInt8, Error>) {
        lock.lock()
        var cb: ((Result<UInt8, Error>) -> Void)?
        if var list = waiters[op], !list.isEmpty { cb = list.removeFirst().cb; waiters[op] = list.isEmpty ? nil : list }
        lock.unlock()
        cb?(r)
    }

    /// A specific waiter gave up (time-out or the write failed). Does nothing if it was already answered.
    private func expire(_ op: UInt8, _ id: Int, _ error: Error) {
        lock.lock()
        var cb: ((Result<UInt8, Error>) -> Void)?
        if var list = waiters[op], let i = list.firstIndex(where: { $0.id == id }) { cb = list.remove(at: i).cb; waiters[op] = list.isEmpty ? nil : list }
        lock.unlock()
        cb?(.failure(error))
    }

    // MARK: commands

    /// Writes a command and waits for the board's acknowledgement (INFO and LIVE are answered by their own frames).
    @discardableResult
    public func send(_ bytes: [UInt8]) async throws -> UInt8 {
        guard connected, let op = bytes.first else { throw SessionError.notConnected }
        let timeout = ackTimeout
        let res: UInt8 = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UInt8, Error>) in
            lock.lock()
            nextWaiter += 1
            let id = nextWaiter
            waiters[op, default: []].append((id: id, cb: { r in cont.resume(with: r) }))
            lock.unlock()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1e9))
                self?.expire(op, id, SessionError.noAnswer)
            }
            Task { [weak self] in
                guard let self = self else { return }
                do { try await self.link.writeCtrl(bytes) } catch { self.expire(op, id, error) }
            }
        }
        if res != 0 && op != Op.live.rawValue { throw SessionError.refused(res) }
        return res
    }

    public func requestInfo() async throws { try await send(Frames.command(.info)) }

    /// Sends a command and then refreshes INFO so the screen shows what the board really has now.
    public func apply(_ bytes: [UInt8]) async throws {
        try await send(bytes)
        try await requestInfo()
    }

    public func setTheme(_ i: Int) async throws { try await apply(Frames.theme(i)) }
    public func setBootStyle(_ i: Int) async throws { try await apply(Frames.bootStyle(i)) }
    public func setBootText(_ s: String) async throws { try await apply(Frames.bootText(s)) }
    public func setStartCap(_ on: Bool) async throws { try await apply(Frames.startCap(on)) }
    public func setBacklight(_ pct: Int) async throws { try await apply(Frames.backlight(pct)) }
    public func setBackLightSafe() async throws { try await apply(Frames.backlight(60)) }
    public func setArcMax(_ steps: Int) async throws { try await apply(Frames.arcMax(steps)) }
    public func setAccent(_ c: RGB) async throws { try await apply(Frames.accent(r: c.r, g: c.g, b: c.b)) }
    public func useOwnDesign(_ on: Bool) async throws { try await apply(Frames.command(.layoutUse, [on ? 1 : 0])) }
    public func previewBoot() async throws { try await send(Frames.command(.preview)) }
    public func music(_ key: Int) async throws { try await send(Frames.music(key)) }

    /// Compiles and installs a design on the board (docs/WIDGETS.md). Throws the compiler's first message if it is invalid.
    public func installDesign(_ json: [String: Any]) async throws {
        let c = Widget.compile(json)
        guard c.ok else { throw SessionError.message(c.errors.first ?? "Ugyldigt design") }
        busy(true); defer { busy(false) }
        try await send(Frames.command(.layoutBegin))
        var off = 0
        while off < c.bytes.count {
            let end = min(c.bytes.count, off + Nova.layoutChunk)
            try await send(Frames.layoutChunk(offset: off, c.bytes[off..<end]))
            off = end
            onStatus?("Sender design… \(off * 100 / c.bytes.count) %")
        }
        try await send(Frames.command(.layoutEnd))
        try await requestInfo()
    }

    /// Sends the packed 128x64 boot picture (1024 bytes).
    public func sendBootImage(_ bits: [UInt8]) async throws {
        guard bits.count == Nova.bootImageBytes else { throw SessionError.message("Billedet har forkert størrelse") }
        busy(true); defer { busy(false) }
        try await send(Frames.command(.imgBegin))
        var off = 0
        while off < bits.count {
            try await send(Frames.imageChunk(offset: off, bits[off..<min(bits.count, off + Nova.imageChunk)]))
            off += Nova.imageChunk
        }
        try await send(Frames.command(.imgEnd))
        try await requestInfo()
    }

    // MARK: live data

    public func fetchLive() async {
        guard connected, !isBusy else { return }
        _ = try? await send(Frames.command(.live))
    }

    /// Asks for live data about twice a second until stopped (only start it while the live view is on screen).
    public func startPolling(interval: TimeInterval = 0.6) {
        stopPolling()
        polling = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                await self.fetchLive()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1e9))
            }
        }
    }
    public func stopPolling() { polling?.cancel(); polling = nil }

    // MARK: firmware update

    private func waitUntil(_ timeout: TimeInterval, _ cond: () -> Bool) async {
        let end = Date().addingTimeInterval(timeout)
        while !cond() && Date() < end { try? await Task.sleep(nanoseconds: 40_000_000) }
    }

    /// Sends a firmware image. The update window must be open on the board (UPDATE screen, hold the button).
    public func updateFirmware(_ image: [UInt8], progress: ((OtaStatus) -> Void)? = nil) async throws {
        guard connected else { throw SessionError.notConnected }
        let chk = Firmware.check(image)
        guard chk.ok else { throw SessionError.message(chk.message) }
        busy(true); defer { busy(false) }
        ota = OtaStatus(state: .idle, error: 0, received: 0, total: image.count)
        onChange?()
        func fail(_ text: String) async -> SessionError {
            try? await link.writeCtrl(Frames.command(.otaAbort))
            return SessionError.message(text)
        }
        try await link.writeCtrl(Frames.otaBegin(size: image.count, crc: chk.crc))
        await waitUntil(5) { self.ota.state == .receiving || self.ota.state == .error }
        if ota.state != .receiving { throw await fail(ota.state == .error ? OtaText.error(ota.error) : "Boardet startede ikke opdateringen") }
        var sent = 0
        while sent < image.count {
            if ota.state == .error { throw await fail(OtaText.error(ota.error)) }
            if sent - ota.received >= Nova.otaWindowBytes {
                await waitUntil(3) { sent - self.ota.received < Nova.otaWindowBytes || self.ota.state != .receiving }
                if sent - ota.received >= Nova.otaWindowBytes && ota.state == .receiving { try? await Task.sleep(nanoseconds: 50_000_000); continue }
            }
            let end = min(image.count, sent + link.dataChunk)
            try await link.writeData(Array(image[sent..<end]))
            sent = end
            progress?(ota)
        }
        await waitUntil(20) { self.ota.state == .done || self.ota.state == .error }
        if ota.state == .error { throw await fail(OtaText.error(ota.error)) }
        if ota.state != .done { throw await fail("Boardet svarede ikke efter opdateringen") }
        progress?(ota)
    }
}
