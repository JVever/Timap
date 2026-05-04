import Foundation

public enum TimeMath {
    public static func hourInTz(hostHour: Double, hostOffset: Double, targetOffset: Double) -> Double {
        var h = hostHour - hostOffset + targetOffset
        while h < 0 { h += 24 }
        while h >= 24 { h -= 24 }
        return h
    }

    public static func dayDelta(hostHour: Double, hostOffset: Double, targetOffset: Double) -> Int {
        let raw = hostHour - hostOffset + targetOffset
        if raw < 0 { return -1 }
        if raw >= 24 { return 1 }
        return 0
    }

    public static func isInWorkHours(localHour: Double, workStart: Double, workEnd: Double) -> Bool {
        localHour >= workStart && localHour < workEnd
    }

    /// Score the slot at `hostHour` (0–24) as the strict intersection of
    /// every teammate's [workStart, workEnd) interval, evaluated in each
    /// teammate's own local time. Returns 1 if everyone is in their work
    /// hours at this slot, 0 otherwise. `instant` is the absolute Date the
    /// slider is pointing to in that slot — teammate offsets are evaluated
    /// at that instant rather than at "now", so DST transitions inside
    /// today's slider range are applied correctly.
    public static func meetingScore(
        hostHour: Double,
        hostOffset: Double,
        team: [Teammate],
        at instant: Date = Date()
    ) -> Double {
        for p in team {
            let h = hourInTz(
                hostHour: hostHour,
                hostOffset: hostOffset,
                targetOffset: p.currentOffsetHours(for: instant)
            )
            if h < p.workStart || h >= p.workEnd { return 0 }
        }
        return 1
    }

    /// Resolve a slider position (`hourOfDay` ∈ [0, 24]) on a specific
    /// calendar date in a specific tz to an absolute `Date`. Centralized so
    /// scoring + rendering both agree on what instant a slider position
    /// refers to.
    public static func hostInstant(date: Date, hourOfDay: Double, in tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let dayShift = Int(floor(hourOfDay / 24))
        let localHour = hourOfDay - Double(dayShift * 24)
        let base = cal.dateComponents([.year, .month, .day], from: date)
        var dc = DateComponents()
        dc.year = base.year
        dc.month = base.month
        dc.day = (base.day ?? 0) + dayShift
        dc.hour = Int(localHour.rounded(.down))
        dc.minute = Int(((localHour - Double(dc.hour ?? 0)) * 60).rounded())
        return cal.date(from: dc) ?? date
    }

    public struct Window {
        public var start: Double
        public var end: Double
        public var minScore: Double

        public init(start: Double, end: Double, minScore: Double) {
            self.start = start
            self.end = end
            self.minScore = minScore
        }
    }

    /// DST-correct version: re-evaluates host + teammate offsets per
    /// candidate hour. Pass the host's actual calendar date and tz; the
    /// 96-step iteration handles a transition inside the slider's range.
    public static func findBestWindows(
        hostDate: Date,
        hostTimeZone: TimeZone,
        team: [Teammate]
    ) -> [Window] {
        let step = 0.25
        var windows: [Window] = []
        var current: Window? = nil
        var h = 0.0
        while h < 24 - 1e-9 {
            let instant = hostInstant(date: hostDate, hourOfDay: h, in: hostTimeZone)
            let hostOffset = Double(hostTimeZone.secondsFromGMT(for: instant)) / 3600.0
            let s = meetingScore(
                hostHour: h, hostOffset: hostOffset,
                team: team, at: instant
            )
            if s >= 0.5 {
                if let cur = current, abs(cur.minScore - s) < 0.01 {
                    current!.end = h + step
                } else {
                    if let cur = current { windows.append(cur) }
                    current = Window(start: h, end: h + step, minScore: s)
                }
            } else if let cur = current {
                windows.append(cur)
                current = nil
            }
            h += step
        }
        if let cur = current { windows.append(cur) }
        return windows.sorted { $0.minScore > $1.minScore }
    }

    /// Convenience overload for code paths that don't have a calendar
    /// context yet (e.g. tests). Uses `Date()` as the host instant which
    /// means DST transitions inside the slider range are NOT applied.
    public static func findBestWindows(hostOffset: Double, team: [Teammate]) -> [Window] {
        let now = Date()
        let tz = TimeZone(secondsFromGMT: Int(hostOffset * 3600)) ?? .current
        return findBestWindows(hostDate: now, hostTimeZone: tz, team: team)
    }
}
