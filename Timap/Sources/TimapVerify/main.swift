// TimapVerify — runtime checks for TimapCore logic.
// Acts as a stand-in for unit tests since CLT-only environments don't ship XCTest.
// Run with: `swift run TimapVerify`. Exits non-zero on first failure.

import Foundation
import TimapCore

private var failures = 0

private func check(_ ok: Bool, _ name: String, _ extra: String = "") {
    if ok {
        print("  ✓ \(name)")
    } else {
        print("  ✗ \(name) \(extra)")
        failures += 1
    }
}

private func approx(_ a: Double, _ b: Double, _ eps: Double = 0.001) -> Bool {
    abs(a - b) < eps
}

print("TimapVerify — TimapCore checks")
print("──────────────────────────────")

// hourInTz
do {
    let h = TimeMath.hourInTz(hostHour: 10, hostOffset: 8, targetOffset: -7)
    check(approx(h, 19), "hourInTz Beijing 10:00 → Seattle 19:00 (prev day)")

    let h2 = TimeMath.hourInTz(hostHour: 2, hostOffset: 8, targetOffset: -7)
    check(approx(h2, 11), "hourInTz Beijing 02:00 → Seattle 11:00 (prev day, wraps)")
}

// dayDelta
do {
    check(TimeMath.dayDelta(hostHour: 2, hostOffset: 8, targetOffset: -7) == -1,
          "dayDelta Beijing 02:00 → Seattle previous day")
    check(TimeMath.dayDelta(hostHour: 16, hostOffset: 8, targetOffset: -7) == 0,
          "dayDelta Beijing 16:00 → Seattle same day")
    check(TimeMath.dayDelta(hostHour: 22, hostOffset: 0, targetOffset: 9) == 1,
          "dayDelta London 22:00 → Tokyo next day")
}

// isInWorkHours
do {
    check(TimeMath.isInWorkHours(localHour: 14.5, workStart: 9, workEnd: 23), "14:30 in 9–23")
    check(!TimeMath.isInWorkHours(localHour: 23.0, workStart: 9, workEnd: 23), "23:00 NOT in 9–23 (exclusive end)")
    check(!TimeMath.isInWorkHours(localHour: 8.5, workStart: 9, workEnd: 23), "08:30 NOT in 9–23")
    check(TimeMath.isInWorkHours(localHour: 9.0, workStart: 9, workEnd: 23), "09:00 in 9–23 (inclusive start)")
    check(TimeMath.isInWorkHours(localHour: 12.0, workStart: 9.5, workEnd: 18.75), "12:00 in 9:30–18:45 (Double hours)")
    check(!TimeMath.isInWorkHours(localHour: 9.25, workStart: 9.5, workEnd: 18.75), "9:15 NOT in 9:30–18:45")
}

// findBestWindows
do {
    let team = DefaultTeam.teammates()
    let windows = TimeMath.findBestWindows(hostOffset: 8, team: team)
    check(!windows.isEmpty, "findBestWindows returns at least one slot for default team")
    if !windows.isEmpty {
        check(windows[0].minScore >= 0.5, "Top window minScore >= 0.5")
    }
}

// Teammate offset uses real TimeZone (DST-aware)
do {
    let mira = Teammate(
        name: "Mira", role: "Design",
        city: "Seattle", country: "US", flag: "🇺🇸",
        tzIdentifier: "America/Los_Angeles",
        lat: 47.6, lng: -122.3, colorHex: "#3b7a8c"
    )
    let off = mira.currentOffsetHours()
    check(off == -8 || off == -7, "Seattle current offset is either -8 (PST) or -7 (PDT), got \(off)")
}

// Storage round-trip — new model: home is a top-level slot, no me teammate
do {
    TeamStore.reset()
    let snap1 = TeamStore.load()
    check(snap1.team.count == 3, "Default team has 3 members on first load")
    check(snap1.home == nil, "First-load home is nil (not yet onboarded)")
    check(snap1.hasOnboarded == false, "First-load hasOnboarded == false")
    check(snap1.extraCities.isEmpty, "First-load extraCities is empty")

    let beijing = City(name: "Beijing", nameZh: "北京",
                      country: "CN", flag: "🇨🇳",
                      lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let home = EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23)
    let extras = [EmptyCityRecord(
        city: City(name: "Tokyo", nameZh: "东京",
                   country: "JP", flag: "🇯🇵",
                   lat: 35.7, lng: 139.7,
                   tz: "Asia/Tokyo"),
        workStart: 10, workEnd: 19
    )]
    TeamStore.save(team: snap1.team, home: home, extraCities: extras,
                   hiddenCities: [], hasOnboarded: true, language: .en)

    let snap2 = TeamStore.load()
    check(snap2.team.count == 3, "After save+reload, team count == 3 (no me teammate added)")
    check(snap2.hasOnboarded, "hasOnboarded round-trips")
    check(snap2.home?.city.name == "Beijing", "home round-trips")
    check(snap2.home?.workStart == 9, "home work hours round-trip")
    check(snap2.language == .en, "language round-trips")
    check(snap2.extraCities.count == 1 && snap2.extraCities.first?.city.name == "Tokyo",
          "extraCities round-trips through TeamStore")
    check(snap2.extraCities.first?.workStart == 10, "extraCities work hours round-trip")

    TeamStore.reset()
}

// Migration from old isMe-based persisted data → home record
do {
    TeamStore.reset()
    // Simulate a v3-era payload: a teammate JSON dict that includes isMe=true.
    let oldTeam: [[String: Any]] = [
        [
            "id": UUID().uuidString,
            "name": "You",
            "role": "Product",
            "city": "Beijing",
            "cityZh": "北京",
            "country": "CN",
            "flag": "🇨🇳",
            "tzIdentifier": "Asia/Shanghai",
            "lat": 39.9,
            "lng": 116.4,
            "workStart": 9,
            "workEnd": 22,
            "colorHex": "#c96442",
            "isMe": true
        ],
        [
            "id": UUID().uuidString,
            "name": "Mira Chen",
            "role": "Design Lead",
            "city": "Seattle",
            "cityZh": "西雅图",
            "country": "US",
            "flag": "🇺🇸",
            "tzIdentifier": "America/Los_Angeles",
            "lat": 47.6,
            "lng": -122.3,
            "workStart": 9,
            "workEnd": 23,
            "colorHex": "#3b7a8c",
            "isMe": false
        ]
    ]
    let data = try! JSONSerialization.data(withJSONObject: oldTeam)
    UserDefaults.standard.set(data, forKey: "timap.team")
    UserDefaults.standard.set(true, forKey: "timap.hasOnboarded")

    let snap = TeamStore.load()
    check(snap.team.count == 1, "Migration: isMe=true entry stripped from team")
    check(snap.team.first?.name == "Mira Chen", "Migration: non-isMe entry preserved")
    check(snap.home?.city.name == "Beijing", "Migration: home extracted from isMe entry")
    check(snap.home?.workStart == 9 && snap.home?.workEnd == 22,
          "Migration: home preserves the isMe entry's work hours")
    check(snap.hasOnboarded, "Migration: hasOnboarded persists post-migration")

    TeamStore.reset()
}

