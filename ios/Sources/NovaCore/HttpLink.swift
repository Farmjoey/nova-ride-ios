import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The phone talks to the board over the board's own Wi-Fi with plain HTTP (the web server in src/WifiApp.cpp):
/// every command is a POST to /api/ctrl, every firmware block a POST to /api/data, and the answer frame is the body of the
/// reply. Same protocol as the Bluetooth service it replaced.
public final class HttpLink: BoardLink {
    public var onStat: (([UInt8]) -> Void)?
    public var onClose: (() -> Void)?
    public var dataChunk: Int { Nova.wifiOtaChunk }

    private let base: URL
    private let session: URLSession
    private let lock = NSLock()
    private var alive = false
    private var fails = 0
    private var heartbeat: Task<Void, Never>?

    public init(base: URL = URL(string: Nova.boardBaseURL)!) {
        self.base = base
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.timeoutIntervalForResource = 30
        c.allowsCellularAccess = false          // the board is on Wi-Fi; never try the mobile network
        c.urlCache = nil
        self.session = URLSession(configuration: c)
    }

    private func post(_ path: String, _ body: [UInt8]) async throws -> [UInt8] {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.httpBody = Data(body)
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let result: Result<(Data, URLResponse), Error> = await withCheckedContinuation { cont in
            let task = session.dataTask(with: req) { data, resp, err in
                if let err = err { cont.resume(returning: .failure(err)) }
                else if let data = data, let resp = resp { cont.resume(returning: .success((data, resp))) }
                else { cont.resume(returning: .failure(SessionError.noAnswer)) }
            }
            task.resume()
        }
        switch result {
        case .failure:
            noteFailure()
            throw SessionError.message("Ingen forbindelse til boardet. Er iPhonen på Wi-Fi-netværket NOVA RIDE?")
        case .success(let (data, resp)):
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                throw SessionError.message("Boardet svarede med fejl (\(http.statusCode)).")
            }
            lock.lock(); fails = 0; lock.unlock()
            let bytes = [UInt8](data)
            if !bytes.isEmpty { onStat?(bytes) }
            return bytes
        }
    }

    private func noteFailure() {
        lock.lock(); fails += 1; let lost = fails >= 2 && alive; if lost { alive = false }; lock.unlock()
        if lost { heartbeat?.cancel(); onClose?() }
    }

    public func connect() async throws {
        _ = try await post("api/ctrl", [Op.info.rawValue])           // the board answers: we are connected
        lock.lock(); alive = true; fails = 0; lock.unlock()
        heartbeat = Task { [weak self] in                              // also notices when the Wi-Fi is gone
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self = self, !Task.isCancelled else { return }
                _ = try? await self.post("api/ctrl", [Op.info.rawValue])
            }
        }
    }

    public func disconnect() {
        heartbeat?.cancel()
        lock.lock(); let was = alive; alive = false; lock.unlock()
        if was { onClose?() }
    }

    public func writeCtrl(_ bytes: [UInt8]) async throws { _ = try await post("api/ctrl", bytes) }
    public func writeData(_ bytes: [UInt8]) async throws { _ = try await post("api/data", bytes) }
}
