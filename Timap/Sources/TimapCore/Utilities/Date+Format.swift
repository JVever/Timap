import Foundation

private let weekdaysEn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
private let weekdaysZh = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
private let monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

public enum TimapFormat {
    /// "10:30 AM" / "上午 10:30" (ampm) — "10:30" / "10:30" (24h, language-agnostic).
    public static func hour(_ h: Double, ampm: Bool = true, lang: AppLanguage = .en) -> String {
        let hour = Int(h.rounded(.down))
        let min = Int(((h - Double(hour)) * 60).rounded())
        if ampm {
            var h12 = hour % 12
            if h12 == 0 { h12 = 12 }
            switch lang {
            case .zh:
                let period = (hour < 12 || hour == 24) ? "上午" : "下午"
                return String(format: "%@ %d:%02d", period, h12, min)
            case .en:
                let period = (hour < 12 || hour == 24) ? "AM" : "PM"
                return String(format: "%d:%02d %@", h12, min, period)
            }
        }
        return String(format: "%02d:%02d", hour, min)
    }

    /// Short axis label for the slider. zh: "0/6/12/18/24" (24h); en: "12a/6a/12p/6p/12a".
    public static func hourShort(_ h: Double, lang: AppLanguage = .en) -> String {
        let hour = Int(h.rounded(.down))
        switch lang {
        case .zh:
            return "\(hour)"
        case .en:
            let period = (hour % 24) < 12 ? "a" : "p"
            var h12 = (hour % 24) % 12
            if h12 == 0 { h12 = 12 }
            return "\(h12)\(period)"
        }
    }

    /// "Mon · May 4" (en) / "周一 · 5月4日" (zh).
    public static func longDate(_ d: Date, in tz: TimeZone? = nil, lang: AppLanguage = .en) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz ?? cal.timeZone
        let weekday = cal.component(.weekday, from: d) - 1
        let month = cal.component(.month, from: d)
        let day = cal.component(.day, from: d)
        switch lang {
        case .zh:
            return "\(weekdaysZh[weekday]) · \(month)月\(day)日"
        case .en:
            return "\(weekdaysEn[weekday]) · \(monthsEn[month - 1]) \(day)"
        }
    }

    /// "MON 4" (en) / "周一 4" (zh) — used in row's date column.
    public static func shortDate(_ d: Date, in tz: TimeZone? = nil, lang: AppLanguage = .en) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz ?? cal.timeZone
        let weekday = cal.component(.weekday, from: d) - 1
        let day = cal.component(.day, from: d)
        switch lang {
        case .zh:
            return "\(weekdaysZh[weekday]) \(day)"
        case .en:
            return "\(weekdaysEn[weekday].uppercased()) \(day)"
        }
    }
}

public extension Date {
    func adding(days: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: self) ?? self
    }
}