// L10n
do {
    check(L10n.t(.allInCore, .zh) == "全员都在工作时间", "zh: allInCore")
    check(L10n.t(.allInCore, .en) == "All in core hours", "en: allInCore")
    check(L10n.relDay(0, .zh) == "今天", "zh: relDay(0)")
    check(L10n.relDay(-1, .zh) == "昨天", "zh: relDay(-1)")
    check(L10n.relDay(1, .en) == "Tomorrow", "en: relDay(+1)")
    check(L10n.relDay(2, .zh) == "+2天", "zh: relDay(+2)")
    check(L10n.relDay(2, .en) == "+2d", "en: relDay(+2)")
    // First-load default is zh
    TeamStore.reset()
    let s = TeamStore.load()
    check(s.language == .zh, "Default language on first load is zh")
    TeamStore.reset()
}

// Geo: city pins must land on continents (the prototype iterations spent
// many rounds fixing this — these checks pin down the wins).
do {
    check(ContinentData.isLand(lng: 116.4, lat: 39.9), "Beijing on land")
    check(ContinentData.isLand(lng: -122.3, lat: 47.6), "Seattle on land")
    check(ContinentData.isLand(lng: -71.1, lat: 42.4), "Boston on land")
    check(ContinentData.isLand(lng: -87.6, lat: 41.9), "Chicago on land")
    check(ContinentData.isLand(lng: -0.1, lat: 51.5), "London on land")
    check(ContinentData.isLand(lng: 139.7, lat: 35.7), "Tokyo on land")
    check(!ContinentData.isLand(lng: 0, lat: 0), "Gulf of Guinea (0,0) is ocean")
    check(!ContinentData.isLand(lng: -150, lat: 0), "Pacific (−150, 0) is ocean")
    check(ContinentData.landDotsViewBox.count > 1000, "Pre-baked dot grid populated (>1000 dots)")
}

// Projection sanity
do {
    let bj = Projection.project(lng: 116.4, lat: 39.9)
    check(approx(bj.x, 822.5, 1) && approx(bj.y, 142.2, 1),
          "Beijing projects near (822, 142) in viewBox 1000×500", "got (\(bj.x), \(bj.y))")
    let sun0 = Projection.sunLongitude(utcHour: 0)
    check(approx(sun0, 180), "Sun at UTC 0 is at lng 180")
    let sun12 = Projection.sunLongitude(utcHour: 12)
    check(approx(sun12, 0), "Sun at UTC 12 is at lng 0 (Greenwich)")
}

// meetingScore — strict intersection: 1 if everyone in [workStart, workEnd), else 0.
do {
    let p = Teammate(name: "P", role: "", city: "Beijing", country: "CN", flag: "🇨🇳",
                     tzIdentifier: "Asia/Shanghai", lat: 39.9, lng: 116.4,
                     workStart: 9, workEnd: 23, colorHex: "#000")
    let off = p.currentOffsetHours()  // +8 today
    check(TimeMath.meetingScore(hostHour: 12, hostOffset: off, team: [p]) == 1.0,
          "12:00 within 9-23 → score 1")
    check(TimeMath.meetingScore(hostHour: 9, hostOffset: off, team: [p]) == 1.0,
          "09:00 (workStart) → score 1 (inclusive)")
    check(TimeMath.meetingScore(hostHour: 22.99, hostOffset: off, team: [p]) == 1.0,
          "22:59 → score 1 (still inside work)")
    // Right at workEnd → exclusive end, no borderline anymore
    check(TimeMath.meetingScore(hostHour: 23, hostOffset: off, team: [p]) == 0,
          "23:00 (workEnd) → 0 (exclusive end, no borderline)")
    check(TimeMath.meetingScore(hostHour: 23.4, hostOffset: off, team: [p]) == 0,
          "23:24 → 0 (past workEnd)")
    // Just before workStart → no borderline
    check(TimeMath.meetingScore(hostHour: 8.99, hostOffset: off, team: [p]) == 0,
          "08:59 → 0 (just before workStart)")
    check(TimeMath.meetingScore(hostHour: 8.0, hostOffset: off, team: [p]) == 0,
          "08:00 → 0 (before work)")
    check(TimeMath.meetingScore(hostHour: 24, hostOffset: off, team: [p]) == 0,
          "hostHour 24 → wraps to local 0 → score 0")
    // Empty team → vacuously 1 (no constraints to fail)
    check(TimeMath.meetingScore(hostHour: 12, hostOffset: 0, team: []) == 1.0,
          "Empty team → 1 (no constraints)")
}

// findBestWindows — strict intersection produces a single great window per overlap span
do {
    let p = Teammate(name: "P", role: "", city: "Beijing", country: "CN", flag: "🇨🇳",
                     tzIdentifier: "Asia/Shanghai", lat: 39.9, lng: 116.4,
                     workStart: 9, workEnd: 23, colorHex: "#000")
    let off = p.currentOffsetHours()
    let windows = TimeMath.findBestWindows(hostOffset: off, team: [p])
    // 9-23 worker: exactly one great window [9, 23), no amber.
    check(windows.count == 1, "9-23 worker yields exactly one window", "got \(windows.count)")
    if let g = windows.first {
        check(approx(g.minScore, 1, 0.01), "Score is 1 (strict intersection)")
        check(approx(g.start, 9, 0.01) && approx(g.end, 23, 0.01),
              "Window is [9, 23)", "got [\(g.start), \(g.end))")
    }
    // No amber bands under strict intersection
    let amber = windows.filter { $0.minScore < 0.95 && $0.minScore >= 0.5 }
    check(amber.isEmpty, "No amber bands under strict intersection", "got \(amber.count)")
}

