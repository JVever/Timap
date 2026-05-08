import Foundation

public struct City: Codable, Hashable, Identifiable {
    public var name: String
    public var nameZh: String?
    public var country: String
    public var flag: String
    public var lat: Double
    public var lng: Double
    public var tz: String

    public var id: String { "\(name)/\(tz)" }

    public init(name: String, nameZh: String? = nil, country: String, flag: String, lat: Double, lng: Double, tz: String) {
        self.name = name
        self.nameZh = nameZh
        self.country = country
        self.flag = flag
        self.lat = lat
        self.lng = lng
        self.tz = tz
    }

    public func displayName(_ lang: AppLanguage) -> String {
        switch lang {
        case .zh: return nameZh ?? name
        case .en: return name
        }
    }
}

/// A city the user has explicitly added to their list but hasn't put any
/// teammates in yet (or has emptied by removing all members). The v4 design
/// makes "city" first-class — a card stays around even with zero members so
/// the user has a place to add coworkers later.
public struct EmptyCityRecord: Codable, Hashable, Identifiable {
    public var city: City
    public var workStart: Double
    public var workEnd: Double

    public var id: String { city.name }

    public init(city: City, workStart: Double = 9, workEnd: Double = 23) {
        self.city = city
        self.workStart = workStart
        self.workEnd = workEnd
    }
}

public enum CityCatalog {
    /// Loaded once, lazily.
    ///
    /// Resource lookup is intentionally permissive: SwiftPM's auto-generated
    /// `Bundle.module` accessor does `Bundle.main.bundleURL.appendingPathComponent(
    /// "Timap_TimapCore.bundle")`, which only works in the bare `swift run`
    /// layout where `Bundle.main.bundleURL` is the executable's parent dir.
    /// Inside a real `.app`, `Bundle.main.bundleURL` is the `.app` itself, so
    /// the SPM bundle has to sit at the `.app` top level (an unusual,
    /// non-canonical location) — and crucially, **`Bundle.module` calls
    /// `fatalError` if the bundle is missing**, taking down the whole process.
    ///
    /// We avoid that crash by trying a small list of layouts:
    ///   1. `Bundle.main.url(forResource:withExtension:)` — the canonical
    ///      `.app/Contents/Resources/cities.json` location. The Makefile
    ///      copies the JSON there directly so this path works without
    ///      depending on SPM's bundle accessor at all.
    ///   2. `Timap_TimapCore.bundle/cities.json` next to the executable
    ///      (`Contents/MacOS/`) — the layout the Makefile shipped through
    ///      v0.1.3, kept for backward compatibility with already-installed
    ///      copies.
    ///   3. `Bundle.module` — works when Timap is launched directly from
    ///      `.build/release` via `swift run` during development.
    public static let all: [City] = {
        for url in candidateCitiesURLs() {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([City].self, from: data) {
                return decoded
            }
        }
        return []
    }()

    /// Ordered list of paths where `cities.json` may live across the
    /// shipping `.app`, dev `swift run`, and legacy install layouts.
    /// Returning a sequence (rather than a single resolved URL) lets us
    /// tolerate any individual path being missing without ever invoking
    /// `Bundle.module`'s fatal-on-miss code path.
    private static func candidateCitiesURLs() -> [URL] {
        var urls: [URL] = []

        // 1. .app/Contents/Resources/cities.json — Makefile's primary copy.
        if let url = Bundle.main.url(forResource: "cities", withExtension: "json") {
            urls.append(url)
        }

        // 2. Look next to the executable for a Timap_TimapCore.bundle dir.
        //    Covers v0.1.3 and earlier installs sitting in /Applications.
        if let exeDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            urls.append(exeDir
                .appendingPathComponent("Timap_TimapCore.bundle")
                .appendingPathComponent("cities.json"))
            urls.append(exeDir.appendingPathComponent("cities.json"))
        }

        // 3. Bundle.module — wrapped in a do/catch-equivalent guard so its
        //    fatalError can't fire. We can't catch fatalError, but we can
        //    skip touching Bundle.module entirely when the SPM bundle
        //    clearly isn't present at any candidate path. The check below
        //    looks where Bundle.module would, without invoking it.
        let mainPath = Bundle.main.bundleURL
            .appendingPathComponent("Timap_TimapCore.bundle")
        if FileManager.default.fileExists(atPath: mainPath.path) {
            if let url = Bundle.module.url(forResource: "cities", withExtension: "json") {
                urls.append(url)
            }
        }

        return urls
    }

    /// Case-insensitive prefix + substring search. Matches against both
    /// English `name` and Chinese `nameZh` so users can type either.
    /// Empty query returns first `limit`.
    public static func search(_ query: String, limit: Int = 8) -> [City] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            return Array(all.prefix(limit))
        }
        func matches(_ c: City, _ predicate: (String) -> Bool) -> Bool {
            predicate(c.name.lowercased()) || (c.nameZh.map(predicate) ?? false)
        }
        let prefix = all.filter { matches($0) { $0.hasPrefix(q) } }
        if prefix.count >= limit { return Array(prefix.prefix(limit)) }
        let other = all.filter { c in
            !matches(c) { $0.hasPrefix(q) } &&
                matches(c) { $0.contains(q) }
        }
        return Array((prefix + other).prefix(limit))
    }
}
