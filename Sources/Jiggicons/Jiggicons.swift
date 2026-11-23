import Foundation

/// The free icons bundled with this package, loaded on first use and kept.
public enum Jiggicons {
    public struct Entry: Decodable, Sendable, Hashable {
        public let id: String
        public let name: String
        public let category: String
    }

    /// Every bundled icon, in the order of the Jiggicons landing page.
    public static let all: [Entry] = {
        guard let url = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "icons"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }()

    public static var names: [String] { all.map(\.id) }

    private static let cache = NSCache<NSString, Box>()
    private final class Box { let icon: JiggiconData; init(_ icon: JiggiconData) { self.icon = icon } }

    /// A bundled icon by id ("bell", "music-note-2"), or nil if it isn't one of the free icons.
    public static func icon(named name: String) -> JiggiconData? {
        if let box = cache.object(forKey: name as NSString) { return box.icon }
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "icons"),
              let icon = try? load(contentsOf: url) else { return nil }
        cache.setObject(Box(icon), forKey: name as NSString)
        return icon
    }

    /// Icon data from a JSON file in the Jiggicons mobile format, e.g. one in your app's bundle.
    public static func load(contentsOf url: URL) throws -> JiggiconData {
        try JSONDecoder().decode(JiggiconData.self, from: Data(contentsOf: url))
    }

    static func soundURL(_ key: String) -> URL? {
        Bundle.module.url(forResource: key, withExtension: "m4a", subdirectory: "sounds")
    }
}