// DST: teammate offset is evaluated at the host instant, not at "now".
// Spring 2026: PST→PDT transition is March 8 at 2 AM PST. Pick a host
// instant safely inside PDT (e.g. April 15) and one safely inside PST
// (e.g. February 15) and verify Mira's offset differs.
do {
    let mira = Teammate(name: "Mira", role: "",
                        city: "Seattle", country: "US", flag: "🇺🇸",
                        tzIdentifier: "America/Los_Angeles",
                        lat: 47.6, lng: -122.3,
                        workStart: 9, workEnd: 23, colorHex: "#000")
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let inPST = cal.date(from: DateComponents(year: 2026, month: 2, day: 15, hour: 12))!
    let inPDT = cal.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 12))!
    let pstOff = mira.currentOffsetHours(for: inPST)
    let pdtOff = mira.currentOffsetHours(for: inPDT)
    check(pstOff == -8, "Seattle is PST (-8) on Feb 15", "got \(pstOff)")
    check(pdtOff == -7, "Seattle is PDT (-7) on Apr 15", "got \(pdtOff)")

    // meetingScore must use the supplied instant. Same hostHour, same team,
    // but different instant → potentially different score (because Mira's
    // offset differs).
    let scorePST = TimeMath.meetingScore(
        hostHour: 23, hostOffset: 8, team: [mira], at: inPST
    )
    let scorePDT = TimeMath.meetingScore(
        hostHour: 23, hostOffset: 8, team: [mira], at: inPDT
    )
    // At Beijing 23:00 + PST (-8): Mira local = 23 - 8 - 8 = 7 (asleep) → score 0
    // At Beijing 23:00 + PDT (-7): Mira local = 23 - 8 - 7 = 8 (asleep) → score 0
    // Both 0 here, but the offsets differ — let me pick a better hour.
    _ = scorePST; _ = scorePDT  // silence unused

    // Pick host hour where PST keeps Mira just inside work and PDT pushes
    // her past workEnd. Beijing 14 + PST(-8): 14-8-8=-2→22 (in work, score 1).
    // Beijing 14 + PDT(-7): 14-8-7=-1→23 (≥workEnd, score 0).
    let s14PST = TimeMath.meetingScore(
        hostHour: 14, hostOffset: 8, team: [mira], at: inPST
    )
    let s14PDT = TimeMath.meetingScore(
        hostHour: 14, hostOffset: 8, team: [mira], at: inPDT
    )
    check(s14PST == 1 && s14PDT == 0,
          "DST: Beijing 14:00 → PST in-work (1), PDT past workEnd (0)",
          "PST=\(s14PST) PDT=\(s14PDT)")
}

// findBestWindows — Beijing host + Seattle teammate intersection
do {
    let beijing = Teammate(name: "_self", role: "",
                           city: "Beijing", country: "CN", flag: "🇨🇳",
                           tzIdentifier: "Asia/Shanghai", lat: 39.9, lng: 116.4,
                           workStart: 9, workEnd: 23, colorHex: "#000")
    let seattle = Teammate(name: "Mira", role: "",
                           city: "Seattle", country: "US", flag: "🇺🇸",
                           tzIdentifier: "America/Los_Angeles",
                           lat: 47.6, lng: -122.3,
                           workStart: 9, workEnd: 23, colorHex: "#000")
    let off = beijing.currentOffsetHours()
    let team = [beijing, seattle]
    let windows = TimeMath.findBestWindows(hostOffset: off, team: team)
    let great = windows.filter { $0.minScore >= 0.95 }
    check(great.count == 1, "Beijing+Seattle: one great window", "got \(great.count)")
    if let g = great.first {
        // Seattle 9 AM = Beijing midnight; Seattle 11 PM = Beijing 14:00.
        // Beijing user 9-23 ∩ Seattle's Beijing-time work [0, 14) = [9, 14).
        // Today's offsets depend on DST: PST(-8) gives [9,15), PDT(-7) gives [9,14).
        let validEnd = approx(g.end, 14, 0.01) || approx(g.end, 15, 0.01)
        check(approx(g.start, 9, 0.01) && validEnd,
              "Beijing+Seattle great window starts at 9 ends at 14 (PDT) or 15 (PST)",
              "got [\(g.start), \(g.end))")
    }
}

// meetingScore regression: home asleep blocks scoring
do {
    let mira = Teammate(name: "Mira", role: "Design",
                        city: "Seattle", country: "US", flag: "🇺🇸",
                        tzIdentifier: "America/Los_Angeles",
                        lat: 47.6, lng: -122.3,
                        workStart: 9, workEnd: 23, colorHex: "#3b7a8c")
    let jordan = Teammate(name: "Jordan", role: "Eng",
                          city: "Boston", country: "US", flag: "🇺🇸",
                          tzIdentifier: "America/New_York",
                          lat: 42.4, lng: -71.1,
                          workStart: 9, workEnd: 23, colorHex: "#7a5ca8")
    let sam = Teammate(name: "Sam", role: "PM",
                       city: "Chicago", country: "US", flag: "🇺🇸",
                       tzIdentifier: "America/Chicago",
                       lat: 41.9, lng: -87.6,
                       workStart: 9, workEnd: 23, colorHex: "#c8924a")
    let team = [mira, jordan, sam]
    // host offset for Beijing = +8
    let hostOff: Double = 8

    let middayScore = TimeMath.meetingScore(hostHour: 10, hostOffset: hostOff, team: team)
    check(middayScore == 1, "10am Beijing host: score 1 (all 3 in work under strict intersection)",
          "got \(middayScore)")
}

