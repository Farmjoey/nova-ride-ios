import Foundation

/// An app installed with a free Apple ID stops working after 7 days. The date is inside the app, in `embedded.mobileprovision`:
/// a signed container with a readable XML property list in the middle. This reads the expiry date from those bytes.
public enum ProvisioningProfile {
    public static func expirationDate(from data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), options: [], in: start.lowerBound..<data.endIndex) else { return nil }
        let xml = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = (try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil)) as? [String: Any] else { return nil }
        return plist["ExpirationDate"] as? Date
    }

    /// Whole days left, rounded up (23 hours left = 1 day). Zero or negative means expired.
    public static func daysLeft(until date: Date, now: Date = Date()) -> Int {
        let seconds = date.timeIntervalSince(now)
        return seconds <= 0 ? Int((seconds / 86400).rounded(.down)) : Int((seconds / 86400).rounded(.up))
    }
}
