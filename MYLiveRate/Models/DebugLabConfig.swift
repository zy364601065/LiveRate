import Foundation

let trendHintLabScenarioStorageKey = "myliverate.debug.trend_hint_scenario"

enum TrendHintLabScenario: String, CaseIterable, Identifiable {
    case none
    case profitStreak4
    case lossStreak4
    case shortStreak3
    case latestZero

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "真实数据"
        case .profitStreak4:
            return "连续盈利 4 天"
        case .lossStreak4:
            return "连续亏损 4 天"
        case .shortStreak3:
            return "连续天数不足 4 天"
        case .latestZero:
            return "最新一天为 0"
        }
    }
}