// Intersection coverage — strict semantics across team sizes and edge cases.
// Use fixed-offset zones so results don't depend on DST or wall-clock date.
do {
    func teammate(name: String, offset: Double, ws: Double = 9, we: Double = 23) -> Teammate {
        let tz = "Etc/GMT" + (offset >= 0 ? "-\(Int(offset))" : "+\(Int(-offset))")
        return Teammate(
            name: name, role: "", city: name, country: "", flag: "",
            tzIdentifier: tz, lat: 0, lng: 0,
            workStart: ws, workEnd: we, colorHex: "#000"
        )
    }

    // Sanity: Etc/GMT signs are reversed — Etc/GMT-8 is UTC+8.
    let beijingProbe = teammate(name: "BJ", offset: 8)
    check(beijingProbe.currentOffsetHours() == 8, "Etc/GMT-8 → +8h offset",
          "got \(beijingProbe.currentOffsetHours())")
    let seattleProbe = teammate(name: "SEA", offset: -7)
    check(seattleProbe.currentOffsetHours() == -7, "Etc/GMT+7 → -7h offset",
          "got \(seattleProbe.currentOffsetHours())")

    // Single-city: window equals work hours.
    do {
        let bj = teammate(name: "BJ", offset: 8)
        let wins = TimeMath.findBestWindows(hostOffset: 8, team: [bj])
        check(wins.count == 1 && approx(wins[0].start, 9) && approx(wins[0].end, 23),
              "Single Beijing 9-23 → window [9, 23)", "got \(wins)")
    }

    // The exact bug-report scenario: Beijing host + Boston (-12) + Chicago (-13)
    // + Seattle (-15), all 9-23. Strict intersection should be Beijing [9, 11).
    do {
        let bj  = teammate(name: "BJ",  offset: 8)
        let bos = teammate(name: "BOS", offset: -4)   // EDT, Beijing - 12h
        let chi = teammate(name: "CHI", offset: -5)   // CDT, Beijing - 13h
        let sea = teammate(name: "SEA", offset: -7)   // PDT, Beijing - 15h
        let wins = TimeMath.findBestWindows(hostOffset: 8, team: [bj, bos, chi, sea])
        check(wins.count == 1, "BJ+BOS+CHI+SEA all 9-23 → exactly one window",
              "got \(wins.count): \(wins)")
        if let w = wins.first {
            check(approx(w.start, 9) && approx(w.end, 11),
                  "Window is [9, 11) — Boston caps at 23:00→Beijing 11:00",
                  "got [\(w.start), \(w.end))")
            check(w.minScore == 1, "Score is 1")
        }
        // Slot-by-slot spot checks
        check(TimeMath.meetingScore(hostHour: 10, hostOffset: 8, team: [bj, bos, chi, sea]) == 1,
              "Beijing 10:00 → all 4 in work (score 1)")
        check(TimeMath.meetingScore(hostHour: 11, hostOffset: 8, team: [bj, bos, chi, sea]) == 0,
              "Beijing 11:00 → Boston at 23:00 (workEnd exclusive) → score 0")
        check(TimeMath.meetingScore(hostHour: 12, hostOffset: 8, team: [bj, bos, chi, sea]) == 0,
              "Beijing 12:00 → Boston at 00:00 (asleep) → score 0")
        check(TimeMath.meetingScore(hostHour: 14, hostOffset: 8, team: [bj, bos, chi, sea]) == 0,
              "Beijing 14:00 → Boston at 02:00 (asleep) → score 0 (the screenshot bug)")
    }

    // Two-city offset of 12h with 9-23 hours → 2 hour overlap window.
    do {
        let a = teammate(name: "A", offset: 0)   // UTC
        let b = teammate(name: "B", offset: 12)  // UTC+12
        let wins = TimeMath.findBestWindows(hostOffset: 0, team: [a, b])
        // a in [9,23). For b to be in [9,23) local, host must be in [-3, 11) mod 24 = [0,11) ∪ [21,24).
        // Intersection with [9,23): [9, 11) and [21, 23).
        check(wins.count == 2, "12h split → two windows", "got \(wins.count)")
        let sorted = wins.sorted { $0.start < $1.start }
        check(approx(sorted[0].start, 9) && approx(sorted[0].end, 11),
              "Morning window [9, 11)", "got [\(sorted[0].start), \(sorted[0].end))")
        check(approx(sorted[1].start, 21) && approx(sorted[1].end, 23),
              "Evening window [21, 23)", "got [\(sorted[1].start), \(sorted[1].end))")
    }

    // No overlap: host 9-12 and partner 9-12 at +12h offset → no window.
    do {
        let a = teammate(name: "A", offset: 0,  ws: 9, we: 12)
        let b = teammate(name: "B", offset: 12, ws: 9, we: 12)
        let wins = TimeMath.findBestWindows(hostOffset: 0, team: [a, b])
        check(wins.isEmpty, "No overlap → no windows", "got \(wins.count)")
    }

    // Hidden teammates must not constrain — caller filters before passing in.
    do {
        let bj  = teammate(name: "BJ",  offset: 8)
        let bos = teammate(name: "BOS", offset: -4)
        // With Boston (12h offset): two narrow windows — morning [9, 11) and
        // evening [21, 23) where the two work-hour bands overlap.
        let bothWins = TimeMath.findBestWindows(hostOffset: 8, team: [bj, bos])
            .sorted { $0.start < $1.start }
        check(bothWins.count == 2, "BJ+BOS → two windows (12h split)", "got \(bothWins.count)")
        if bothWins.count == 2 {
            check(approx(bothWins[0].start, 9) && approx(bothWins[0].end, 11),
                  "Morning [9, 11)", "got [\(bothWins[0].start), \(bothWins[0].end))")
            check(approx(bothWins[1].start, 21) && approx(bothWins[1].end, 23),
                  "Evening [21, 23)", "got [\(bothWins[1].start), \(bothWins[1].end))")
        }
        // Without Boston (caller hid it): single window expands to [9, 23).
        let bjOnly = TimeMath.findBestWindows(hostOffset: 8, team: [bj])
        check(bjOnly.count == 1 && approx(bjOnly[0].end, 23),
              "BJ alone → window expands to 23", "got \(bjOnly)")
    }

    // Custom work hours per city are honored (e.g. Tokyo 10-19).
    do {
        let tokyo = teammate(name: "TYO", offset: 9, ws: 10, we: 19)
        let bj    = teammate(name: "BJ",  offset: 8, ws: 9,  we: 23)
        // Tokyo 10-19 in Beijing time: Tokyo h = host - 8 + 9 = host + 1.
        // 10 ≤ host+1 < 19 → 9 ≤ host < 18.
        // Intersect Beijing [9, 23) → [9, 18).
        let wins = TimeMath.findBestWindows(hostOffset: 8, team: [bj, tokyo])
        check(wins.count == 1, "BJ+TYO → one window", "got \(wins.count)")
        if let w = wins.first {
            check(approx(w.start, 9) && approx(w.end, 18),
                  "Custom Tokyo 10-19 → window [9, 18) in Beijing",
                  "got [\(w.start), \(w.end))")
        }
    }

    // Half-hour work hours are honored (e.g. 9:30-17:30).
    do {
        let p = teammate(name: "P", offset: 0, ws: 9.5, we: 17.5)
        let wins = TimeMath.findBestWindows(hostOffset: 0, team: [p])
        check(wins.count == 1, "Half-hour work hours → one window")
        if let w = wins.first {
            check(approx(w.start, 9.5) && approx(w.end, 17.5),
                  "Window respects 0.5h grid", "got [\(w.start), \(w.end))")
        }
    }

    // Three cities forming a tight overlap — confirm the algorithm doesn't
    // accidentally widen past any single member's bounds.
    do {
        let a = teammate(name: "A", offset: 0,   ws: 10, we: 14)
        let b = teammate(name: "B", offset: 1,   ws: 10, we: 14)  // 9-13 in A's tz
        let c = teammate(name: "C", offset: -1,  ws: 10, we: 14)  // 11-15 in A's tz
        // Intersection in A's tz: max(10, 9, 11) to min(14, 13, 15) = [11, 13).
        let wins = TimeMath.findBestWindows(hostOffset: 0, team: [a, b, c])
        check(wins.count == 1, "Triple overlap → one window", "got \(wins.count)")
        if let w = wins.first {
            check(approx(w.start, 11) && approx(w.end, 13),
                  "Tight overlap [11, 13)", "got [\(w.start), \(w.end))")
        }
    }
}

