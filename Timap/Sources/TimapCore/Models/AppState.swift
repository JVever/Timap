import Foundation
import Combine

/// A city + its team members, used by the v11 city-card layout. Carries all
/// city-level metadata directly so empty cities (cards added but with no
/// members) and the home city (which lives outside the `team` array) render
/// identically to populated cities.
public struct CityGroup: Identifiable {
    public let city: String
    public let cityZh: String?
    public let country: String
    public let flag: String
    public let lat: Double
    public let lng: Double
    public let tzIdentifier: String
    public let workStart: Double
    public let workEnd: Double
    /// Color used for the map pin and the home accent. For populated cities
    /// it's a member's `colorHex`; for empty/home cities it's a deterministic
    /// hash of the city name.
    public let colorHex: String
    public let members: [Teammate]
    public let isHome: Bool
    public let isHidden: Bool

    public var id: String { city }
    public var offsetHours: Double {
        offsetHours(at: Date())
    }
    /// DST-correct offset at a specific instant. Use this when computing
    /// local times relative to a scrubbed slider position so a transition
    /// inside today's slider range is honored.
    public func offsetHours(at date: Date) -> Double {
        Double(TimeZone(identifier: tzIdentifier)?.secondsFromGMT(for: date) ?? 0) / 3600.0
    }
    /// Convenience for views that still want a "primary" teammate to read
    /// styling from (e.g. label tinting). Returns the alphabetically-first
    /// member, or nil if the city has no members yet (e.g. an empty home).
    public var anchor: Teammate? { members.first }
    public func displayCity(_ lang: AppLanguage) -> String {
        switch lang {
        case .zh: return cityZh ?? city
        case .en: return city
        }
    }

    public init(
        city: String, cityZh: String?, country: String, flag: String,
        lat: Double, lng: Double, tzIdentifier: String,
        workStart: Double, workEnd: Double,
        colorHex: String,
        members: [Teammate], isHome: Bool, isHidden: Bool
    ) {
        self.city = city
        self.cityZh = cityZh
        self.country = country
        self.flag = flag
        self.lat = lat
        self.lng = lng
        self.tzIdentifier = tzIdentifier
        self.workStart = workStart
        self.workEnd = workEnd
        self.colorHex = colorHex
        self.members = members
        self.isHome = isHome
        self.isHidden = isHidden
    }

