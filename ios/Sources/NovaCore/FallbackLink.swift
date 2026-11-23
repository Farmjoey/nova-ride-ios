import Foundation

/// Wi-Fi first, Bluetooth if the phone is not on the board's Wi-Fi. `secondary` is made only when it is needed (making the
/// Bluetooth link is what makes the phone ask for Bluetooth permission).
public final class FallbackLink: BoardLink {
    public var onStat: (([UInt8]) -> Void)? { didSet { primary.onStat = onStat; secondaryLink?.onStat = onStat } }
    public var onClose: (() -> Void)? { didSet { primary.onClose = onClose; secondaryLink?.onClose = onClose } }
    /// Told to the screen: "Ikke på boardets Wi-Fi: prøver Bluetooth…"
    public var onNote: ((String) -> Void)?
    public private(set) var usedFallback = false

    private let primary: BoardLink
    private let makeSecondary: () -> BoardLink
    private var secondaryLink: BoardLink?
    private var active: BoardLink?

    public init(primary: BoardLink, secondary: @escaping () -> BoardLink) {
        self.primary = primary
        self.makeSecondary = secondary
    }

    public var dataChunk: Int { active?.dataChunk ?? primary.dataChunk }
    public var supportsFirmwareUpdate: Bool { active?.supportsFirmwareUpdate ?? true }
    public var kind: String { active?.kind ?? primary.kind }

    public func connect() async throws {
        usedFallback = false
        do {
            try await primary.connect()
            active = primary
            return
        } catch {
            let first = error.localizedDescription
            onNote?("Ikke på boardets Wi-Fi. Prøver Bluetooth…")
            let second = makeSecondary()
            second.onStat = onStat
            second.onClose = onClose
            secondaryLink = second
            do {
                try await second.connect()
                active = second
                usedFallback = true
            } catch {
                throw SessionError.message("Ingen forbindelse til boardet. Wi-Fi: \(first) Bluetooth: \(error.localizedDescription)")
            }
        }
    }

    public func disconnect() {
        primary.disconnect()
        secondaryLink?.disconnect()
        active = nil
    }

    public func writeCtrl(_ bytes: [UInt8]) async throws {
        guard let a = active else { throw SessionError.notConnected }
        try await a.writeCtrl(bytes)
    }

    public func writeData(_ bytes: [UInt8]) async throws {
        guard let a = active else { throw SessionError.notConnected }
        try await a.writeData(bytes)
    }
}
