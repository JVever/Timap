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

    public init(city: City, workStart: Double = 9, workEnd: Double = 18) {
        self.city = city
        self.workStart = workStart
        self.workEnd = workEnd
    }
}

public enum CityCatalog {
    /// Loaded once, lazily.
    public static let all: [City] = {
        guard let url = Bundle.module.url(forResource: "cities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([City].self, from: data)
        else {
            return []
        }
        return decoded
    }()

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