// CityCatalog: bundled JSON loads
do {
    let cities = CityCatalog.all
    check(cities.count >= 50, "CityCatalog loaded ≥50 cities, got \(cities.count)")
    check(cities.contains { $0.name == "Beijing" }, "Catalog contains Beijing")
    check(cities.contains { $0.name == "London" }, "Catalog contains London")
    let london = CityCatalog.search("lon", limit: 5)
    check(london.contains { $0.name == "London" }, "Search 'lon' returns London")
    let empty = CityCatalog.search("", limit: 8)
    check(empty.count == 8, "Empty search returns 8 results (or all if fewer), got \(empty.count)")
}

// CityCanonicalizer: collapse "西雅图" / "Seattle" duplicates so the
// settings work-hours panel + the city-card list both show one entry.
do {
    let mira = Teammate(
        name: "Mira Chen", role: "Design Lead",
        city: "Seattle", cityZh: "西雅图", country: "US", flag: "🇺🇸",
        tzIdentifier: "America/Los_Angeles", lat: 47.6, lng: -122.3,
        workStart: 7, workEnd: 23, colorHex: "#3b7a8c"
    )
    // Adversarial input: city stored as the Chinese name.
    let teemo = Teammate(
        name: "Teemo", role: "",
        city: "西雅图", country: "US", flag: "🇺🇸",
        tzIdentifier: "America/Los_Angeles", lat: 47.6, lng: -122.3,
        workStart: 9, workEnd: 23, colorHex: "#3b8c7a"
    )
    let normalized = CityCanonicalizer.normalize([mira, teemo])
    let cities = Set(normalized.map(\.city))
    check(cities.contains("Seattle") && !cities.contains("西雅图"),
          "Canonicalize: 西雅图 → Seattle")
    let seattleMembers = normalized.filter { $0.city == "Seattle" }
    check(seattleMembers.count == 2, "Both Mira and Teemo end up in Seattle")
    let starts = Set(seattleMembers.map(\.workStart))
    check(starts.count == 1, "Seattle members share a single workStart after sync")
    // Anchor preference (no host concept now): alphabetical → Mira (M < T)
    check(starts.first == 7.0, "Sync used Mira's 7 (alphabetical anchor) for Seattle")
}

// CityGroup.group sort modes — settings list keeps insertion order so a
// newly-added city always sits at the bottom near the "+" button, even
// when its UTC offset would place it elsewhere. Regression-prone: every
// time the home and settings views share the same `citiesGrouped` API,
// this guarantee evaporates.
do {
    let beijing = City(name: "Beijing", nameZh: "北京",
                       country: "CN", flag: "🇨🇳",
                       lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let tokyo = City(name: "Tokyo", nameZh: "东京",
                     country: "JP", flag: "🇯🇵",
                     lat: 35.7, lng: 139.7, tz: "Asia/Tokyo")
    let london = City(name: "London", nameZh: "伦敦",
                      country: "GB", flag: "🇬🇧",
                      lat: 51.5, lng: -0.1, tz: "Europe/London")
    let home = EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23)
    let extras = [
        EmptyCityRecord(city: tokyo,  workStart: 9, workEnd: 23),
        EmptyCityRecord(city: london, workStart: 9, workEnd: 23),
    ]

    // Default `.byOffset` ordering — Tokyo (+9) > Beijing (+8) > London (~0)
    // → home first, then by offset desc → Beijing, Tokyo, London.
    let byOffset = CityGroup.group(team: [], home: home, extraCities: extras)
    check(byOffset.map(\.city) == ["Beijing", "Tokyo", "London"],
          "byOffset: home first, then by UTC offset descending",
          "got \(byOffset.map(\.city))")

    // `.insertion` ordering — home first, then extraCities in the order
    // they were added (Tokyo before London). The settings list MUST use
    // this so newly-added cities don't jump to the middle by offset.
    let byInsertion = CityGroup.group(
        team: [], home: home, extraCities: extras, sort: .insertion
    )
    check(byInsertion.map(\.city) == ["Beijing", "Tokyo", "London"],
          ".insertion: home first, then extraCities in add order",
          "got \(byInsertion.map(\.city))")

    // The actual regression scenario: add London FIRST (low offset), then
    // Tokyo (high offset). `byOffset` would surface Tokyo above London;
    // `.insertion` must keep London before Tokyo.
    let extrasReversed = [
        EmptyCityRecord(city: london, workStart: 9, workEnd: 23),
        EmptyCityRecord(city: tokyo,  workStart: 9, workEnd: 23),
    ]
    let regression = CityGroup.group(
        team: [], home: home, extraCities: extrasReversed, sort: .insertion
    )
    check(regression.map(\.city) == ["Beijing", "London", "Tokyo"],
          ".insertion: a low-offset city added first stays above a high-offset city added later",
          "got \(regression.map(\.city))")
    let regressionByOffset = CityGroup.group(
        team: [], home: home, extraCities: extrasReversed
    )
    check(regressionByOffset.map(\.city) == ["Beijing", "Tokyo", "London"],
          "byOffset reorders the same input by UTC — these two modes MUST stay distinct",
          "got \(regressionByOffset.map(\.city))")
}

