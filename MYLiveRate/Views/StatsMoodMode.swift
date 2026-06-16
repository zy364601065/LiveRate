import Foundation

let statsMoodModeStorageKey = "myliverate.stats.mood_mode"
let luluMoodBehaviorStorageKey = "myliverate.stats.lulu_behavior"
let luluHappyAssetStorageKey = "myliverate.stats.lulu_happy_asset"
let luluBadAssetStorageKey = "myliverate.stats.lulu_bad_asset"
let luluDefaultGIFName = "lulu_default.GIF"

enum StatsMoodMode: String, CaseIterable, Identifiable {
    case standard
    case lulu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return "默认"
        case .lulu:
            return "噜噜"
        }
    }

    var detailText: String {
        switch self {
        case .standard:
            return "延续当前原生绘制表情。"
        case .lulu:
            return "日历底图改用 GIF 表情池。"
        }
    }
}

enum LuluMoodBehavior: String, CaseIterable, Identifiable {
    case random
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .random:
            return "随机"
        case .manual:
            return "手动"
        }
    }

    var detailText: String {
        switch self {
        case .random:
            return "每次切换到不同日期时，按情绪随机抽一张。"
        case .manual:
            return "盈利和亏损各固定使用你选中的一张。"
        }
    }
}

enum LuluHappyAsset: String, CaseIterable, Identifiable {
    case happy1 = "lulu_happy1.GIF"
    case happy2 = "lulu_happy2.GIF"
    case happy3 = "lulu_happy3.GIF"
    case happy4 = "lulu_happy4.GIF"
    case happy5 = "lulu_happy5.GIF"

    var id: String { rawValue }
    var fileName: String { rawValue }

    var displayName: String {
        switch self {
        case .happy1: return "开心 1"
        case .happy2: return "开心 2"
        case .happy3: return "开心 3"
        case .happy4: return "开心 4"
        case .happy5: return "开心 5"
        }
    }
}

enum LuluBadAsset: String, CaseIterable, Identifiable {
    case bad1 = "lulu_bad1.GIF"
    case bad2 = "lulu_bad2.GIF"
    case bad3 = "lulu_bad3.GIF"
    case bad4 = "lulu_bad4.GIF"
    case bad5 = "lulu_bad5.GIF"

    var id: String { rawValue }
    var fileName: String { rawValue }

    var displayName: String {
        switch self {
        case .bad1: return "沮丧 1"
        case .bad2: return "沮丧 2"
        case .bad3: return "沮丧 3"
        case .bad4: return "沮丧 4"
        case .bad5: return "沮丧 5"
        }
    }
}
