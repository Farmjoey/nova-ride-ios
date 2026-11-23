// Stand-in for Apple's UserNotifications, only to type-check the app on a PC.
import Foundation
public struct UNAuthorizationOptions: OptionSet { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }
    public static let alert = UNAuthorizationOptions(rawValue: 1), sound = UNAuthorizationOptions(rawValue: 2) }
public struct UNNotificationSound { public init() {}; public static let `default` = UNNotificationSound() }
open class UNNotificationContent { public init() {} }
open class UNMutableNotificationContent: UNNotificationContent { public override init() { super.init() }; public var title = ""; public var body = ""; public var sound: UNNotificationSound? }
open class UNNotificationTrigger {}
open class UNTimeIntervalNotificationTrigger: UNNotificationTrigger { public init(timeInterval: TimeInterval, repeats: Bool) {} }
open class UNNotificationRequest { public init(identifier: String, content: UNNotificationContent, trigger: UNNotificationTrigger?) {} }
open class UNUserNotificationCenter {
    public static func current() -> UNUserNotificationCenter { UNUserNotificationCenter() }
    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    public func add(_ request: UNNotificationRequest) async throws {}
    public func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
}