// CityGroup.group with home record
do {
    let beijing = City(name: "Beijing", nameZh: "北京",
                       country: "CN", flag: "🇨🇳",
                       lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let home = EmptyCityRecord(city: beijing, workStart: 9, workEnd: 22)
    let mira = Teammate(
        name: "Mira Chen", role: "Design Lead",
        city: "Seattle", country: "US", flag: "🇺🇸",
        tzIdentifier: "America/Los_Angeles", lat: 47.6, lng: -122.3,
        colorHex: "#3b7a8c"
    )
    let jordan = Teammate(
        name: "Jordan Park", role: "Engineer",
        city: "Boston", country: "US", flag: "🇺🇸",
        tzIdentifier: "America/New_York", lat: 42.4, lng: -71.1,
        colorHex: "#7a5ca8"
    )
    let sam = Teammate(
        name: "Sam Okafor", role: "PM",
        city: "Chicago", country: "US", flag: "🇺🇸",
        tzIdentifier: "America/Chicago", lat: 41.9, lng: -87.6,
        colorHex: "#c8924a"
    )
    let groups = CityGroup.group(team: [mira, jordan, sam], home: home)
    check(groups.count == 4, "Home + 3 non-home cities = 4 groups")
    check(groups.first?.isHome == true, "Home sorts first")
    check(groups.first?.city == "Beijing", "Home is Beijing")
    check(groups.first?.members.isEmpty == true, "Home has no members (no me teammate)")
    check(groups.first?.workStart == 9 && groups.first?.workEnd == 22,
          "Home work hours come from the home record, not a teammate")

    // Two members in one city should collapse to one card
    let mira2 = Teammate(
        name: "Aria Lin", role: "Researcher",
        city: "Seattle", country: "US", flag: "🇺🇸",
        tzIdentifier: "America/Los_Angeles", lat: 47.6, lng: -122.3,
        colorHex: "#5588aa"
    )
    let groupsB = CityGroup.group(team: [mira, mira2], home: home)
    check(groupsB.count == 2, "Two Seattle teammates → one Seattle card; home stays = 2 total")
    let seattle = groupsB.first { $0.city == "Seattle" }
    check(seattle?.members.count == 2, "Seattle group contains 2 members")

    // Hidden cities: home never gets hidden; non-home are sorted to bottom
    let groupsC = CityGroup.group(
        team: [mira, jordan, sam], home: home,
        hiddenCities: ["Boston", "Chicago"]
    )
    check(groupsC.count == 4, "Hidden cities still appear in the group list")
    check(groupsC.first?.city == "Beijing" && groupsC.first?.isHome == true,
          "Home stays first regardless of hidden flags")
    check(groupsC[1].city == "Seattle" && !groupsC[1].isHidden,
          "Visible non-home cities come before hidden ones")
    check(groupsC[2].isHidden && groupsC[3].isHidden,
          "Hidden cities sit at the bottom of the list")
}

// Members in home city render as chips on the home card (no "you" entry)
do {
    let beijing = City(name: "Beijing", nameZh: "北京",
                       country: "CN", flag: "🇨🇳",
                       lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let home = EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23)
    let coworker = Teammate(
        name: "王芳", role: "Designer",
        city: "Beijing", cityZh: "北京", country: "CN", flag: "🇨🇳",
        tzIdentifier: "Asia/Shanghai", lat: 39.9, lng: 116.4,
        workStart: 9, workEnd: 23, colorHex: "#7a5ca8"
    )
    let groups = CityGroup.group(team: [coworker], home: home)
    let homeCard = groups.first { $0.isHome }
    check(homeCard?.members.count == 1, "Home card shows the local coworker as a chip")
    check(homeCard?.members.first?.name == "王芳",
          "Local coworker (not 'you') shown by name")
}

// LabelPlacer.placeCities separates close labels and dedupes per city
do {
    let mira = Teammate(name: "Mira", role: "", city: "Seattle", country: "US", flag: "",
                        tzIdentifier: "America/Los_Angeles", lat: 47.6, lng: -122.3, colorHex: "#fff")
    let teemo = Teammate(name: "Teemo", role: "", city: "Seattle", country: "US", flag: "",
                         tzIdentifier: "America/Los_Angeles", lat: 47.6, lng: -122.3, colorHex: "#fff")
    let jordan = Teammate(name: "Jordan", role: "", city: "Boston", country: "US", flag: "",
                          tzIdentifier: "America/New_York", lat: 42.4, lng: -71.1, colorHex: "#fff")
    let groups = CityGroup.group(team: [mira, teemo, jordan])
    let placed = LabelPlacer.placeCities(groups)
    check(placed.count == 2, "placeCities returns one entry per city, not per teammate (2 cities, 3 members)")
    check(Set(placed.map(\.cityID)) == ["Seattle", "Boston"], "placeCities cityIDs are city names")
}

// LabelPlacer pushes close-latitude labels apart
do {
    let aP = Teammate(name: "A", role: "", city: "Aville", country: "", flag: "",
                      tzIdentifier: "UTC", lat: 42.0, lng: -71.0, colorHex: "#fff")
    let bP = Teammate(name: "B", role: "", city: "Bville", country: "", flag: "",
                      tzIdentifier: "UTC", lat: 42.0, lng: -88.0, colorHex: "#fff")
    let groups = CityGroup.group(team: [aP, bP])
    let placed = LabelPlacer.placeCities(groups)
    let dys = placed.map(\.dy)
    check(dys.contains { $0 != 0 }, "Co-located labels get separated")
}

// LabelPlacer regression: a city on one side of the world must not push
// labels on the opposite side off the map. Bug report: hiding Boston
// "fixes" Nanjing's label, even though they're on opposite continents.
do {
    let seattle = Teammate(name: "S", role: "", city: "Seattle", country: "US", flag: "",
                           tzIdentifier: "America/Los_Angeles", lat: 47.6, lng: -122.3, colorHex: "#fff")
    let chicago = Teammate(name: "C", role: "", city: "Chicago", country: "US", flag: "",
                           tzIdentifier: "America/Chicago", lat: 41.9, lng: -87.6, colorHex: "#fff")
    let boston  = Teammate(name: "B", role: "", city: "Boston",  country: "US", flag: "",
                           tzIdentifier: "America/New_York", lat: 42.4, lng: -71.1, colorHex: "#fff")
    let beijing = Teammate(name: "BJ", role: "", city: "Beijing", country: "CN", flag: "",
                           tzIdentifier: "Asia/Shanghai", lat: 39.9, lng: 116.4, colorHex: "#fff")
    let nanjing = Teammate(name: "NJ", role: "", city: "Nanjing", country: "CN", flag: "",
                           tzIdentifier: "Asia/Shanghai", lat: 32.0, lng: 118.8, colorHex: "#fff")

    let withBoston = LabelPlacer.placeCities(
        CityGroup.group(team: [seattle, chicago, boston, beijing, nanjing])
    )
    let withoutBoston = LabelPlacer.placeCities(
        CityGroup.group(team: [seattle, chicago, beijing, nanjing])
    )

    func y(_ ps: [LabelPlacer.PlacedCity], _ id: String) -> Double {
        ps.first { $0.cityID == id }?.labelYPct ?? -1
    }
    let nWith = y(withBoston, "Nanjing")
    let nWithout = y(withoutBoston, "Nanjing")
    check(approx(nWith, nWithout, 0.01),
          "Boston visibility does not affect Nanjing's label position",
          "with=\(nWith) without=\(nWithout)")
    // And every label stays within the map viewport.
    for p in withBoston {
        check(p.labelYPct >= 0 && p.labelYPct <= 100,
              "Label \(p.cityID) y stays in [0,100]",
              "got \(p.labelYPct)")
    }
}

// Initials helper (from JSX d_initialsOf)
do {
    check(Initials.of("王芳") == "王芳", "Initials: 2-char CJK keeps both")
    check(Initials.of("张三丰") == "三丰", "Initials: 3-char CJK takes last 2")
    check(Initials.of("欧阳娜娜") == "娜娜", "Initials: 4-char CJK takes last 2")
    check(Initials.of("Mira Chen") == "MC", "Initials: two-word Latin → first letters")
    check(Initials.of("madonna") == "M", "Initials: single-word Latin → just the first letter")
    check(Initials.of("ada") == "A", "Initials: single-word, even short → just first letter")
    check(Initials.of("") == "?", "Initials: empty falls back to ?")
    check(Initials.hasCJK("Tokyo") == false, "hasCJK: Latin name → false")
    check(Initials.hasCJK("东京") == true, "hasCJK: Chinese name → true")
}

// Palette deterministic color
do {
    let a = Palette.color(for: "Tokyo")
    let b = Palette.color(for: "Tokyo")
    check(a == b, "Palette is deterministic for the same seed")
    check(Palette.colors.contains(a), "Palette pick is from the canonical 8-color set")
}

// AppState.scoringTeam includes home + extraCities, not just `team`.
// This is the exact bug report scenario: home=Beijing, team=[Seattle teammate],
// extraCities=[Chicago, Boston] — strict intersection must give [9, 11) Beijing.
@MainActor func runScoringTeamCoverageTest() {
    let beijing = City(name: "Beijing", nameZh: "北京",
                       country: "CN", flag: "🇨🇳",
                       lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let chicago = City(name: "Chicago", nameZh: "芝加哥",
                       country: "US", flag: "🇺🇸",
                       lat: 41.9, lng: -87.6, tz: "America/Chicago")
    let boston = City(name: "Boston", nameZh: "波士顿",
                      country: "US", flag: "🇺🇸",
                      lat: 42.4, lng: -71.1, tz: "America/New_York")
    let mira = Teammate(
        name: "张中豪", role: "",
        city: "Seattle", cityZh: "西雅图",
        country: "US", flag: "🇺🇸",
        tzIdentifier: "America/Los_Angeles",
        lat: 47.6, lng: -122.3,
        workStart: 9, workEnd: 23, colorHex: "#c75a92"
    )
    let state = AppState(
        team: [mira],
        home: EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23),
        extraCities: [
            EmptyCityRecord(city: chicago, workStart: 9, workEnd: 23),
            EmptyCityRecord(city: boston,  workStart: 9, workEnd: 23),
        ],
        hiddenCities: [],
        hasOnboarded: true,
        language: .zh
    )
    // scoringTeam must include all 4 cities (1 real + home + 2 extras).
    let cities = Set(state.scoringTeam.map(\.city))
    check(cities == ["Beijing", "Seattle", "Chicago", "Boston"],
          "scoringTeam covers home + team + extraCities",
          "got \(cities)")

    // Hide Boston → it should drop from scoringTeam.
    state.hiddenCities.insert("Boston")
    let afterHide = Set(state.scoringTeam.map(\.city))
    check(afterHide == ["Beijing", "Seattle", "Chicago"],
          "Hiding Boston removes it from scoringTeam",
          "got \(afterHide)")
    state.hiddenCities.remove("Boston")

    // The suggestion must be [9, 11) Beijing (Boston caps at 11:00 because
    // 11:00 Beijing = 23:00 Boston which is exclusive workEnd).
    let wins = TimeMath.findBestWindows(
        hostDate: state.hostDate, hostTimeZone: state.hostTimeZone,
        team: state.scoringTeam
    )
    check(wins.count == 1, "BJ host + SEA + CHI + BOS → exactly one window",
          "got \(wins.count)")
    if let w = wins.first {
        check(approx(w.start, 9, 0.01) && approx(w.end, 11, 0.01),
              "Window is [9, 11) — matches the user's scenario",
              "got [\(w.start), \(w.end))")
    }

    // Hiding Boston should expand the window (the next constraint is Chicago
    // at 23:00 = Beijing 12:00, so window grows to [9, 12)).
    state.hiddenCities.insert("Boston")
    let winsNoBos = TimeMath.findBestWindows(
        hostDate: state.hostDate, hostTimeZone: state.hostTimeZone,
        team: state.scoringTeam
    )
    if let w = winsNoBos.first {
        check(approx(w.end, 12, 0.01),
              "Without Boston, window grows to [9, 12) (Chicago is now binding)",
              "got [\(w.start), \(w.end))")
    }
    state.hiddenCities.remove("Boston")
}

// setCityWorkHours quantizes to 0.5h grid and updates scoringTeam, so a
// settings-page edit immediately reflects in the home suggestion window.
@MainActor func runWorkHoursLiveRefreshTest() {
    let beijing = City(name: "Beijing", nameZh: "北京",
                       country: "CN", flag: "🇨🇳",
                       lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let state = AppState(
        team: [],
        home: EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23),
        extraCities: [],
        hiddenCities: [],
        hasOnboarded: true,
        language: .zh
    )
    // Initial: home work 9-23 → window [9, 23) Beijing.
    let w0 = TimeMath.findBestWindows(
        hostDate: state.hostDate, hostTimeZone: state.hostTimeZone, team: state.scoringTeam
    )
    check(w0.count == 1 && approx(w0[0].start, 9) && approx(w0[0].end, 23),
          "Pre-edit window [9, 23)", "got \(w0)")

    // Simulate user dragging start handle to 9:30 in settings.
    state.setCityWorkHours("Beijing", start: 9.5, end: 23)
    check(state.home?.workStart == 9.5,
          "home.workStart updated to 9.5", "got \(state.home?.workStart ?? -1)")

    let w1 = TimeMath.findBestWindows(
        hostDate: state.hostDate, hostTimeZone: state.hostTimeZone, team: state.scoringTeam
    )
    check(w1.count == 1 && approx(w1[0].start, 9.5) && approx(w1[0].end, 23),
          "After edit, suggestion shifts to [9:30, 23)", "got \(w1)")

    // Non-grid value gets quantized.
    state.setCityWorkHours("Beijing", start: 9.75, end: 23)
    check(state.home?.workStart == 10,
          "9.75 quantizes up to 10", "got \(state.home?.workStart ?? -1)")
    state.setCityWorkHours("Beijing", start: 9.2, end: 23)
    check(state.home?.workStart == 9,
          "9.2 quantizes down to 9", "got \(state.home?.workStart ?? -1)")

    // citiesGrouped — the source the home view's CityCardView reads —
    // must reflect the latest work-hour edit, not a stale snapshot.
    state.setCityWorkHours("Beijing", start: 9.5, end: 22)
    let bjGroup = state.citiesGrouped.first { $0.city == "Beijing" }
    check(bjGroup?.workStart == 9.5 && bjGroup?.workEnd == 22,
          "citiesGrouped reflects edit immediately",
          "got \(bjGroup?.workStart ?? -1)-\(bjGroup?.workEnd ?? -1)")
}
Task { @MainActor in runWorkHoursLiveRefreshTest() }
RunLoop.main.run(until: Date().addingTimeInterval(0.05))

// scoringTeam dedup: a city must contribute at most one constraint, even
// when it appears in multiple sources (Codex review finding).
@MainActor func runScoringTeamDedupTest() {
    let beijing = City(name: "Beijing", nameZh: "北京",
                       country: "CN", flag: "🇨🇳",
                       lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let seattle = City(name: "Seattle", nameZh: "西雅图",
                       country: "US", flag: "🇺🇸",
                       lat: 47.6, lng: -122.3, tz: "America/Los_Angeles")

    // 1) Teammate in home city — home wins, teammate dedup'd out.
    do {
        let mira = Teammate(
            name: "Mira", role: "",
            city: "Beijing", cityZh: "北京", country: "CN", flag: "🇨🇳",
            tzIdentifier: "Asia/Shanghai", lat: 39.9, lng: 116.4,
            workStart: 10, workEnd: 18, colorHex: "#000"
        )
        let state = AppState(
            team: [mira],
            home: EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23),
            extraCities: [],
            hiddenCities: [],
            hasOnboarded: true,
            language: .zh
        )
        let bjEntries = state.scoringTeam.filter { $0.city == "Beijing" }
        check(bjEntries.count == 1, "home + teammate same city → single entry",
              "got \(bjEntries.count)")
        check(bjEntries.first?.workStart == 9 && bjEntries.first?.workEnd == 23,
              "Home record wins for shared city",
              "got \(bjEntries.first?.workStart ?? -1)-\(bjEntries.first?.workEnd ?? -1)")
    }

    // 2) Same city in team and extraCities — first occurrence wins, no
    // double-counting (the bug Codex flagged).
    do {
        let teemo = Teammate(
            name: "Teemo", role: "",
            city: "Seattle", cityZh: "西雅图", country: "US", flag: "🇺🇸",
            tzIdentifier: "America/Los_Angeles", lat: 47.6, lng: -122.3,
            workStart: 9, workEnd: 23, colorHex: "#000"
        )
        let state = AppState(
            team: [teemo],
            home: EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23),
            extraCities: [EmptyCityRecord(city: seattle, workStart: 9, workEnd: 23)],
            hiddenCities: [],
            hasOnboarded: true,
            language: .zh
        )
        let seaEntries = state.scoringTeam.filter { $0.city == "Seattle" }
        check(seaEntries.count == 1, "team + extraCities same city → single entry",
              "got \(seaEntries.count)")
    }
}
Task { @MainActor in runScoringTeamDedupTest() }
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
Task { @MainActor in runScoringTeamCoverageTest() }
RunLoop.main.run(until: Date().addingTimeInterval(0.05))

