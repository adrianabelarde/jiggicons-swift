import Foundation

/// The free icons bundled with this package, loaded on first use and kept,
/// and any icons from the full set that you added to your app with
/// `npx jiggicons add <icon> --format swift` (found in your app's bundle).
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

    /// An icon by id ("bell", "music-note-2"): one of the bundled free icons, or
    /// one you added to your app with the Jiggicons CLI. Nil if it is neither.
    public static func icon(named name: String) -> JiggiconData? {
        if let box = cache.object(forKey: name as NSString) { return box.icon }
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "icons")
                ?? added.url(name + ".jiggicon", "json"),
              let icon = try? load(contentsOf: url) else { return nil }
        cache.setObject(Box(icon), forKey: name as NSString)
        return icon
    }

    /// Also look for added icons in this bundle (your app's main bundle is
    /// always searched). Use it when the icons live in a framework or package.
    public static func register(bundle: Bundle) { added.add(bundle: bundle) }

    /// Also look for added icons in this folder on disk, e.g. one you downloaded into.
    public static func register(folder: URL) { added.add(folder: folder) }

    // Where the CLI's files are found: `<id>.jiggicon.json` and the sounds
    // beside it, at the top of a bundle (how Xcode copies a group) or in its
    // Jiggicons folder (a folder reference), or in a registered folder.
    final class Added: @unchecked Sendable {
        private let lock = NSLock()
        private var bundles: [Bundle] = [.main]
        private var folders: [URL] = []

        func add(bundle: Bundle) { lock.lock(); defer { lock.unlock() }; if !bundles.contains(bundle) { bundles.append(bundle) } }
        func add(folder: URL) { lock.lock(); defer { lock.unlock() }; if !folders.contains(folder) { folders.append(folder) } }

        func url(_ resource: String, _ ext: String) -> URL? {
            lock.lock(); defer { lock.unlock() }
            for folder in folders {
                let url = folder.appendingPathComponent(resource + "." + ext)
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
            for bundle in bundles {
                if let url = bundle.url(forResource: resource, withExtension: ext)
                    ?? bundle.url(forResource: resource, withExtension: ext, subdirectory: "Jiggicons") { return url }
            }
            return nil
        }
    }
    static let added = Added()

    /// Icon data from a JSON file in the Jiggicons mobile format, e.g. one in your app's bundle.
    public static func load(contentsOf url: URL) throws -> JiggiconData {
        try JSONDecoder().decode(JiggiconData.self, from: Data(contentsOf: url))
    }

    // A bundled cue, or an added icon's (.m4a, or .wav where the CLI could not encode AAC).
    static func soundURL(_ key: String) -> URL? {
        Bundle.module.url(forResource: key, withExtension: "m4a", subdirectory: "sounds")
            ?? added.url(key, "m4a") ?? added.url(key, "wav")
    }
}
