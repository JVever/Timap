import Foundation

public struct Teammate: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var role: String
    public var city: String
    public var cityZh: String?
    public var country: String
    public var flag: String
    public var tzIdentifier: String
    public var lat: Double
    public var lng: Double
    /// Work-hours stored as `Double` so the v4 settings UI can express
    /// 0.25h steps. Old persisted integer hours decode fine into Double.
    public var workStart: Double
    public var workEnd: Double
    public var colorHex: String
    /// PNG/JPEG bytes of an uploaded avatar. Codable encodes `Data` as
    /// base64 in JSON which round-trips cleanly through UserDefaults.
    public var avatarData: Data?

    public init(
        id: UUID = UUID(),
        name: String,
        role: String,
        city: String,
        cityZh: String? = nil,
        country: String,
        flag: String,
        tzIdentifier: String,
        lat: Double,
        lng: Double,
        workStart: Double = 9,
        workEnd: Double = 23,
        colorHex: String,
        avatarData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.city = city
        self.cityZh = cityZh
        self.country = country
        self.flag = flag
        self.tzIdentifier = tzIdentifier
        self.lat = lat
        self.lng = lng
        self.workStart = workStart
        self.workEnd = workEnd
        self.colorHex = colorHex
        self.avatarData = avatarData
    }

    public func displayCity(_ lang: AppLanguage) -> String {
        switch lang {
        case .zh: return cityZh ?? city
        case .en: return city
        }
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: tzIdentifier) ?? .current
    }

    public func currentOffsetHours(for date: Date = Date()) -> Double {
        Double(timeZone.secondsFromGMT(for: date)) / 3600.0
    }

    public var initials: String { Initials.of(name) }
}

/// One-time normalization that runs every time persisted data is loaded.
/// Earlier code paths could persist `city` as either the canonical English
/// name (e.g. "Seattle") or the localized alias (e.g. "西雅图"). The two
/// look like distinct cities to grouping logic, so a teammate added via the
/// Chinese name picker would split into a duplicate city entry.
public enum CityCanonicalizer {
    public static func normalize(_ team: [Teammate]) -> [Teammate] {
        let canon = team.map { canonicalize($0) }
        return syncWorkHours(canon)
    }

    public static func canonicalize(_ p: Teammate) -> Teammate {
        guard let match = findMatch(for: p) else { return p }
        var out = p
        out.city = match.name
        out.cityZh = match.nameZh
        out.country = match.country
        out.flag = match.flag
        out.lat = match.lat
        out.lng = match.lng
        out.tzIdentifier = match.tz
        return out
    }

    /// Within each canonical city group, force work-hours to the anchor's
    /// values (alphabetically first by name). After this, every member of
    /// a city has the same workStart / workEnd. Note: the home city's
    /// hours come from `AppState.home`, not from any teammate, so this
    /// sync is only between teammates inside the same city.
    public static func syncWorkHours(_ team: [Teammate]) -> [Teammate] {
        var byCity: [String: [Int]] = [:]
        for (idx, p) in team.enumerated() {
            byCity[p.city, default: []].append(idx)
        }
        var out = team
        for (_, indices) in byCity where indices.count > 1 {
            let sorted = indices.sorted { team[$0].name < team[$1].name }
            let anchorIndex = sorted.first ?? indices[0]
            let anchor = team[anchorIndex]
            for i in indices {
                out[i].workStart = anchor.workStart
                out[i].workEnd = anchor.workEnd
            }
        }
        return out
    }

    private static func findMatch(for p: Teammate) -> City? {
        let catalog = CityCatalog.all
        let candidatesInTz = catalog.filter { $0.tz == p.tzIdentifier }
        if let exact = candidatesInTz.first(where: { c in
            c.name == p.city || c.nameZh == p.city
                || (p.cityZh != nil && (c.name == p.cityZh! || c.nameZh == p.cityZh!))
        }) {
            return exact
        }
        if !candidatesInTz.isEmpty {
            return candidatesInTz.min { a, b in distSq(a, p) < distSq(b, p) }
        }
        return catalog.first { c in
            c.name == p.city || c.nameZh == p.city
                || (p.cityZh != nil && (c.name == p.cityZh! || c.nameZh == p.cityZh!))
        }
    }

    private static func distSq(_ c: City, _ p: Teammate) -> Double {
        let dlat = c.lat - p.lat
        let dlng = c.lng - p.lng
        return dlat * dlat + dlng * dlng
    }

    /// Canonicalize a `City` value (used by home / extraCities) so it matches
    /// the names teammates have been canonicalized to. Without this, a home
    /// stored as "西雅图" would never match teammates stored as "Seattle".
    public static func canonicalize(_ city: City) -> City {
        if let match = findMatch(for: city) {
            return match
        }
        return city
    }

    private static func findMatch(for c: City) -> City? {
        let catalog = CityCatalog.all
        // Same tz lookup first (rules out cities sharing a name across tzs).
        let candidatesInTz = catalog.filter { $0.tz == c.tz }
        if let exact = candidatesInTz.first(where: { cat in
            cat.name == c.name || cat.nameZh == c.name
                || (c.nameZh != nil && (cat.name == c.nameZh! || cat.nameZh == c.nameZh!))
        }) {
            return exact
        }
        if !candidatesInTz.isEmpty {
            return candidatesInTz.min { a, b in
                let da = (a.lat - c.lat) * (a.lat - c.lat) + (a.lng - c.lng) * (a.lng - c.lng)
                let db = (b.lat - c.lat) * (b.lat - c.lat) + (b.lng - c.lng) * (b.lng - c.lng)
                return da < db
            }
        }
        return catalog.first { cat in
            cat.name == c.name || cat.nameZh == c.name
                || (c.nameZh != nil && (cat.name == c.nameZh! || cat.nameZh == c.nameZh!))
        }
    }
}

public enum DefaultTeam {
    public static func teammates() -> [Teammate] {
        [
            Teammate(
                name: "Mira Chen", role: "Design Lead",
                city: "Seattle", cityZh: "西雅图", country: "US", flag: "🇺🇸",
                tzIdentifier: "America/Los_Angeles",
                lat: 47.6, lng: -122.3,
                workStart: 9, workEnd: 23,
                colorHex: "#3b7a8c"
            ),
            Teammate(
                name: "Jordan Park", role: "Engineer",
                city: "Boston", cityZh: "波士顿", country: "US", flag: "🇺🇸",
                tzIdentifier: "America/New_York",
                lat: 42.4, lng: -71.1,
                workStart: 9, workEnd: 23,
                colorHex: "#7a5ca8"
            ),
            Teammate(
                name: "Sam Okafor", role: "PM",
                city: "Chicago", cityZh: "芝加哥", country: "US", flag: "🇺🇸",
                tzIdentifier: "America/Chicago",
                lat: 41.9, lng: -87.6,
                workStart: 9, workEnd: 23,
                colorHex: "#c8924a"
            )
        ]
    }
}