    /// Group teammates + home + extra cities into card data. The home city
    /// is always included (provided `home` is non-nil), and home's geo /
    /// work-hours always come from the home record — not from any teammate
    /// who happens to share that city. Sort: home first; then visible by
    /// descending UTC offset; hidden last.
    public static func group(
        team: [Teammate],
        home: EmptyCityRecord? = nil,
        extraCities: [EmptyCityRecord] = [],
        hiddenCities: Set<String> = []
    ) -> [CityGroup] {
        var memberBuckets: [String: [Teammate]] = [:]
        var insertionOrder: [String] = []
        for p in team {
            if memberBuckets[p.city] == nil { insertionOrder.append(p.city) }
            memberBuckets[p.city, default: []].append(p)
        }

        var result: [CityGroup] = []

        // Home first. Always synthesized — even if the home city has no
        // teammates, the card stays in place so the user has a working-hours
        // surface for it. If teammates ARE in the home city, list them as
        // chips; the home record wins for hours/geo metadata.
        if let h = home {
            let homeMembers = memberBuckets[h.city.name]?
                .sorted { $0.name < $1.name } ?? []
            result.append(CityGroup(
                city: h.city.name, cityZh: h.city.nameZh,
                country: h.city.country, flag: h.city.flag,
                lat: h.city.lat, lng: h.city.lng,
                tzIdentifier: h.city.tz,
                workStart: h.workStart, workEnd: h.workEnd,
                colorHex: Palette.color(for: h.city.name),
                members: homeMembers,
                isHome: true,
                isHidden: false
            ))
        }

        // Non-home populated cities (skip the home key, already handled).
        for key in insertionOrder where home?.city.name != key {
            var members = memberBuckets[key]!
            members.sort { $0.name < $1.name }
            let anchor = members[0]
            result.append(CityGroup(
                city: anchor.city, cityZh: anchor.cityZh,
                country: anchor.country, flag: anchor.flag,
                lat: anchor.lat, lng: anchor.lng,
                tzIdentifier: anchor.tzIdentifier,
                workStart: anchor.workStart, workEnd: anchor.workEnd,
                colorHex: anchor.colorHex,
                members: members,
                isHome: false,
                isHidden: hiddenCities.contains(key)
            ))
        }

        // Empty (non-home) cities the user has added but hasn't populated.
        for rec in extraCities where memberBuckets[rec.city.name] == nil
            && home?.city.name != rec.city.name {
            result.append(CityGroup(
                city: rec.city.name, cityZh: rec.city.nameZh,
                country: rec.city.country, flag: rec.city.flag,
                lat: rec.city.lat, lng: rec.city.lng,
                tzIdentifier: rec.city.tz,
                workStart: rec.workStart, workEnd: rec.workEnd,
                colorHex: Palette.color(for: rec.city.name),
                members: [],
                isHome: false,
                isHidden: hiddenCities.contains(rec.city.name)
            ))
        }

        return result.sorted { a, b in
            if a.isHome != b.isHome { return a.isHome && !b.isHome }
            if a.isHidden != b.isHidden { return !a.isHidden && b.isHidden }
            return a.offsetHours > b.offsetHours
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var team: [Teammate] {
        didSet { persist() }
    }
    @Published public var hiddenCities: Set<String> {
        didSet { persist() }
    }
    /// User-added cities that have no teammates yet. Excludes the home
    /// city — `home` is its own slot so it doesn't accidentally get
    /// deleted via the same code path.
    @Published public var extraCities: [EmptyCityRecord] {
        didSet { persist() }
    }
    /// The user's home city. The whole app's time math pivots on this:
    /// the slider's "now" tracks home's tz, the map's day/night terminator
    /// renders relative to home, and meeting score uses home as the host
    /// offset. There's no "you" teammate concept; the user is implicitly at
    /// home.
    @Published public var home: EmptyCityRecord? {
        didSet { persist() }
    }
    @Published public var hasOnboarded: Bool {
        didSet { persist() }
    }
    @Published public var language: AppLanguage {
        didSet { persist() }
    }
    @Published public var hostHour: Double
    @Published public var isLive: Bool
    @Published public var hostDate: Date

    public init(
        team: [Teammate],
        home: EmptyCityRecord?,
        extraCities: [EmptyCityRecord],
        hiddenCities: Set<String>,
        hasOnboarded: Bool,
        language: AppLanguage
    ) {
        self.team = team
        self.home = home
        self.extraCities = extraCities
        self.hiddenCities = hiddenCities
        self.hasOnboarded = hasOnboarded
        self.language = language
        self.isLive = true
        self.hostDate = Date()
        self.hostHour = 10
        self.hostHour = Self.computeLiveHostHour(home: home) ?? 10
    }

    public static func load() -> AppState {
        let s = TeamStore.load()
        return AppState(
            team: s.team, home: s.home, extraCities: s.extraCities,
            hiddenCities: s.hiddenCities,
            hasOnboarded: s.hasOnboarded, language: s.language
        )
    }

    private func persist() {
        TeamStore.save(
            team: team, home: home, extraCities: extraCities,
            hiddenCities: hiddenCities,
            hasOnboarded: hasOnboarded, language: language
        )
    }

    public func tr(_ key: L10n.Key) -> String { L10n.t(key, language) }

    public var homeCity: String? { home?.city.name }
    /// Identifier of the time zone the slider/map are scrubbed against.
    /// Falls back to the system zone before onboarding.
    public var hostTimeZone: TimeZone {
        guard let home = home, let tz = TimeZone(identifier: home.city.tz) else {
            return .current
        }
        return tz
    }
    /// Absolute Date the slider is currently pointing to. Used by scoring
    /// + view code that needs DST-correct offsets at the scrubbed time
    /// rather than at "now".
    public var hostInstant: Date {
        TimeMath.hostInstant(date: hostDate, hourOfDay: hostHour, in: hostTimeZone)
    }

    public var hostOffsetHours: Double {
        Double(hostTimeZone.secondsFromGMT(for: hostInstant)) / 3600.0
    }

    public var visibleTeam: [Teammate] {
        team.filter { !hiddenCities.contains($0.city) }
    }

    /// Team list used by meeting-score / best-window calculations. Includes
    /// every visible city the user cares about: home (always — the user's
    /// own work hours must constrain the window), real teammates, and
    /// `extraCities` (empty placeholders the user added because they want
    /// that timezone factored in even without a specific colleague).
    /// Hidden cities are filtered from team and extraCities. Each city
    /// contributes at most ONE constraint — if a teammate lives in the
    /// home city, or extraCities and team both reference the same city
    /// (e.g. through a migration), the duplicate is dropped so the same
    /// work-hours interval doesn't get applied twice and silently shrink
    /// the suggestion window.
    public var scoringTeam: [Teammate] {
        var seen = Set<String>()
        var result: [Teammate] = []

        if let home = home {
            result.append(virtualTeammate(
                city: home.city, workStart: home.workStart, workEnd: home.workEnd
            ))
            seen.insert(home.city.name)
        }
        for p in team where !hiddenCities.contains(p.city) {
            if seen.insert(p.city).inserted {
                result.append(p)
            }
        }
        for rec in extraCities where !hiddenCities.contains(rec.city.name) {
            if seen.insert(rec.city.name).inserted {
                result.append(virtualTeammate(
                    city: rec.city, workStart: rec.workStart, workEnd: rec.workEnd
                ))
            }
        }
        return result
    }

    /// Synthesize a Teammate from a city + work-hours pair. Used for cities
    /// without a specific named member (home, extraCities). The avatar/name
    /// are placeholders since this teammate never renders in the UI; only
    /// the tz + work hours are read by the scorer.
    private func virtualTeammate(city: City, workStart: Double, workEnd: Double) -> Teammate {
        Teammate(
            id: UUID(),
            name: "_virtual", role: "",
            city: city.name, cityZh: city.nameZh,
            country: city.country, flag: city.flag,
            tzIdentifier: city.tz,
            lat: city.lat, lng: city.lng,
            workStart: workStart, workEnd: workEnd,
            colorHex: "#000000"
        )
    }

    public var citiesGrouped: [CityGroup] {
        CityGroup.group(
            team: team, home: home,
            extraCities: extraCities,
            hiddenCities: hiddenCities
        )
    }

    public func toggleCityHidden(_ city: String) {
        guard city != homeCity else { return }
        if hiddenCities.contains(city) {
            hiddenCities.remove(city)
        } else {
            hiddenCities.insert(city)
        }
    }

    public func jumpToBestWindow() {
        let windows = TimeMath.findBestWindows(
            hostDate: hostDate, hostTimeZone: hostTimeZone, team: scoringTeam
        )
        guard !windows.isEmpty else { return }
        let great = windows.filter { $0.minScore >= 0.95 }.sorted { $0.start < $1.start }
        if !great.isEmpty {
            let next = great.first { $0.start > hostHour + 0.01 } ?? great[0]
            setHostHour(next.start)
            return
        }
        let byStart = windows.sorted { $0.start < $1.start }
        let next = byStart.first { $0.start > hostHour + 0.01 } ?? byStart[0]
        setHostHour(next.start)
    }

    public func setHostHour(_ h: Double) {
        hostHour = h
        isLive = false
    }

    public func goLive() {
        isLive = true
        if let h = Self.computeLiveHostHour(home: home) { hostHour = h }
        hostDate = Date()
    }

    public func tick() {
        hostDate = Date()
        if isLive, let h = Self.computeLiveHostHour(home: home) {
            hostHour = h
        }
    }

    public func upsert(_ p: Teammate) {
        if let i = team.firstIndex(where: { $0.id == p.id }) {
            team[i] = p
        } else {
            team.append(p)
        }
        team = CityCanonicalizer.normalize(team)
        // If a member was just added to a city that was previously empty,
        // drop the empty placeholder.
        extraCities.removeAll { rec in team.contains { $0.city == rec.city.name } }
    }

    /// Update work hours for a city. Hits home record (if it's home), the
    /// matching extraCities entry (if it's an empty city), and every
    /// teammate in that city. All three sources are kept in sync because
    /// the visible card pulls from one of them.
    public func setCityWorkHours(_ city: String, start rawStart: Double, end rawEnd: Double) {
        // Quantize to 30-min grid — the global minimum time scale. Anything
        // finer can't be meaningfully represented on the slider or strips.
        let start = (rawStart * 2).rounded() / 2
        let cleanEnd = max(start + 0.5, (rawEnd * 2).rounded() / 2)
        for i in team.indices where team[i].city == city {
            team[i].workStart = start
            team[i].workEnd = cleanEnd
        }
        if let i = extraCities.firstIndex(where: { $0.city.name == city }) {
            extraCities[i].workStart = start
            extraCities[i].workEnd = cleanEnd
        }
        if home?.city.name == city {
            home?.workStart = start
            home?.workEnd = cleanEnd
        }
    }

    /// Remove a teammate by id. Always allowed — the home concept is now
    /// detached from any teammate, so deleting "the last person in the
    /// home city" is a no-op for home (the card stays).
    public func remove(_ id: UUID) {
        guard let p = team.first(where: { $0.id == id }) else { return }
        let removedCity = p.city
        team.removeAll { $0.id == id }
        // If the removed teammate's city now has no members AND it isn't
        // home AND it isn't already in extraCities, demote to extraCities
        // so the card sticks around. Home doesn't need this because home
        // already lives in its own slot.
        if !team.contains(where: { $0.city == removedCity }),
           home?.city.name != removedCity,
           !extraCities.contains(where: { $0.city.name == removedCity }) {
            let entry = EmptyCityRecord(
                city: City(
                    name: p.city, nameZh: p.cityZh,
                    country: p.country, flag: p.flag,
                    lat: p.lat, lng: p.lng,
                    tz: p.tzIdentifier
                ),
                workStart: p.workStart, workEnd: p.workEnd
            )
            extraCities.append(entry)
        }
    }

    /// Add a city that has no members yet. Idempotent — refuses if the
    /// city already exists in `team`, `extraCities`, or `home`. Comparison
    /// is case-insensitive so manual entries like "tokyo" can't collide
    /// with the canonical "Tokyo" already in the catalog.
    public func addEmptyCity(_ city: City, workStart: Double = 9, workEnd: Double = 23) {
        if cityExists(city.name) { return }
        extraCities.append(EmptyCityRecord(city: city, workStart: workStart, workEnd: workEnd))
    }

    /// True iff a city by `name` is already known anywhere in app state.
    /// Used by the manual-add form to validate before submission.
    public func cityExists(_ name: String) -> Bool {
        let needle = name.lowercased()
        if home?.city.name.lowercased() == needle { return true }
        if team.contains(where: { $0.city.lowercased() == needle }) { return true }
        if extraCities.contains(where: { $0.city.name.lowercased() == needle }) { return true }
        return false
    }

    /// Wholesale delete: members in that city + extraCities entry. Refuses
    /// to delete home — caller must `setHomeCity(_:)` somewhere else first.
    public func deleteCity(_ city: String) {
        guard city != homeCity else { return }
        team.removeAll { $0.city == city }
        extraCities.removeAll { $0.city.name == city }
        hiddenCities.remove(city)
    }

    /// Set a different city as home. The previous home is preserved as an
    /// empty/extra-city card if no teammates were there.
    public func setHomeCity(_ city: String) {
        guard let oldHome = home, oldHome.city.name != city else { return }
        // Look up the destination's metadata. May come from a teammate's
        // city, an extraCities entry, or the catalog directly.
        var dest: EmptyCityRecord? = nil
        if let other = team.first(where: { $0.city == city }) {
            dest = EmptyCityRecord(
                city: City(
                    name: other.city, nameZh: other.cityZh,
                    country: other.country, flag: other.flag,
                    lat: other.lat, lng: other.lng,
                    tz: other.tzIdentifier
                ),
                workStart: other.workStart, workEnd: other.workEnd
            )
        } else if let rec = extraCities.first(where: { $0.city.name == city }) {
            dest = rec
        }
        guard let newHome = dest else { return }

        // Old home → demote to extraCities IF no teammates lived there.
        if !team.contains(where: { $0.city == oldHome.city.name }),
           !extraCities.contains(where: { $0.city.name == oldHome.city.name }) {
            extraCities.append(oldHome)
        }
        // New home → drop its extra-city placeholder if any (it lives in
        // the `home` slot now).
        extraCities.removeAll { $0.city.name == newHome.city.name }
        // Home cannot be hidden. If the new home was previously hidden,
        // un-hide it now or `scoringTeam` would still filter teammates in
        // that city out.
        hiddenCities.remove(newHome.city.name)

        home = newHome
        goLive()
    }

    /// First-launch handler. Called by OnboardingView once the user picks
    /// a city. No "me" teammate is created — home is just a top-level
    /// reference.
    public func completeOnboarding(home: City, workStart: Double = 9, workEnd: Double = 23) {
        self.home = EmptyCityRecord(city: home, workStart: workStart, workEnd: workEnd)
        // Strip any extraCities entry that collides with the new home.
        extraCities.removeAll { $0.city.name == home.name }
        // Home is never hidden — clear any stale hidden flag for it.
        hiddenCities.remove(home.name)
        team = CityCanonicalizer.normalize(team)
        hasOnboarded = true
        goLive()
    }

    private static func computeLiveHostHour(home: EmptyCityRecord?) -> Double? {
        guard let home = home,
              let tz = TimeZone(identifier: home.city.tz) else { return nil }
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.hour, .minute], from: now)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
    }
}
