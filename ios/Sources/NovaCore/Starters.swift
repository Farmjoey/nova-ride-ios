import Foundation

/// A ready-made design bundled with the app (app/widgets/starter/*.json).
public struct StarterDesign {
    public var id: String
    public var json: [String: Any]
    public var name: String { (json["name"] as? String) ?? id }
    public var author: String { (json["author"] as? String) ?? "" }
    public var detail: String { (json["desc"] as? String) ?? "" }
    public var pages: Int { Widget.compile(json).pages }
}

public enum StarterLibrary {
    /// Reads `index.json` (`{"widgets": [...]}`) and every listed design from `directory`.
    public static func load(directory: URL) -> [StarterDesign] {
        guard let idxData = try? Data(contentsOf: directory.appendingPathComponent("index.json")),
              let idx = (try? JSONSerialization.jsonObject(with: idxData)) as? [String: Any],
              let names = idx["widgets"] as? [String] else { return [] }
        var out: [StarterDesign] = []
        for n in names {
            if let d = try? Data(contentsOf: directory.appendingPathComponent(n + ".json")), let j = Widget.parse(json: d) {
                out.append(StarterDesign(id: n, json: j))
            }
        }
        return out
    }
}
