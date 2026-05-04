import Foundation

public enum TeamStore {
    private static let teamKey = "timap.team"
    private static let homeKey = "timap.home"
    private static let extraCitiesKey = "timap.extraCities"
    private static let hiddenCitiesKey = "timap.hiddenCities"
    private static let onboardedKey = "timap.hasOnboarded"
    private static let languageKey = "timap.language"
    // Legacy key from the per-teammate hide era. Read-only for migration.
    private static let legacyHiddenIDsKey = "timap.hiddenIDs"

    public struct Snapshot {
        public var team: [Teammate]
        public var home: EmptyCityRecord?
        public var extraCities: [EmptyCityRecord]
        public var hiddenCities: Set<String>
        public var hasOnboarded: Bool
        public var language: AppLanguage
    }

    public static func load() -> Snapshot {
        let defaults = UserDefaults.standard

        // Step 1 — migrate `isMe:true` teammates from older schemas. The
        // current Teammate model has no `isMe` field; if a saved entry
        // had one, we extract its city info into a `home` record and drop
        // the entry from the team list. This runs once per persisted
        // payload; after the migrated data is rewritten on the next save,
        // the JSON no longer contains `isMe`.
        var migratedHome: EmptyCityRecord? = nil
        let teamData = defaults.data(forKey: teamKey)
        var rawTeam: [Teammate] = []
        var teamDataIsValid = true
        if let teamData = teamData {
            let result = migrateAndDecodeTeam(teamData)
            rawTeam = result.team
            migratedHome = result.home
            teamDataIsValid = result.decodedCleanly
        } else {
            // Truly first-launch — no persisted team. Seed with the demo
            // team so the user has something to play with.
            rawTeam = DefaultTeam.teammates()
        }
        let team = CityCanonicalizer.normalize(rawTeam)
        // Only rewrite the persisted blob if we successfully decoded the
        // user's actual data. If the payload was corrupted we leave the
        // bytes in place — the user can recover them by, say, downgrading
        // — and operate on an empty team in memory until the next intentional
        // edit overwrites the slot.
        if teamDataIsValid, let data = try? JSONEncoder().encode(team) {
            defaults.set(data, forKey: teamKey)
        }

        // Step 2 — load home record. Prefer explicit storage; fall back to
        // the migrated record from step 1. Canonicalize through CityCatalog
        // so a home stored as "西雅图" lines up with teammates normalized to
        // "Seattle".
        let homeRaw: EmptyCityRecord?
        if let data = defaults.data(forKey: homeKey),
           let decoded = try? JSONDecoder().decode(EmptyCityRecord.self, from: data) {
            homeRaw = decoded
        } else {
            homeRaw = migratedHome
        }
        let home: EmptyCityRecord? = homeRaw.map {
            EmptyCityRecord(
                city: CityCanonicalizer.canonicalize($0.city),
                workStart: $0.workStart, workEnd: $0.workEnd
            )
        }
        if let home = home, let data = try? JSONEncoder().encode(home) {
            defaults.set(data, forKey: homeKey)
        }

        // Step 3 — extra cities (cities user added without members; never
        // includes home). Canonicalized so dedupe against `team` and `home`
        // works on the same canonical key.
        let extraCitiesRaw: [EmptyCityRecord]
        if let data = defaults.data(forKey: extraCitiesKey),
           let decoded = try? JSONDecoder().decode([EmptyCityRecord].self, from: data) {
            extraCitiesRaw = decoded
        } else {
            extraCitiesRaw = []
        }
        let extraCities: [EmptyCityRecord] = extraCitiesRaw
            .map { EmptyCityRecord(
                city: CityCanonicalizer.canonicalize($0.city),
                workStart: $0.workStart, workEnd: $0.workEnd
            ) }
            .filter { $0.city.name != home?.city.name }

        let hiddenCities: Set<String>
        if let data = defaults.data(forKey: hiddenCitiesKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            hiddenCities = decoded
        } else {
            hiddenCities = []
        }

        // hasOnboarded is OR'd with home presence: if a migrated/persisted
        // home exists, the user is onboarded by definition. This catches
        // schemas where hasOnboarded was lost mid-migration.
        let onboardedRaw = defaults.bool(forKey: onboardedKey)
        let hasOnboarded = onboardedRaw || (home != nil)

        let language: AppLanguage = {
            if let raw = defaults.string(forKey: languageKey),
               let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return .zh
        }()
        return Snapshot(
            team: team, home: home, extraCities: extraCities,
            hiddenCities: hiddenCities,
            hasOnboarded: hasOnboarded, language: language
        )
    }