// AppState.setHomeCity clears hiddenCities for the new home
@MainActor func runHomeHiddenTest() {
    let beijing = City(name: "Beijing", nameZh: "北京",
                       country: "CN", flag: "🇨🇳",
                       lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let seattle = City(name: "Seattle", nameZh: "西雅图",
                       country: "US", flag: "🇺🇸",
                       lat: 47.6, lng: -122.3,
                       tz: "America/Los_Angeles")
    let state = AppState(
        team: [Teammate(name: "Mira", role: "",
                        city: "Seattle", cityZh: "西雅图",
                        country: "US", flag: "🇺🇸",
                        tzIdentifier: "America/Los_Angeles",
                        lat: 47.6, lng: -122.3,
                        workStart: 9, workEnd: 23, colorHex: "#000")],
        home: EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23),
        extraCities: [EmptyCityRecord(city: seattle, workStart: 9, workEnd: 23)],
        hiddenCities: ["Seattle"],
        hasOnboarded: true,
        language: .en
    )
    // Sanity: Seattle is hidden, scoringTeam excludes Mira before swap
    let teamCountBefore = state.scoringTeam.filter { $0.city == "Seattle" }.count
    check(teamCountBefore == 0, "Mira filtered from scoringTeam while Seattle hidden")

    // Promote Seattle to home
    state.setHomeCity("Seattle")
    check(!state.hiddenCities.contains("Seattle"),
          "After setHomeCity('Seattle'), hiddenCities no longer contains Seattle")
    // After promotion Seattle is the home; the dedup keeps a single Seattle
    // entry in scoringTeam (the home virtual). What matters is that Mira's
    // city is no longer filtered out.
    check(state.scoringTeam.contains { $0.city == "Seattle" },
          "After promotion, Seattle is represented in scoringTeam")
}
Task { @MainActor in runHomeHiddenTest() }
// Run synchronously since the rest of the file is sync. The Task above
// schedules onto the main actor; in this single-threaded CLI the next
// statement runs after it completes because Verify uses a synchronous
// run loop (Foundation's main RunLoop is implicit at exit).
RunLoop.main.run(until: Date().addingTimeInterval(0.05))

