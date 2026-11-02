import Foundation
import Combine

/// The state the screens show, and the actions they trigger. All real work happens in `BoardSession` (tested on a PC).
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var connecting = false
    @Published private(set) var info: BoardInfo?
    @Published private(set) var live: LiveValues?
    @Published private(set) var ota = OtaStatus(state: .idle, error: 0, received: 0, total: 0)
    @Published private(set) var history = WidgetHistory()
    @Published var status = ""
    @Published var message = ""
    @Published private(set) var working = false
    @Published private(set) var demo = false

    // preferences (remembered between launches)
    @Published var liveEnabled: Bool { didSet { defaults.set(liveEnabled, forKey: "liveEnabled"); updatePolling() } }
    @Published var useMph: Bool { didSet { defaults.set(useMph, forKey: "useMph") } }
    @Published var accentHex: String { didSet { defaults.set(accentHex, forKey: "accentHex") } }

    let starters: [StarterDesign]
    private(set) var session: BoardSession?
    private let defaults = UserDefaults.standard
    private var homeVisible = false
    private var lastHistory = Date.distantPast

    init() {
        liveEnabled = UserDefaults.standard.bool(forKey: "liveEnabled")
        useMph = UserDefaults.standard.bool(forKey: "useMph")
        accentHex = UserDefaults.standard.string(forKey: "accentHex") ?? "#6fa3a8"
        if let dir = Bundle.main.url(forResource: "starter", withExtension: nil) { starters = StarterLibrary.load(directory: dir) } else { starters = [] }
    }

    var theme: NovaTheme {
        NovaTheme.at(info?.theme ?? NovaTheme.defaultIndex, accent: RGB(hex: accentHex))
    }
    var standardDesign: [String: Any]? { starters.first?.json }

    // MARK: connection

    func connect(demo useDemo: Bool) {
        guard !connecting, !connected else { return }
        message = ""; status = useDemo ? "" : "Forbinder til boardet…"
        connecting = true
        demo = useDemo
        let s = BoardSession(link: useDemo ? DemoBoard() : HttpLink())
        session = s
        s.onChange = { [weak self] in Task { @MainActor in self?.sync() } }
        s.onStatus = { [weak self] text in Task { @MainActor in self?.status = text } }
        Task {
            do {
                try await s.connect()
                status = ""
            } catch {
                message = error.localizedDescription
                status = ""
                session = nil
            }
            connecting = false
            sync()
        }
    }

    func disconnect() {
        session?.disconnect()
        session = nil
        sync()
    }

    private func sync() {
        guard let s = session else {
            connected = false; info = nil; live = nil; history = WidgetHistory(); updatePolling(); return
        }
        let wasConnected = connected
        connected = s.connected
        info = s.info
        live = s.live
        ota = s.ota
        if s.connected, let l = s.live, Date().timeIntervalSince(lastHistory) >= 2 { history.add(l); lastHistory = Date() }
        if wasConnected != connected { updatePolling() }
        if wasConnected && !connected { session = nil; if message.isEmpty { message = "Forbindelsen til boardet blev afbrudt." } }
    }

    // MARK: actions

    /// Runs board work and shows any failure as a message (never silently).
    func run(_ label: String = "", _ work: @escaping (BoardSession) async throws -> Void) {
        guard let s = session, s.connected else { message = "Ikke forbundet til boardet."; return }
        message = ""
        working = true
        if !label.isEmpty { status = label }
        Task {
            do { try await work(s) } catch { message = error.localizedDescription }
            working = false
            if !label.isEmpty { status = "" }
            sync()
        }
    }

    // MARK: live view

    func setHomeVisible(_ v: Bool) { homeVisible = v; updatePolling() }

    private func updatePolling() {
        guard let s = session else { return }
        if homeVisible && connected && (liveEnabled || demo) { s.startPolling() } else { s.stopPolling() }
    }

    // MARK: derived

    var liveValues: LiveValues {
        if let l = live { return l }
        return LiveValues()
    }
}