    public static func save(
        team: [Teammate],
        home: EmptyCityRecord?,
        extraCities: [EmptyCityRecord],
        hiddenCities: Set<String>,
        hasOnboarded: Bool,
        language: AppLanguage
    ) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(team) {
            defaults.set(data, forKey: teamKey)
        }
        if let home = home, let data = try? JSONEncoder().encode(home) {
            defaults.set(data, forKey: homeKey)
        } else if home == nil {
            defaults.removeObject(forKey: homeKey)
        }
        if let data = try? JSONEncoder().encode(extraCities) {
            defaults.set(data, forKey: extraCitiesKey)
        }
        if let data = try? JSONEncoder().encode(hiddenCities) {
            defaults.set(data, forKey: hiddenCitiesKey)
        }
        defaults.set(hasOnboarded, forKey: onboardedKey)
        defaults.set(language.rawValue, forKey: languageKey)
        defaults.removeObject(forKey: legacyHiddenIDsKey)
    }

    public static func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: teamKey)
        defaults.removeObject(forKey: homeKey)
        defaults.removeObject(forKey: extraCitiesKey)
        defaults.removeObject(forKey: hiddenCitiesKey)
        defaults.removeObject(forKey: legacyHiddenIDsKey)
        defaults.removeObject(forKey: onboardedKey)
        defaults.removeObject(forKey: languageKey)
    }

    /// Inspect the raw team JSON, extract any legacy `isMe: true` entry
    /// into a home record, and return the cleaned team plus that record.
    /// The third tuple element flags whether the JSON decoded cleanly —
    /// when false, callers MUST avoid rewriting the persisted bytes so
    /// user data isn't silently replaced with an empty team.
    private static func migrateAndDecodeTeam(_ data: Data)
        -> (team: [Teammate], home: EmptyCityRecord?, decodedCleanly: Bool)
    {
        // We always inspect the raw JSON first because direct decoding
        // would silently drop the legacy `isMe` flag — leaving us no way
        // to extract the host city into a home record.
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Unrecognizable shape. Try a one-shot direct decode (some
            // futures may use a JSON object root with metadata + team).
            if let direct = try? JSONDecoder().decode([Teammate].self, from: data) {
                return (direct, nil, true)
            }
            return ([], nil, false)
        }

        var migratedHome: EmptyCityRecord? = nil
        if let meEntry = raw.first(where: { ($0["isMe"] as? Bool) == true }) {
            migratedHome = homeRecordFromEntry(meEntry)
        }
        let cleaned = raw.filter { ($0["isMe"] as? Bool) != true }
        guard let cleanedData = try? JSONSerialization.data(withJSONObject: cleaned),
              let team = try? JSONDecoder().decode([Teammate].self, from: cleanedData) else {
            // Partial corruption — preserve original bytes; surface what
            // little we extracted.
            return ([], migratedHome, false)
        }
        return (team, migratedHome, true)
    }

    private static func homeRecordFromEntry(_ e: [String: Any]) -> EmptyCityRecord? {
        guard let city = e["city"] as? String,
              let lat = e["lat"] as? Double,
              let lng = e["lng"] as? Double,
              let tz = e["tzIdentifier"] as? String else {
            return nil
        }
        let cityZh = e["cityZh"] as? String
        let country = (e["country"] as? String) ?? ""
        let flag = (e["flag"] as? String) ?? "🌐"
        let workStart = (e["workStart"] as? Double) ?? Double(e["workStart"] as? Int ?? 9)
        let workEnd = (e["workEnd"] as? Double) ?? Double(e["workEnd"] as? Int ?? 23)
        return EmptyCityRecord(
            city: City(
                name: city, nameZh: cityZh,
                country: country, flag: flag,
                lat: lat, lng: lng, tz: tz
            ),
            workStart: workStart,
            workEnd: workEnd
        )
    }
}