// Empty city support
do {
    let beijing = City(name: "Beijing", nameZh: "北京",
                       country: "CN", flag: "🇨🇳",
                       lat: 39.9, lng: 116.4, tz: "Asia/Shanghai")
    let home = EmptyCityRecord(city: beijing, workStart: 9, workEnd: 23)
    let extra = EmptyCityRecord(
        city: City(name: "Tokyo", nameZh: "东京",
                   country: "JP", flag: "🇯🇵",
                   lat: 35.7, lng: 139.7,
                   tz: "Asia/Tokyo"),
        workStart: 9, workEnd: 18
    )
    let groups = CityGroup.group(team: [], home: home, extraCities: [extra])
    check(groups.count == 2, "Home + empty Tokyo = 2 groups, even with no teammates")
    let tokyo = groups.first { $0.city == "Tokyo" }
    check(tokyo?.members.isEmpty == true, "Empty city has no members")
    check(tokyo?.workStart == 9 && tokyo?.workEnd == 18, "Empty city carries its own work hours")
}

// Brand assets — guard against accidental deletion of the icns/SVGs that
// `make bundle` copies into the .app. The check is path-based because
// BrandIcon is in the Timap (AppKit) target, not importable from here.
do {
    let cwd = FileManager.default.currentDirectoryPath
    for rel in ["Resources/Timap.icns", "Resources/Timap-AppIcon.svg"] {
        let path = "\(cwd)/\(rel)"
        check(FileManager.default.fileExists(atPath: path), "brand asset present: \(rel)")
    }
}

print("──────────────────────────────")
if failures == 0 {
    print("All checks passed ✓")
    exit(0)
} else {
    print("\(failures) check(s) failed")
    exit(1)
}
