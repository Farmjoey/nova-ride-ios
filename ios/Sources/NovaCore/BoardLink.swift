import Foundation

/// The transport between the app and a board: HTTP over the board's Wi-Fi on the phone, a simulated board in demo mode and in tests.
/// All callbacks may arrive on any thread; the session handles that.
public protocol BoardLink: AnyObject {
    var onStat: (([UInt8]) -> Void)? { get set }
    var onClose: (() -> Void)? { get set }
    /// Reaches the board (throws a Danish message on failure).
    func connect() async throws
    func disconnect()
    /// A command to the board. Its answer (INFO, ACK, live data...) is passed to `onStat` before this returns.
    func writeCtrl(_ bytes: [UInt8]) async throws
    /// A block of a firmware image. The update status comes back through `onStat`.
    func writeData(_ bytes: [UInt8]) async throws
    /// How many bytes of firmware go in one `writeData`.
    var dataChunk: Int { get }
}

public extension BoardLink {
    var dataChunk: Int { Nova.otaChunk }
}

public enum SessionError: Error, LocalizedError, Equatable {
    case notConnected
    case noAnswer
    case refused(UInt8)
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Ikke forbundet til boardet."
        case .noAnswer: return "Intet svar fra boardet"
        case .refused: return "Boardet afviste kommandoen"
        case .message(let m): return m
        }
    }
}
