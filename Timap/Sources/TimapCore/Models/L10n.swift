import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Hashable {
    case zh
    case en

    public var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

/// Tiny in-memory i18n. Adding a key:
///   1. add a case to `L10n.Key`
///   2. add the entry to BOTH `zh` and `en` dictionaries
/// View call sites use `state.tr(.someKey)`.
public enum L10n {
    public enum Key: String, Hashable {
        // Header / status
        case allInCore, workable, someoneAsleep, now
        // Slider / footer
        case bestSlots
        // Team rows
        case hiddenSep, clickToHide, clickToInclude
        // City cards (v11)
        case home
        // Onboarding (v2 — 2-step welcome + city pick redesign)
        case welcome, whereBased, locationHint, getStarted, locationSearchPlaceholder
        case welcomeSub, welcomeBullet1, welcomeBullet2, welcomeBullet3
        case onbNext, onbHotLabel, onbResultsLabel, onbSelectToContinue, onbBack
        // Settings
        case settings, done, quitApp
        case sectionLocation, sectionWorkHours, sectionTeammates, sectionLanguage
        case change, cancel, add, edit, save, confirm
        case toBetweenHours
        // v4 settings — city-card layout
        case addCity, setAsHome, deleteCity, cantDeleteHome, workHoursLabel
        case unnamed
        // Tooltips on main view
        case jumpToBestSlotTooltip, atNowTooltip, goLiveTooltip
        case clickToHideCityTooltip, clickToIncludeCityTooltip
        // City-add validation
        case duplicateCityWarning
        case editTooltip, deleteTooltip, uploadAvatarTooltip
        case addTeammateChip, teammateNamePlaceholder, useInitials
        case searchCityPlaceholderV4, searchHint, manualAddSelf
        case noMatchTryEnglish
        case manualCityTitle, manualCityHint, backToSearch
        case fieldCnName, fieldEnName, fieldUtcOffset, fieldLat, fieldLng
        case manualCnExample, manualEnExample, manualUtcExample, manualLatExample, manualLngExample
        case coordsHint
        // Field labels still used by inline edit chip and onboarding
        case fieldName
        // City picker
        case searchCity, noMatchingCity
    }

    /// Composite phrasing helpers — used where strings are interpolated
    /// with runtime values and the word order differs across languages.
    public static func deleteCityPrompt(_ city: String, memberCount: Int, _ lang: AppLanguage) -> String {
        switch lang {
        case .zh:
            if memberCount > 0 {
                return "删除 \(city) 及 \(memberCount) 位同事？"
            }
            return "删除 \(city)？"
        case .en:
            if memberCount > 0 {
                let unit = memberCount > 1 ? "teammates" : "teammate"
                return "Delete \(city) and \(memberCount) \(unit)?"
            }
            return "Delete \(city)?"
        }
    }

    public static func deletePersonPrompt(_ name: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zh: return "删除 \(name)？"
        case .en: return "Delete \(name)?"
        }
    }

    public static func manualAddWithQuery(_ q: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zh: return "手动添加 \"\(q)\" →"
        case .en: return "Add \"\(q)\" manually →"
        }
    }

    public static func noMatchFor(_ q: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zh: return "没有匹配 \"\(q)\""
        case .en: return "No match for \"\(q)\""
        }
    }

    public static func t(_ key: Key, _ lang: AppLanguage) -> String {
        let dict = lang == .zh ? zh : en
        return dict[key] ?? en[key] ?? key.rawValue
    }

    /// Today / Yesterday / Tomorrow / +Nd / -Nd, localized.
    public static func relDay(_ delta: Int, _ lang: AppLanguage) -> String {
        switch lang {
        case .zh:
            switch delta {
            case 0:  return "今天"
            case 1:  return "明天"
            case -1: return "昨天"
            default: return delta > 0 ? "+\(delta)天" : "\(delta)天"
            }
        case .en:
            switch delta {
            case 0:  return "Today"
            case 1:  return "Tomorrow"
            case -1: return "Yesterday"
            default: return delta > 0 ? "+\(delta)d" : "\(delta)d"
            }
        }
    }

    private static let zh: [Key: String] = [
        .allInCore:                  "全员都在工作时间",
        .workable:                   "勉强可行",
        .someoneAsleep:              "有人在睡觉",
        .now:                        "现在",
        .bestSlots:                  "最佳时段",
        .hiddenSep:                  "已隐藏 · 点头像恢复",
        .clickToHide:                "点此隐藏",
        .clickToInclude:             "点此恢复",
        .welcome:                    "欢迎使用 Timap",
        .whereBased:                 "你所在的城市？",
        .locationHint:               "这将作为你的本地时区。可以稍后在设置中更改。",
        .getStarted:                 "开始使用",
        .locationSearchPlaceholder:  "输入城市 — 例如：北京、伦敦、东京",
        .welcomeSub:                 "为跨时区的团队，找到一起在线的最佳时刻。",
        .welcomeBullet1:             "看清每个城市当下是清晨、午后，还是深夜",
        .welcomeBullet2:             "一眼找到所有人都在工作时间的会议时段",
        .welcomeBullet3:             "常驻菜单栏，随时拉出，随时收起",
        .onbNext:                    "下一步",
        .onbHotLabel:                "常用城市",
        .onbResultsLabel:            "搜索结果",
        .onbSelectToContinue:        "选择一个城市",
        .onbBack:                    "返回",
        .settings:                   "设置",
        .done:                       "完成",
        .quitApp:                    "退出 Timap",
        .sectionLocation:            "你的位置",
        .sectionWorkHours:           "工作时间",
        .sectionTeammates:           "同事",
        .sectionLanguage:            "语言",
        .change:                     "更改",
        .cancel:                     "取消",
        .add:                        "添加",
        .edit:                       "编辑",
        .save:                       "保存",
        .confirm:                    "确定",
        .toBetweenHours:             "至",
        .addCity:                    "添加新城市",
        .setAsHome:                  "设为本地",
        .deleteCity:                 "删除城市",
        .cantDeleteHome:             "本地城市不可删除——先把另一座城市设为本地",
        .workHoursLabel:             "工作时段",
        .unnamed:                    "未命名",
        .jumpToBestSlotTooltip:      "点击跳到下一个推荐会议时段",
        .atNowTooltip:               "当前显示的就是现在",
        .goLiveTooltip:              "回到现在",
        .clickToHideCityTooltip:     "点击隐藏此城市",
        .clickToIncludeCityTooltip:  "点击恢复参与会议评分",
        .duplicateCityWarning:       "已存在同名城市，请换一个名字",
        .editTooltip:                "编辑",
        .deleteTooltip:              "删除",
        .uploadAvatarTooltip:        "上传头像",
        .addTeammateChip:            "同事",
        .teammateNamePlaceholder:    "同事姓名",
        .useInitials:                "头像用首字母",
        .searchCityPlaceholderV4:    "搜索城市，例如：东京 / Tokyo / 美国",
        .searchHint:                 "从已知城市中搜索 ——",
        .manualAddSelf:              "手动添加自定义城市 →",
        .noMatchTryEnglish:          "试试英文（如 Tokyo），或手动填写完整信息。",
        .manualCityTitle:            "手动添加城市",
        .manualCityHint:             "为了在地图上摆放，需要经纬度",
        .backToSearch:               "← 返回搜索",
        .fieldCnName:                "中文名",
        .fieldEnName:                "英文名",
        .fieldUtcOffset:             "UTC 偏移",
        .fieldLat:                   "纬度",
        .fieldLng:                   "经度",
        .manualCnExample:            "如：东京",
        .manualEnExample:            "如：Tokyo",
        .manualUtcExample:           "整数偏移，如：8 / -5（半小时偏移请从内置城市搜索）",
        .manualLatExample:           "-90 ~ 90，如：35.7",
        .manualLngExample:           "-180 ~ 180，如：139.7",
        .coordsHint:                 "提示：在 Google Maps / 高德地图上右键任意位置即可复制经纬度。",
        .fieldName:                  "姓名",
        .searchCity:                 "搜索城市……",
        .noMatchingCity:             "未找到匹配城市，请换个拼写。",
        .home:                       "本地",
    ]

    private static let en: [Key: String] = [
        .allInCore:                  "All in core hours",
        .workable:                   "Workable",
        .someoneAsleep:              "Someone is asleep",
        .now:                        "Now",
        .bestSlots:                  "BEST SLOTS",
        .hiddenSep:                  "HIDDEN · CLICK AVATAR TO INCLUDE",
        .clickToHide:                "Click to hide",
        .clickToInclude:             "Click to include",
        .welcome:                    "Welcome to Timap",
        .whereBased:                 "Where are you based?",
        .locationHint:               "This becomes your home time zone. You can change it later in Settings.",
        .getStarted:                 "Get started",
        .locationSearchPlaceholder:  "Type a city — e.g., Beijing, London, Tokyo",
        .welcomeSub:                 "Find the time that works for your team — across cities, across time zones.",
        .welcomeBullet1:             "See morning, afternoon and night across every city at a glance",
        .welcomeBullet2:             "Spot the windows where everyone's in working hours",
        .welcomeBullet3:             "Lives in the menu bar — pull it open, dismiss it, repeat",
        .onbNext:                    "Next",
        .onbHotLabel:                "Popular",
        .onbResultsLabel:            "Results",
        .onbSelectToContinue:        "Select a city to continue",
        .onbBack:                    "Back",
        .settings:                   "Settings",
        .done:                       "Done",
        .quitApp:                    "Quit Timap",
        .sectionLocation:            "YOUR LOCATION",
        .sectionWorkHours:           "WORKING HOURS",
        .sectionTeammates:           "TEAMMATES",
        .sectionLanguage:            "LANGUAGE",
        .change:                     "Change",
        .cancel:                     "Cancel",
        .add:                        "Add",
        .edit:                       "Edit",
        .save:                       "Save",
        .confirm:                    "Confirm",
        .toBetweenHours:             "to",
        .addCity:                    "Add city",
        .setAsHome:                  "Set as home",
        .deleteCity:                 "Delete city",
        .cantDeleteHome:             "Home city can't be deleted — set another city as home first",
        .workHoursLabel:             "WORKING HOURS",
        .unnamed:                    "Unnamed",
        .jumpToBestSlotTooltip:      "Click to jump to the next recommended slot",
        .atNowTooltip:               "Already showing current time",
        .goLiveTooltip:              "Back to live time",
        .clickToHideCityTooltip:     "Click to hide this city",
        .clickToIncludeCityTooltip:  "Click to include in scoring again",
        .duplicateCityWarning:       "A city with this name already exists",
        .editTooltip:                "Edit",
        .deleteTooltip:              "Delete",
        .uploadAvatarTooltip:        "Upload avatar",
        .addTeammateChip:            "Teammate",
        .teammateNamePlaceholder:    "Teammate name",
        .useInitials:                "Use initials",
        .searchCityPlaceholderV4:    "Search city — e.g., Tokyo / 东京 / Japan",
        .searchHint:                 "Search known cities ——",
        .manualAddSelf:              "Add custom city manually →",
        .noMatchTryEnglish:          "Try the English name (e.g., Tokyo), or fill in details manually.",
        .manualCityTitle:            "Add city manually",
        .manualCityHint:             "Coordinates needed to place on map",
        .backToSearch:               "← Back to search",
        .fieldCnName:                "Chinese name",
        .fieldEnName:                "English name",
        .fieldUtcOffset:             "UTC offset",
        .fieldLat:                   "Latitude",
        .fieldLng:                   "Longitude",
        .manualCnExample:            "e.g., 东京",
        .manualEnExample:            "e.g., Tokyo",
        .manualUtcExample:           "Integer hours, e.g., 8 / -5 (half-hour zones: pick from catalog)",
        .manualLatExample:           "-90 to 90, e.g., 35.7",
        .manualLngExample:           "-180 to 180, e.g., 139.7",
        .coordsHint:                 "Tip: right-click on Google Maps / Amap to copy coordinates.",
        .fieldName:                  "Name",
        .searchCity:                 "Search city…",
        .noMatchingCity:             "No matching city. Try another spelling.",
        .home:                       "HOME",
    ]
}
