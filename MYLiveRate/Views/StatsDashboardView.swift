import SwiftUI
import Charts
import UIKit

struct StatsDashboardView: View {
    private enum ConsecutiveTrendType {
        case profit
        case loss
    }

    private struct ConsecutiveTrendStatus {
        let type: ConsecutiveTrendType
        let streakCount: Int
    }

    private struct ConsecutiveTrendHint {
        let symbolName: String
        let message: String
        let detail: String
        let accentColor: Color
        let backgroundColor: Color
    }

    private struct DailyTrendSlot: Identifiable {
        let day: Date
        let amount: Double?
        let plotDate: Date

        var id: Date { day }
    }

    private struct MonthlyTrendSlot: Identifiable {
        let month: Date
        let amount: Double?
        let plotDate: Date

        var id: Date { month }
    }

    private struct WeeklyTrendSlot: Identifiable {
        let weekStart: Date
        let amount: Double?
        let plotDate: Date

        var id: Date { weekStart }
    }

    private enum SummaryPeriod: String, CaseIterable, Identifiable {
        case currentWeek = "本周"
        case currentMonth = "本月"
        case allTime = "总计"
        var id: String { rawValue }
    }

    private enum KeyStatMood: Equatable {
        case profit
        case loss
    }

    private enum LuluCalendarMood: Equatable {
        case profit
        case loss
        case defaultAsset
    }

    private enum CalendarMoodPresentation: Equatable {
        case standard(KeyStatMood)
        case lulu(LuluCalendarMood)
        case custom(LuluCalendarMood)
    }

    private struct KeyStatItem {
        let title: String
        let day: String
        let amount: String
        let tone: Color

        init(title: String, day: String, amount: String, tone: Color) {
            self.title = title
            self.day = day
            self.amount = amount
            self.tone = tone
        }
    }

    private enum TrendChartStyle: String, CaseIterable, Identifiable {
        case bar = "柱状"
        case line = "折线"
        case area = "面积"
        case scatter = "散点"
        var id: String { rawValue }
    }

    @ObservedObject var viewModel: ExchangeRateViewModel
    @ObservedObject var statsMoodViewModel: StatsMoodViewModel
    @State private var selectedDay = Date()
    @State private var trendPeriod: TrendPeriod = .daily
    @State private var trendChartStyle: TrendChartStyle = .bar
    @State private var summaryPeriod: SummaryPeriod = .currentMonth
    @State private var displayedMonth = Date()
    @State private var dailyChartScrollPosition: Date = Date()
    @State private var selectedDailySlotDate: Date = Date()
    @State private var monthlyChartScrollPosition: Date = Date()
    @State private var selectedMonthlySlotDate: Date = Date()
    @State private var weeklyChartScrollPosition: Date = Date()
    @State private var selectedWeeklySlotDate: Date = Date()
    @State private var calendarGridWidth: CGFloat = 0
    @State private var hasInitializedSelection = false
    @State private var isCurrencyPickerPresented = false
    @State private var displayedConsecutiveTrendHint: ConsecutiveTrendHint?
    @State private var randomizedLuluAssetFileName: String?
    @State private var randomizedCustomAssetID: UUID?
    @AppStorage(trendHintToneStorageKey) private var trendHintToneRawValue: String = TrendHintTone.wild.rawValue
    @AppStorage(statsMoodModeStorageKey) private var statsMoodModeRawValue: String = StatsMoodMode.standard.rawValue
    @AppStorage(luluMoodBehaviorStorageKey) private var luluMoodBehaviorRawValue: String = LuluMoodBehavior.random.rawValue
    @AppStorage(luluHappyAssetStorageKey) private var luluHappyAssetRawValue: String = LuluHappyAsset.happy1.rawValue
    @AppStorage(luluBadAssetStorageKey) private var luluBadAssetRawValue: String = LuluBadAsset.bad1.rawValue
    @AppStorage(customStatsMoodModeIDStorageKey) private var customStatsMoodModeID: String = ""
    @AppStorage("myliverate.stats.hide_numbers") private var hideStatsNumbers = false
#if DEBUG
    @AppStorage(trendHintLabScenarioStorageKey) private var trendHintLabScenarioRawValue: String = TrendHintLabScenario.none.rawValue
#endif
    private let trendPeriodOptions: [TrendPeriod] = [.daily, .monthly]
    private let positiveColor = Color(red: 0.93, green: 0.19, blue: 0.23)
    private let negativeColor = Color(red: 0.12, green: 0.72, blue: 0.67)
    private let accentBlue = Color(red: 0.95, green: 0.52, blue: 0.16)
    private let titleColor = Color(uiColor: .label)
    private let subtitleColor = Color(uiColor: .secondaryLabel)
    private let pageBackgroundTop = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
            : UIColor(red: 0.995, green: 0.995, blue: 0.992, alpha: 1)
    })
    private let pageBackgroundBottom = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
            : UIColor(red: 0.989, green: 0.989, blue: 0.982, alpha: 1)
    })
    private let glassFillColor = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.50)
            : UIColor(white: 1, alpha: 0.20)
    })
    private let glassStrokeColor = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(white: 1, alpha: 0.62)
    })
    private let calendarCellSpacing: CGFloat = 4
    private let dailyVisibleDays = 7
    private let weeklyVisibleWeeks = 8
    private let monthlyVisibleMonths = 6
    private let hiddenValueMask = "****"
    private static let profitHintQueueStorageKey = "myliverate.stats.profit_hint_queue.v1"
    private static let lossHintQueueStorageKey = "myliverate.stats.loss_hint_queue.v1"

    private var selectedTrendHintTone: TrendHintTone {
        TrendHintTone(rawValue: trendHintToneRawValue) ?? .wild
    }

    private var selectedStatsMoodMode: StatsMoodMode {
        StatsMoodMode(rawValue: statsMoodModeRawValue) ?? .standard
    }

    private var selectedLuluMoodBehavior: LuluMoodBehavior {
        LuluMoodBehavior(rawValue: luluMoodBehaviorRawValue) ?? .random
    }

    private var selectedLuluHappyAsset: LuluHappyAsset {
        LuluHappyAsset(rawValue: luluHappyAssetRawValue) ?? .happy1
    }

    private var selectedLuluBadAsset: LuluBadAsset {
        LuluBadAsset(rawValue: luluBadAssetRawValue) ?? .bad1
    }

    private var selectedCustomMoodMode: CustomStatsMoodMode? {
        statsMoodViewModel.mode(id: customStatsMoodModeID)
    }

    private func maskedNumericText(_ text: String) -> String {
        guard hideStatsNumbers else { return text }
        guard text != "--" else { return text }
        let hasNumericContent = text.range(of: #"[0-9+\-/%]"#, options: .regularExpression) != nil
        return hasNumericContent ? hiddenValueMask : text
    }

    // 稳
    private static let steadyProfitMessages = [
        "策略执行稳定，继续保持。",
        "盈利节奏良好，可按计划推进。",
        
        "趋势健康，注意分批与仓位管理。",
        "当前表现优于近阶段平均水平。",
        "连续正收益，建议继续纪律执行。",
        "节奏不错，重点关注回撤控制。"
    ]
    private static let steadyLossMessages = [
        "出现连续回撤，先控制风险敞口。",
        "建议复盘近期决策并降低冲动交易。",
        "优先防守，等待更高胜率机会。",
        "保持节奏，避免在波动期过度加仓。",
        "先稳住回撤，再逐步恢复进攻。",
        "当前以风险管理为第一优先级。"
    ]
    
    // 狂野
    private static let wildProfitMessages = [
        "杀疯了！策略直接起飞，继续猛干！",
        "盈利如潮水般涌来，给我往死里冲！",
        "势头凶猛，仓位拉满，干他妈的！",
        "今天状态爆棚，远超平均水平，给我继续屠！",
        "连着吃肉，纪律执行到位，冲啊兄弟！",
        "节奏狂野，注意回撤但别怂，继续进攻！"
    ]

    private static let wildLossMessages = [
        "操，连续挨打！先把仓位给我砍下来！",
        "别他妈冲动了，马上复盘，冷静再战！",
        "现在进入防守模式，缩手等机会，憋住！",
        "回撤凶狠，禁止加仓，先保命再说！",
        "稳住别崩，止损止损，养精蓄锐再杀回来！",
        "风险第一！把贪婪给我吞下去，活下来才能继续狂飙！"
    ]
    
    // 更凶
    private static let savageProfitMessages = [
        "他妈的杀爆了！策略直接起飞，继续给我猛干！",
        "盈利像疯狗一样狂咬，仓位拉满往死里冲！",
        "势头凶残，屠杀模式已开启，干翻它！",
        "今天状态炸裂，远超平均，给我继续血洗市场！",
        "连着吃大肉，纪律执行得漂亮，冲啊王八蛋！",
        "节奏狂到炸裂，注意回撤但别怂，继续进攻！"
    ]

    private static let savageLossMessages = [
        "操他妈的！连续挨揍，先把仓位给我砍到骨头！",
        "别他妈脑子发热，马上复盘，冷静点再战！",
        "现在给我缩卵防守，憋住！等高胜率机会再杀！",
        "回撤这么狠？禁止加仓！先保命，别死在里面！",
        "稳住别崩盘，止损止损！养好精气神再回来复仇！",
        "风险他妈的是第一位！把贪婪吞下去，活下来才能继续狂飙！"
    ]

    private var marketCalendar: Calendar {
        var calendar = viewModel.marketCalendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.firstWeekday = 1
        return calendar
    }

    private var localDisplayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        return calendar
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }

    private var rows: [DailyAmountRow] {
        viewModel.dailyAmountRows(for: viewModel.statsDisplayCurrency)
    }

    private func signedAmountColor(_ value: Double, zeroColor: Color = .secondary) -> Color {
        if hideStatsNumbers {
            return Color(uiColor: .tertiaryLabel)
        }
        if value > 0 { return positiveColor }
        if value < 0 { return negativeColor }
        return zeroColor
    }

    private func signedRuleColor(_ value: Double?) -> Color {
        guard let value else { return .gray }
        return signedAmountColor(value, zeroColor: .gray)
    }

    private var trendRows: [TrendDataPoint] {
        viewModel.trendRows(for: viewModel.statsDisplayCurrency, period: trendPeriod)
    }

    private var dailyTrendSlots: [DailyTrendSlot] {
        let calendar = marketCalendar
        let today = calendar.startOfDay(for: Date())
        guard let startDay = calendar.date(byAdding: .day, value: -29, to: today) else {
            return []
        }
        let endDay = today
        let amountByDay = Dictionary(uniqueKeysWithValues: rows.map {
            (calendar.startOfDay(for: $0.day), $0.convertedAmount)
        })

        var slots: [DailyTrendSlot] = []
        var cursor = startDay
        while cursor <= endDay {
            slots.append(
                DailyTrendSlot(
                    day: cursor,
                    amount: amountByDay[cursor],
                    plotDate: middayInMarketCalendar(for: cursor)
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return slots
    }

    private var dailyTrendYDomain: ClosedRange<Double> {
        let absMax = dailyTrendSlots
            .compactMap(\.amount)
            .map { abs($0) }
            .max() ?? 0
        let padded = max(absMax * 1.2, 1)
        return (-padded)...padded
    }

    private var selectedDailySlot: DailyTrendSlot? {
        dailyTrendSlots.first {
            marketCalendar.isDate($0.day, inSameDayAs: selectedDailySlotDate)
        } ?? dailyTrendSlots.last
    }

    private var latestDailyDataSlot: DailyTrendSlot? {
        dailyTrendSlots.last { $0.amount != nil } ?? dailyTrendSlots.last
    }

    private var selectedDailySlotAmount: Double {
        selectedDailySlot?.amount ?? 0
    }

    private var selectedDailySlotAmountText: String {
        hideStatsNumbers ? hiddenValueMask : String(format: "%+.2f", selectedDailySlotAmount)
    }

    private var selectedDailySlotAmountColor: Color {
        signedAmountColor(selectedDailySlotAmount)
    }

    private var selectedDailyRuleColor: Color {
        signedRuleColor(selectedDailySlot?.amount)
    }

    private var selectedDailyDateText: String {
        guard let day = selectedDailySlot?.day else { return "--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: day)
    }

    private var dailyBoundaryDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var dailyAxisBoundaryValues: [Date] {
        guard let first = dailyTrendSlots.first?.plotDate,
              let last = dailyTrendSlots.last?.plotDate else {
            return []
        }
        return first == last ? [first] : [first, last]
    }

    private var dailyChartXDomain: ClosedRange<Date> {
        guard let first = dailyTrendSlots.first?.plotDate,
              let last = dailyTrendSlots.last?.plotDate else {
            let now = Date()
            return now...now
        }
        let padding = halfVisibleTimeInterval
        let start = first.addingTimeInterval(-padding)
        let end = last.addingTimeInterval(padding)
        return start...end
    }

    private var halfVisibleTimeInterval: TimeInterval {
        (Double(dailyVisibleDays) / 2.0) * 24 * 3600
    }

    private var centeredPlotDateFromScroll: Date {
        dailyChartScrollPosition.addingTimeInterval(halfVisibleTimeInterval)
    }

    private func leadingDateForCenteredFocus(_ focusDate: Date) -> Date {
        focusDate.addingTimeInterval(-halfVisibleTimeInterval)
    }

    private func syncDailySelectionFromScrollPosition(_ leadingDate: Date) {
        let centerDate = leadingDate.addingTimeInterval(halfVisibleTimeInterval)
        guard let nearest = dailyTrendSlots.min(by: {
            abs($0.plotDate.timeIntervalSince(centerDate)) < abs($1.plotDate.timeIntervalSince(centerDate))
        }) else {
            return
        }

        if selectedDay != nearest.day {
            selectedDay = nearest.day
            selectedDailySlotDate = nearest.day
        }
    }

    private func alignSelectedDailySlotToLatest() {
        guard let target = latestDailyDataSlot else { return }
        selectedDailySlotDate = target.day
        selectedDay = target.day
        displayedMonth = target.day
        dailyChartScrollPosition = leadingDateForCenteredFocus(target.plotDate)
    }

    private func middayInMarketCalendar(for day: Date) -> Date {
        let calendar = marketCalendar
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    private var monthlyTrendSlots: [MonthlyTrendSlot] {
        let calendar = marketCalendar
        guard let latestDataMonth = trendRows.last?.periodStart else {
            let todayMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
            return [MonthlyTrendSlot(month: todayMonth, amount: nil, plotDate: midMonthInMarketCalendar(for: todayMonth))]
        }
        
        guard let startMonth = calendar.date(byAdding: .month, value: -11, to: latestDataMonth) else {
            return []
        }
        let endMonth = latestDataMonth
        let amountByMonth = Dictionary(uniqueKeysWithValues: trendRows.map {
            ($0.periodStart, $0.amount)
        })

        var slots: [MonthlyTrendSlot] = []
        var cursor = startMonth
        while cursor <= endMonth {
            slots.append(
                MonthlyTrendSlot(
                    month: cursor,
                    amount: amountByMonth[cursor],
                    plotDate: midMonthInMarketCalendar(for: cursor)
                )
            )
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return slots
    }

    private var monthlyTrendYDomain: ClosedRange<Double> {
        let absMax = monthlyTrendSlots
            .compactMap(\.amount)
            .map { abs($0) }
            .max() ?? 0
        let padded = max(absMax * 1.2, 1)
        return (-padded)...padded
    }

    private var selectedMonthlySlot: MonthlyTrendSlot? {
        monthlyTrendSlots.first {
            marketCalendar.isDate($0.month, equalTo: selectedMonthlySlotDate, toGranularity: .month)
        } ?? monthlyTrendSlots.last
    }

    private var latestMonthlyDataSlot: MonthlyTrendSlot? {
        monthlyTrendSlots.last { $0.amount != nil } ?? monthlyTrendSlots.last
    }

    private var selectedMonthlySlotAmount: Double {
        selectedMonthlySlot?.amount ?? 0
    }

    private var selectedMonthlySlotAmountText: String {
        hideStatsNumbers ? hiddenValueMask : String(format: "%+.2f", selectedMonthlySlotAmount)
    }

    private var selectedMonthlySlotAmountColor: Color {
        signedAmountColor(selectedMonthlySlotAmount)
    }

    private var selectedMonthlyRuleColor: Color {
        signedRuleColor(selectedMonthlySlot?.amount)
    }

    private var selectedMonthlyDateText: String {
        guard let month = selectedMonthlySlot?.month else { return "--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: month)
    }

    private var monthlyBoundaryDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }

    private var monthlyChartXDomain: ClosedRange<Date> {
        guard let first = monthlyTrendSlots.first?.plotDate,
              let last = monthlyTrendSlots.last?.plotDate else {
            let now = Date()
            return now...now
        }
        let padding = halfVisibleMonthlyTimeInterval
        let start = first.addingTimeInterval(-padding)
        let end = last.addingTimeInterval(padding)
        return start...end
    }

    private var halfVisibleMonthlyTimeInterval: TimeInterval {
        (Double(monthlyVisibleMonths) / 2.0) * 30 * 24 * 3600
    }

    private var monthlyCenteredPlotDateFromScroll: Date {
        monthlyChartScrollPosition.addingTimeInterval(halfVisibleMonthlyTimeInterval)
    }

    private func leadingDateForMonthlyCenteredFocus(_ focusDate: Date) -> Date {
        focusDate.addingTimeInterval(-halfVisibleMonthlyTimeInterval)
    }

    private func syncMonthlySelectionFromScrollPosition(_ leadingDate: Date) {
        let centerDate = leadingDate.addingTimeInterval(halfVisibleMonthlyTimeInterval)
        guard let nearest = monthlyTrendSlots.min(by: {
            abs($0.plotDate.timeIntervalSince(centerDate)) < abs($1.plotDate.timeIntervalSince(centerDate))
        }) else {
            return
        }

        if !marketCalendar.isDate(selectedMonthlySlotDate, equalTo: nearest.month, toGranularity: .month) {
            selectedMonthlySlotDate = nearest.month
        }
    }

    private func alignSelectedMonthlySlotToLatest() {
        guard let target = latestMonthlyDataSlot else { return }
        selectedMonthlySlotDate = target.month
        monthlyChartScrollPosition = leadingDateForMonthlyCenteredFocus(target.plotDate)
    }

    private func midMonthInMarketCalendar(for monthStart: Date) -> Date {
        let calendar = marketCalendar
        guard let days = calendar.range(of: .day, in: .month, for: monthStart)?.count else {
            return monthStart
        }
        return calendar.date(byAdding: .day, value: days / 2, to: monthStart) ?? monthStart
    }

    private var weeklyTrendRows: [TrendDataPoint] {
        viewModel.trendRows(for: viewModel.statsDisplayCurrency, period: .weekly)
    }

    private var weeklyTrendSlots: [WeeklyTrendSlot] {
        let calendar = marketCalendar
        guard let latestDataWeekStart = weeklyTrendRows.last?.periodStart else {
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            return [WeeklyTrendSlot(weekStart: currentWeek, amount: nil, plotDate: midWeekInMarketCalendar(for: currentWeek))]
        }

        guard let startWeek = calendar.date(byAdding: .weekOfYear, value: -11, to: latestDataWeekStart) else {
            return []
        }
        let amountByWeek = Dictionary(uniqueKeysWithValues: weeklyTrendRows.map {
            ($0.periodStart, $0.amount)
        })

        var slots: [WeeklyTrendSlot] = []
        var cursor = startWeek
        while cursor <= latestDataWeekStart {
            slots.append(
                WeeklyTrendSlot(
                    weekStart: cursor,
                    amount: amountByWeek[cursor],
                    plotDate: midWeekInMarketCalendar(for: cursor)
                )
            )
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return slots
    }

    private var weeklyTrendYDomain: ClosedRange<Double> {
        let absMax = weeklyTrendSlots
            .compactMap(\.amount)
            .map { abs($0) }
            .max() ?? 0
        let padded = max(absMax * 1.2, 1)
        return (-padded)...padded
    }

    private var selectedWeeklySlot: WeeklyTrendSlot? {
        weeklyTrendSlots.first {
            marketCalendar.isDate($0.weekStart, equalTo: selectedWeeklySlotDate, toGranularity: .weekOfYear)
        } ?? weeklyTrendSlots.last
    }

    private var latestWeeklyDataSlot: WeeklyTrendSlot? {
        weeklyTrendSlots.last { $0.amount != nil } ?? weeklyTrendSlots.last
    }

    private var selectedWeeklySlotAmount: Double {
        selectedWeeklySlot?.amount ?? 0
    }

    private var selectedWeeklySlotAmountText: String {
        hideStatsNumbers ? hiddenValueMask : String(format: "%+.2f", selectedWeeklySlotAmount)
    }

    private var selectedWeeklySlotAmountColor: Color {
        signedAmountColor(selectedWeeklySlotAmount)
    }

    private var selectedWeeklyRuleColor: Color {
        signedRuleColor(selectedWeeklySlot?.amount)
    }

    private var selectedWeeklyDateText: String {
        guard let weekStart = selectedWeeklySlot?.weekStart else { return "--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "yyyy年"
        let yearText = formatter.string(from: weekStart)
        let weekNumber = marketCalendar.component(.weekOfYear, from: weekStart)
        return "\(yearText)第\(weekNumber)周"
    }

    private var weeklyBoundaryDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var weeklyChartXDomain: ClosedRange<Date> {
        guard let first = weeklyTrendSlots.first?.plotDate,
              let last = weeklyTrendSlots.last?.plotDate else {
            let now = Date()
            return now...now
        }
        let padding = halfVisibleWeeklyTimeInterval
        let start = first.addingTimeInterval(-padding)
        let end = last.addingTimeInterval(padding)
        return start...end
    }

    private var halfVisibleWeeklyTimeInterval: TimeInterval {
        (Double(weeklyVisibleWeeks) / 2.0) * 7 * 24 * 3600
    }

    private var weeklyCenteredPlotDateFromScroll: Date {
        weeklyChartScrollPosition.addingTimeInterval(halfVisibleWeeklyTimeInterval)
    }

    private func leadingDateForWeeklyCenteredFocus(_ focusDate: Date) -> Date {
        focusDate.addingTimeInterval(-halfVisibleWeeklyTimeInterval)
    }

    private func syncWeeklySelectionFromScrollPosition(_ leadingDate: Date) {
        let centerDate = leadingDate.addingTimeInterval(halfVisibleWeeklyTimeInterval)
        guard let nearest = weeklyTrendSlots.min(by: {
            abs($0.plotDate.timeIntervalSince(centerDate)) < abs($1.plotDate.timeIntervalSince(centerDate))
        }) else {
            return
        }

        if !marketCalendar.isDate(selectedWeeklySlotDate, equalTo: nearest.weekStart, toGranularity: .weekOfYear) {
            selectedWeeklySlotDate = nearest.weekStart
        }
    }

    private func alignSelectedWeeklySlotToLatest() {
        guard let target = latestWeeklyDataSlot else { return }
        selectedWeeklySlotDate = target.weekStart
        weeklyChartScrollPosition = leadingDateForWeeklyCenteredFocus(target.plotDate)
    }

    private func midWeekInMarketCalendar(for weekStart: Date) -> Date {
        marketCalendar.date(byAdding: .day, value: 3, to: weekStart) ?? weekStart
    }

    private var selectedDayEntries: [DayUploadEntry] {
        viewModel.uploadEntries(on: selectedDay, currency: viewModel.statsDisplayCurrency)
    }

    private var monthTitleFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }

    private var monthAmountMap: [Date: Double] {
        Dictionary(uniqueKeysWithValues: rows.map {
            (marketCalendar.startOfDay(for: $0.day), $0.convertedAmount)
        })
    }

    private var calendarHeatmapMaxAbsAmount: Double {
        let calendar = marketCalendar
        return monthAmountMap
            .filter { calendar.isDate($0.key, equalTo: displayedMonth, toGranularity: .month) }
            .map { abs($0.value) }
            .max() ?? 0
    }

    private var currentMonthTotalAmount: Double {
        let calendar = marketCalendar
        return monthAmountMap.reduce(0) { total, pair in
            if calendar.isDate(pair.key, equalTo: displayedMonth, toGranularity: .month) {
                return total + pair.value
            }
            return total
        }
    }

    private var summaryDisplayAmount: Double {
        if summaryPeriod == .currentWeek {
            let range = currentWeekRange
            return monthAmountMap.reduce(0) { total, pair in
                if pair.key >= range.start && pair.key <= range.end {
                    return total + pair.value
                }
                return total
            }
        }

        if summaryPeriod == .currentMonth {
            return currentMonthTotalAmount
        }

        return viewModel.dailyTotalAmount(for: viewModel.statsDisplayCurrency) ?? 0
    }

    private func dayText(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: day)
    }

    private var keyStatsScopeRows: [DailyAmountRow] {
        switch summaryPeriod {
        case .currentWeek:
            let range = currentWeekRange
            return rows.filter {
                let day = marketCalendar.startOfDay(for: $0.day)
                return day >= range.start && day <= range.end
            }
        case .currentMonth:
            return currentMonthRows
        case .allTime:
            return rows
        }
    }

    private var maxProfitDayStat: (day: Date, amount: Double)? {
        guard let row = keyStatsScopeRows.max(by: { $0.convertedAmount < $1.convertedAmount }),
              row.convertedAmount > 0 else {
            return nil
        }
        return (day: marketCalendar.startOfDay(for: row.day), amount: row.convertedAmount)
    }

    private var maxLossDayStat: (day: Date, amount: Double)? {
        guard let row = keyStatsScopeRows.min(by: { $0.convertedAmount < $1.convertedAmount }),
              row.convertedAmount < 0 else {
            return nil
        }
        return (day: marketCalendar.startOfDay(for: row.day), amount: row.convertedAmount)
    }

    private var currentMonthRows: [DailyAmountRow] {
        let calendar = marketCalendar
        return rows.filter { calendar.isDate($0.day, equalTo: displayedMonth, toGranularity: .month) }
    }

    private func calendarMood(for date: Date) -> KeyStatMood? {
        guard let amount = amountValue(for: date) else {
            return nil
        }

        if amount > 0 {
            return .profit
        }

        if amount < 0 {
            return .loss
        }

        return nil
    }

    private func luluCalendarMood(for date: Date) -> LuluCalendarMood? {
        guard let amount = amountValue(for: date) else {
            return .defaultAsset
        }

        if amount > 0 {
            return .profit
        }

        if amount < 0 {
            return .loss
        }

        return nil
    }

    private var selectedCalendarPresentation: CalendarMoodPresentation? {
        switch selectedStatsMoodMode {
        case .standard:
            guard let mood = calendarMood(for: selectedDay) else { return nil }
            return .standard(mood)
        case .lulu:
            guard let mood = luluCalendarMood(for: selectedDay) else { return nil }
            return .lulu(mood)
        case .custom:
            guard selectedCustomMoodMode != nil else {
                guard let fallbackMood = calendarMood(for: selectedDay) else { return nil }
                return .standard(fallbackMood)
            }
            guard let mood = luluCalendarMood(for: selectedDay) else { return nil }
            return .custom(mood)
        }
    }

    private func refreshSelectedLuluAsset() {
        guard selectedStatsMoodMode == .lulu || selectedStatsMoodMode == .custom else {
            randomizedLuluAssetFileName = nil
            randomizedCustomAssetID = nil
            return
        }

        guard let mood = luluCalendarMood(for: selectedDay) else {
            randomizedLuluAssetFileName = nil
            randomizedCustomAssetID = nil
            return
        }

        if selectedStatsMoodMode == .custom {
            randomizedLuluAssetFileName = nil
            randomizedCustomAssetID = randomCustomAssetID(for: mood)
            return
        }

        switch mood {
        case .defaultAsset:
            randomizedLuluAssetFileName = luluDefaultGIFName
        case .profit:
            switch selectedLuluMoodBehavior {
            case .random:
                randomizedLuluAssetFileName = LuluHappyAsset.allCases.randomElement()?.fileName
            case .manual:
                randomizedLuluAssetFileName = selectedLuluHappyAsset.fileName
            }
        case .loss:
            switch selectedLuluMoodBehavior {
            case .random:
                randomizedLuluAssetFileName = LuluBadAsset.allCases.randomElement()?.fileName
            case .manual:
                randomizedLuluAssetFileName = selectedLuluBadAsset.fileName
            }
        }
    }

    private func randomCustomAssetID(for mood: LuluCalendarMood) -> UUID? {
        guard let mode = selectedCustomMoodMode else { return nil }
        switch mood {
        case .defaultAsset:
            return mode.defaultAsset?.id
        case .profit:
            switch mode.behavior {
            case .random:
                return mode.profitAssets.randomElement()?.id
            case .manual:
                return mode.selectedProfitAssetID ?? mode.profitAssets.first?.id
            }
        case .loss:
            switch mode.behavior {
            case .random:
                return mode.lossAssets.randomElement()?.id
            case .manual:
                return mode.selectedLossAssetID ?? mode.lossAssets.first?.id
            }
        }
    }

    private func resolvedLuluAssetFileName(for mood: LuluCalendarMood) -> String? {
        switch mood {
        case .defaultAsset:
            return luluDefaultGIFName
        case .profit:
            switch selectedLuluMoodBehavior {
            case .random:
                return randomizedLuluAssetFileName ?? LuluHappyAsset.allCases.first?.fileName
            case .manual:
                return selectedLuluHappyAsset.fileName
            }
        case .loss:
            switch selectedLuluMoodBehavior {
            case .random:
                return randomizedLuluAssetFileName ?? LuluBadAsset.allCases.first?.fileName
            case .manual:
                return selectedLuluBadAsset.fileName
            }
        }
    }

    private func resolvedCustomAsset(for mood: LuluCalendarMood) -> CustomStatsMoodAsset? {
        guard let mode = selectedCustomMoodMode else { return nil }
        switch mood {
        case .defaultAsset:
            return mode.defaultAsset
        case .profit:
            switch mode.behavior {
            case .random:
                if let randomizedCustomAssetID,
                   let asset = mode.profitAssets.first(where: { $0.id == randomizedCustomAssetID }) {
                    return asset
                }
                return mode.profitAssets.first
            case .manual:
                if let selectedID = mode.selectedProfitAssetID,
                   let asset = mode.profitAssets.first(where: { $0.id == selectedID }) {
                    return asset
                }
                return mode.profitAssets.first
            }
        case .loss:
            switch mode.behavior {
            case .random:
                if let randomizedCustomAssetID,
                   let asset = mode.lossAssets.first(where: { $0.id == randomizedCustomAssetID }) {
                    return asset
                }
                return mode.lossAssets.first
            case .manual:
                if let selectedID = mode.selectedLossAssetID,
                   let asset = mode.lossAssets.first(where: { $0.id == selectedID }) {
                    return asset
                }
                return mode.lossAssets.first
            }
        }
    }

    private var monthWinRateStat: (wins: Int, total: Int, rate: Double)? {
        let monthRows = currentMonthRows
        guard !monthRows.isEmpty else { return nil }
        let wins = monthRows.filter { $0.convertedAmount > 0 }.count
        let total = monthRows.count
        let rate = total > 0 ? Double(wins) / Double(total) : 0
        return (wins, total, rate)
    }

    private var monthOverMonthStat: (delta: Double, percent: Double?)? {
        let calendar = marketCalendar
        let thisMonthTotal = currentMonthTotalAmount
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else {
            return nil
        }

        let previousMonthTotal = monthAmountMap.reduce(0.0) { total, pair in
            if calendar.isDate(pair.key, equalTo: previousMonth, toGranularity: .month) {
                return total + pair.value
            }
            return total
        }

        let delta = thisMonthTotal - previousMonthTotal
        let percent: Double? = previousMonthTotal == 0 ? nil : (delta / abs(previousMonthTotal)) * 100
        return (delta, percent)
    }

    private var keyStatsItems: [KeyStatItem] {
        let profit: (String, String) = {
            guard let stat = maxProfitDayStat else { return ("--", "--") }
            return (dayText(stat.day), compactAmountText(stat.amount))
        }()

        let loss: (String, String) = {
            guard let stat = maxLossDayStat else { return ("--", "--") }
            return (dayText(stat.day), compactAmountText(stat.amount))
        }()

        let winRate: (String, String, Color) = {
            guard let stat = monthWinRateStat else { return ("本月", "--", .secondary) }
            let ratio = "\(stat.wins)/\(stat.total)"
            let percentText = String(format: "%.1f%%", stat.rate * 100)
            let tone: Color = stat.rate >= 0.5 ? positiveColor : negativeColor
            return ("本月", "\(ratio)（\(percentText)）", tone)
        }()

        let monthVsMonth: (String, String, Color) = {
            guard let stat = monthOverMonthStat else { return ("环比", "--", .secondary) }
            let deltaText = compactAmountText(stat.delta)
            let percentText = stat.percent.map { String(format: "%+.1f%%", $0) } ?? "--"
            let tone = signedAmountColor(stat.delta, zeroColor: .secondary)
            return ("本月vs上月", "\(deltaText) / \(percentText)", tone)
        }()

        let rawItems = [
            KeyStatItem(title: "最大盈利日", day: profit.0, amount: profit.1, tone: positiveColor),
            KeyStatItem(title: "最大亏损日", day: loss.0, amount: loss.1, tone: negativeColor),
            KeyStatItem(title: "胜率", day: winRate.0, amount: winRate.1, tone: winRate.2),
            KeyStatItem(title: "环比变化", day: monthVsMonth.0, amount: monthVsMonth.1, tone: monthVsMonth.2)
        ]

        guard hideStatsNumbers else { return rawItems }
        return rawItems.map { item in
            KeyStatItem(
                title: item.title,
                day: maskedNumericText(item.day),
                amount: maskedNumericText(item.amount),
                tone: subtitleColor
            )
        }
    }

    private func compactAmountText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let absText = formatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.2f", abs(value))
        return value >= 0 ? "+\(absText)" : "-\(absText)"
    }

    private var summaryTitleText: String {
        switch summaryPeriod {
        case .currentWeek:
            return "本周收益"
        case .currentMonth:
            return "本月收益"
        case .allTime:
            return "累计收益"
        }
    }

    private var summaryMainAmount: Double {
        summaryDisplayAmount
    }

    private var summaryMainAmountText: String {
        guard !hideStatsNumbers else { return hiddenValueMask }
        return viewModel.formatAmount(summaryMainAmount, currency: viewModel.statsDisplayCurrency)
    }

    private var currentWeekRange: (start: Date, end: Date) {
        var mondayCalendar = marketCalendar
        mondayCalendar.firstWeekday = 2
        mondayCalendar.minimumDaysInFirstWeek = 4

        let today = mondayCalendar.startOfDay(for: Date())
        let components = mondayCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        let start = mondayCalendar.date(from: components) ?? today
        return (start: start, end: today)
    }

    private func currentConsecutiveTrendStatus() -> ConsecutiveTrendStatus? {
        let calendar = marketCalendar
        let hintInput = consecutiveTrendHintInput(calendar: calendar)
        let sortedEntries = hintInput.amountByDay.sorted { $0.key > $1.key }
        guard let latestAmount = sortedEntries.first?.value else {
            return nil
        }

        if latestAmount == 0 {
            return nil
        }

        let isProfit = latestAmount > 0
        var streakCount = 0

        for entry in sortedEntries {
            let amount = entry.value
            if isProfit {
                guard amount > 0 else { break }
            } else {
                guard amount < 0 else { break }
            }

            streakCount += 1
        }

        guard streakCount >= 4 else {
            return nil
        }

        return ConsecutiveTrendStatus(
            type: isProfit ? .profit : .loss,
            streakCount: streakCount
        )
    }

    private func refreshConsecutiveTrendHint() {
        guard let status = currentConsecutiveTrendStatus() else {
            displayedConsecutiveTrendHint = nil
            return
        }

        switch status.type {
        case .profit:
            displayedConsecutiveTrendHint = ConsecutiveTrendHint(
                symbolName: "chart.line.uptrend.xyaxis.circle.fill",
                message: nextConsecutiveTrendMessage(for: .profit),
                detail: "已连续盈利 \(status.streakCount) 天",
                accentColor: positiveColor,
                backgroundColor: positiveColor.opacity(0.10)
            )
        case .loss:
            displayedConsecutiveTrendHint = ConsecutiveTrendHint(
                symbolName: "shield.lefthalf.filled.badge.checkmark",
                message: nextConsecutiveTrendMessage(for: .loss),
                detail: "已连续亏损 \(status.streakCount) 天",
                accentColor: negativeColor,
                backgroundColor: negativeColor.opacity(0.10)
            )
        }
    }

    private func nextConsecutiveTrendMessage(for type: ConsecutiveTrendType) -> String {
        let defaults = UserDefaults.standard
        let baseStorageKey: String
        let allMessages = messages(for: type, tone: selectedTrendHintTone)

        switch type {
        case .profit:
            baseStorageKey = Self.profitHintQueueStorageKey
        case .loss:
            baseStorageKey = Self.lossHintQueueStorageKey
        }
        let storageKey = "\(baseStorageKey).\(selectedTrendHintTone.rawValue)"

        var queue = (defaults.stringArray(forKey: storageKey) ?? [])
            .filter { allMessages.contains($0) }

        if queue.isEmpty {
            queue = allMessages.shuffled()
        }

        let selected = queue.removeFirst()
        defaults.set(queue, forKey: storageKey)
        return selected
    }

    private func messages(for type: ConsecutiveTrendType, tone: TrendHintTone) -> [String] {
        switch (tone, type) {
        case (.steady, .profit):
            return Self.steadyProfitMessages
        case (.steady, .loss):
            return Self.steadyLossMessages
        case (.wild, .profit):
            return Self.wildProfitMessages
        case (.wild, .loss):
            return Self.wildLossMessages
        case (.savage, .profit):
            return Self.savageProfitMessages
        case (.savage, .loss):
            return Self.savageLossMessages
        }
    }

    private func consecutiveTrendHintInput(calendar: Calendar) -> (latestDataDay: Date, amountByDay: [Date: Double]) {
#if DEBUG
        if let debugInput = debugConsecutiveTrendHintInput(calendar: calendar) {
            return debugInput
        }
#endif
        let amountByDay = monthAmountMap
        let latestDataDay = rows.first?.day ?? calendar.startOfDay(for: Date())
        return (latestDataDay, amountByDay)
    }

#if DEBUG
    private var trendHintLabScenario: TrendHintLabScenario {
        TrendHintLabScenario(rawValue: trendHintLabScenarioRawValue) ?? .none
    }

    private func debugConsecutiveTrendHintInput(calendar: Calendar) -> (latestDataDay: Date, amountByDay: [Date: Double])? {
        let latestDataDay = calendar.startOfDay(for: Date())
        let offsetsAndAmounts: [(Int, Double)]

        switch trendHintLabScenario {
        case .none:
            return nil
        case .profitStreak4:
            offsetsAndAmounts = [(0, 120), (-1, 90), (-2, 60), (-3, 30)]
        case .lossStreak4:
            offsetsAndAmounts = [(0, -120), (-1, -90), (-2, -60), (-3, -30)]
        case .shortStreak3:
            offsetsAndAmounts = [(0, 120), (-1, 90), (-2, 60), (-3, -30)]
        case .latestZero:
            offsetsAndAmounts = [(0, 0), (-1, 120), (-2, 90), (-3, 60), (-4, 30)]
        }

        var amountByDay: [Date: Double] = [:]
        for (offset, amount) in offsetsAndAmounts {
            guard let day = calendar.date(byAdding: .day, value: offset, to: latestDataDay) else {
                continue
            }
            amountByDay[day] = amount
        }

        return (latestDataDay, amountByDay)
    }
#endif

    private func chartDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        switch trendPeriod {
        case .daily, .weekly:
            formatter.dateFormat = "M月d日"
        case .monthly:
            formatter.dateFormat = "yyyy年M月"
        }
        return formatter.string(from: date)
    }

    private var weekdaySymbols: [String] { ["日", "一", "二", "三", "四", "五", "六"] }

    private var todayInCalendarGrid: Date {
        let components = localDisplayCalendar.dateComponents([.year, .month, .day], from: Date())
        return marketCalendar.date(from: components) ?? marketCalendar.startOfDay(for: Date())
    }

    private func normalizedCalendarDay(_ day: Date) -> Date {
        marketCalendar.startOfDay(for: day)
    }

    private func amountText(for day: Date) -> String? {
        let normalizedDay = normalizedCalendarDay(day)
        if let amount = monthAmountMap[normalizedDay] {
            if amount == 0 {
                return nil
            }
            return hideStatsNumbers ? hiddenValueMask : String(format: "%+.2f", amount)
        }

        if marketCalendar.isDate(normalizedDay, inSameDayAs: todayInCalendarGrid) {
            return "未更新"
        }

        if normalizedDay < todayInCalendarGrid {
            return nil
        }

        return nil
    }

    private func amountValue(for day: Date) -> Double? {
        monthAmountMap[normalizedCalendarDay(day)]
    }

    private func isFutureCalendarDay(_ day: Date) -> Bool {
        normalizedCalendarDay(day) > todayInCalendarGrid
    }

    private func hasRecordedAmount(for day: Date) -> Bool {
        amountValue(for: day) != nil
    }

    private func isUnrecordedFutureDay(_ day: Date) -> Bool {
        isFutureCalendarDay(day) && !hasRecordedAmount(for: day)
    }

    private func dayCellBackground(for day: Date, isSelected: Bool) -> Color {
        if isUnrecordedFutureDay(day) {
            return .clear
        }

        let amount = amountValue(for: day) ?? 0
        let heat = calendarHeatmapMaxAbsAmount > 0 ? min(abs(amount) / calendarHeatmapMaxAbsAmount, 1) : 0
        let opacity = 0.14 + (heat * 0.16)

        if hideStatsNumbers {
            return Color(uiColor: .tertiarySystemFill).opacity(isSelected ? 0.78 : 0.60)
        }

        if amount > 0 {
            return positiveColor.opacity(isSelected ? opacity + 0.04 : opacity)
        }
        if amount < 0 {
            return negativeColor.opacity(isSelected ? opacity + 0.04 : opacity)
        }
        return Color(uiColor: .tertiarySystemFill).opacity(isSelected ? 0.68 : 0.50)
    }

    private func dayPrimaryTextColor(for day: Date, isSelected: Bool) -> Color {
        if isSelected {
            return .primary
        }
        return .primary
    }

    private func amountDisplayColor(for day: Date, isSelected: Bool) -> Color {
        guard let amount = amountValue(for: day) else {
            return .secondary
        }

        if hideStatsNumbers {
            return subtitleColor.opacity(isSelected ? 0.95 : 0.82)
        }

        if amount > 0 {
            return positiveColor
        }
        if amount < 0 {
            return negativeColor
        }
        return .secondary
    }

    private var calendarGridDays: [Date?] {
        let calendar = marketCalendar

        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthRange = calendar.range(of: .day, in: .month, for: monthInterval.start) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingCount)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                result.append(calendar.startOfDay(for: date))
            }
        }

        while result.count % 7 != 0 {
            result.append(nil)
        }

        return result
    }

    var body: some View {
        NavigationStack {
            mainScrollView
        }
    }

    private var titleHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("统计面板")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(titleColor)
                    statsNumberPrivacyToggle
                }
                Text("按美东交易日查看收益日历与趋势")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(subtitleColor)
            }

            Spacer()

            NavigationLink(destination: StatsRecordsListView(viewModel: viewModel, selectedDay: selectedDay)) {
                HStack(spacing: 3) {
                    Text("查看记录")
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentBlue)
            }
        }
    }

    private var statsNumberPrivacyToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                hideStatsNumbers.toggle()
            }
        } label: {
            Image(systemName: hideStatsNumbers ? "eye.slash.fill" : "eye.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(accentBlue)
                .frame(width: 28, height: 28)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(glassStrokeColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hideStatsNumbers ? "显示统计数字" : "隐藏统计数字")
    }

    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleHeader
                calendarSection
                summarySection
                keyStatsSection
                trendSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 112)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: handleOnAppear)
        .onChange(of: trendPeriod) { _, newValue in
            handleTrendPeriodChange(newValue)
        }
        .onChange(of: dailyChartScrollPosition) { _, newValue in
            if trendPeriod == .daily {
                syncDailySelectionFromScrollPosition(newValue)
            }
        }
        .onChange(of: monthlyChartScrollPosition) { _, newValue in
            if trendPeriod == .monthly {
                syncMonthlySelectionFromScrollPosition(newValue)
            }
        }
        .onChange(of: selectedDay) { _, _ in
            refreshSelectedLuluAsset()
        }
        .onChange(of: statsMoodModeRawValue) { _, _ in
            refreshSelectedLuluAsset()
        }
        .onChange(of: luluMoodBehaviorRawValue) { _, _ in
            refreshSelectedLuluAsset()
        }
        .onChange(of: luluHappyAssetRawValue) { _, _ in
            refreshSelectedLuluAsset()
        }
        .onChange(of: luluBadAssetRawValue) { _, _ in
            refreshSelectedLuluAsset()
        }
        .onChange(of: customStatsMoodModeID) { _, _ in
            refreshSelectedLuluAsset()
        }
        .onChange(of: statsMoodViewModel.customModes) { _, _ in
            refreshSelectedLuluAsset()
        }
        .onChange(of: monthAmountMap) { _, _ in
            refreshSelectedLuluAsset()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                currencyMenu
            }
        }
        .sheet(isPresented: $isCurrencyPickerPresented) {
            currencyPickerSheet
                .presentationDetents([.height(310)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }

    private func handleOnAppear() {
        refreshConsecutiveTrendHint()
        guard !hasInitializedSelection else { return }
        hasInitializedSelection = true

        if let latestDay = rows.first?.day {
            displayedMonth = latestDay
            selectedDay = latestDay
        } else {
            displayedMonth = todayInCalendarGrid
            selectedDay = todayInCalendarGrid
        }

        refreshSelectedLuluAsset()
        
        DispatchQueue.main.async {
            self.alignSelectedDailySlotToLatest()
            self.alignSelectedWeeklySlotToLatest()
            self.alignSelectedMonthlySlotToLatest()
        }
    }

    private func handleTrendPeriodChange(_ newValue: TrendPeriod) {
        if newValue == .daily {
            alignSelectedDailySlotToLatest()
        } else if newValue == .monthly {
            alignSelectedMonthlySlotToLatest()
        }
    }

    private func handleTrendSlotsChange(_ newValue: [Date]) {
        if trendPeriod == .daily {
            alignSelectedDailySlotToLatest()
        } else if trendPeriod == .monthly {
            alignSelectedMonthlySlotToLatest()
        }
    }

    private var currencyMenu: some View {
        Button {
            isCurrencyPickerPresented = true
        } label: {
            HStack(spacing: 4) {
                Text(currencyDisplayLabel(viewModel.statsDisplayCurrency))
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(accentBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(glassStrokeColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var currencyPickerSheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("选择统计币种")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(titleColor)

                Text("当前：\(currencyDisplayLabel(viewModel.statsDisplayCurrency))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(Currency.displayOrder) { currency in
                        Button {
                            viewModel.statsDisplayCurrency = currency
                            isCurrencyPickerPresented = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: currency == viewModel.statsDisplayCurrency ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(currency == viewModel.statsDisplayCurrency ? settingsAccent : .secondary.opacity(0.65))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currencyDisplayLabel(currency))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(titleColor)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(glassStrokeColor, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("切换到\(currency.displayName)")
                    }
                }

                Button("取消") {
                    isCurrencyPickerPresented = false
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(glassFillColor)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(glassStrokeColor, lineWidth: 1)
                    }
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }

    private var settingsAccent: Color {
        Color(red: 0.95, green: 0.52, blue: 0.16)
    }

    private func currencyDisplayLabel(_ currency: Currency) -> String {
        "\(currency.chineseName)（\(currency.rawValue)）"
    }

    private var calendarHeader: some View {
        HStack {
            Button {
                let calendar = marketCalendar
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(accentBlue)

            Spacer()

            Text(monthTitleFormatter.string(from: displayedMonth))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)

            Spacer()

            Button {
                let calendar = marketCalendar
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(accentBlue)
        }
    }

    private func dayCellBorderColor(for day: Date, isSelected: Bool) -> Color {
        guard isSelected else { return .clear }
        return accentBlue.opacity(0.34)
    }

    private var calendarGrid: some View {
        let cellWidth = max((calendarGridWidth - (calendarCellSpacing * 6)) / 7, 30)
        let cellHeight = max(cellWidth, 56)
        let columns = Array(repeating: GridItem(.fixed(cellWidth), spacing: calendarCellSpacing), count: 7)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: calendarCellSpacing) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: cellWidth)
                }
            }

            LazyVGrid(columns: columns, spacing: calendarCellSpacing) {
                ForEach(Array(calendarGridDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isSelected = marketCalendar.isDate(selectedDay, inSameDayAs: date)
                        Button {
                            selectedDay = date
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(marketCalendar.component(.day, from: date))")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(dayPrimaryTextColor(for: date, isSelected: isSelected))
                                if let amountText = amountText(for: date) {
                                    Text(amountText)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(amountDisplayColor(for: date, isSelected: isSelected))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .padding(.horizontal, 2)
                                } else if marketCalendar.isDate(normalizedCalendarDay(date), inSameDayAs: todayInCalendarGrid),
                                          amountValue(for: date) == nil {
                                    Text("未更新")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 2)
                                }
                            }
                            .frame(width: cellWidth, height: cellHeight)
                            .background(dayCellBackground(for: date, isSelected: isSelected), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(dayCellBorderColor(for: date, isSelected: isSelected), lineWidth: isSelected ? 1 : 0)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: cellWidth, height: cellHeight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        calendarGridWidth = proxy.size.width
                    }
                    .onChange(of: proxy.size.width) { _, newValue in
                        calendarGridWidth = newValue
                    }
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            calendarHeader
            calendarGrid
        }
        .padding(16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(glassFillColor)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )

                GeometryReader { proxy in
                    if let presentation = selectedCalendarPresentation {
                        let backgroundSize = CGSize(
                            width: max(proxy.size.width - 2, 0),
                            height: max(proxy.size.height - 2, 0)
                        )

                        calendarMoodBackground(for: presentation, containerSize: backgroundSize)
                            .frame(width: backgroundSize.width, height: backgroundSize.height)
                            .opacity(hideStatsNumbers ? 0.18 : 0.30)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(glassStrokeColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 5)
        }
        .animation(.easeInOut(duration: 0.22), value: selectedCalendarPresentation)
        .animation(.easeInOut(duration: 0.22), value: selectedStatsMoodMode)
    }

    @ViewBuilder
    private func calendarMoodBackground(for presentation: CalendarMoodPresentation, containerSize: CGSize) -> some View {
        switch presentation {
        case .standard(let mood):
            CalendarMoodBadgeView(
                mood: mood,
                positiveColor: positiveColor,
                negativeColor: negativeColor,
                isMuted: hideStatsNumbers
            )
            .frame(width: 220, height: 220)
        case .lulu(let mood):
            if hideStatsNumbers {
                EmptyView()
            } else if let assetFileName = resolvedLuluAssetFileName(for: mood) {
                KingfisherGIFView(fileName: assetFileName, contentMode: .scaleAspectFill)
                    .frame(width: containerSize.width, height: containerSize.height)
                    .clipped()
            } else {
                switch mood {
                case .profit:
                    CalendarMoodBadgeView(
                        mood: .profit,
                        positiveColor: positiveColor,
                        negativeColor: negativeColor,
                        isMuted: false
                    )
                    .frame(width: 220, height: 220)
                case .loss:
                    CalendarMoodBadgeView(
                        mood: .loss,
                        positiveColor: positiveColor,
                        negativeColor: negativeColor,
                        isMuted: false
                    )
                    .frame(width: 220, height: 220)
                case .defaultAsset:
                    EmptyView()
                }
            }
        case .custom(let mood):
            if hideStatsNumbers {
                EmptyView()
            } else if let asset = resolvedCustomAsset(for: mood), asset.signedURL != nil {
                KingfisherRemoteGIFView(url: asset.signedURL, contentMode: .scaleAspectFill)
                    .frame(width: containerSize.width, height: containerSize.height)
                    .clipped()
            } else {
                switch mood {
                case .profit:
                    CalendarMoodBadgeView(
                        mood: .profit,
                        positiveColor: positiveColor,
                        negativeColor: negativeColor,
                        isMuted: false
                    )
                    .frame(width: 220, height: 220)
                case .loss:
                    CalendarMoodBadgeView(
                        mood: .loss,
                        positiveColor: positiveColor,
                        negativeColor: negativeColor,
                        isMuted: false
                    )
                    .frame(width: 220, height: 220)
                case .defaultAsset:
                    EmptyView()
                }
            }
        }
    }

    private var trendHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("趋势走向")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(titleColor)
                Spacer()
                Picker("趋势周期", selection: $trendPeriod) {
                    ForEach(trendPeriodOptions) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 178)
            }

            Picker("图形样式", selection: $trendChartStyle) {
                ForEach(TrendChartStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var dailyTrendChart: some View {
        VStack(spacing: 0) {
            Text(selectedDailyDateText)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(selectedDailySlotAmountText)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(selectedDailySlotAmountColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

            Chart {
                ForEach(dailyTrendSlots) { slot in
                    if let amount = slot.amount {
                        switch trendChartStyle {
                        case .bar:
                            BarMark(
                                x: .value("日期", slot.plotDate),
                                y: .value("金额", amount),
                                width: .fixed(9)
                            )
                            .foregroundStyle(signedAmountColor(amount))
                        case .line:
                            LineMark(
                                x: .value("日期", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(signedAmountColor(amount))
                        case .area:
                            AreaMark(
                                x: .value("日期", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(signedAmountColor(amount).opacity(0.35))
                        case .scatter:
                            PointMark(
                                x: .value("日期", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .symbolSize(40)
                            .foregroundStyle(signedAmountColor(amount))
                        }
                    }
                }

                RuleMark(y: .value("中轴", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(accentBlue.opacity(0.28))

                RuleMark(x: .value("中心线", centeredPlotDateFromScroll))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(selectedDailyRuleColor)
            }
            .chartXScale(domain: dailyChartXDomain)
            .chartYScale(domain: dailyTrendYDomain)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 60 * 60 * 24 * 7)
            .chartScrollPosition(x: $dailyChartScrollPosition)
            .chartScrollTargetBehavior(.valueAligned(matching: DateComponents(timeZone: marketCalendar.timeZone, hour: 12)))
            .chartXAxis(.hidden)
            .frame(height: 220)

            if let first = dailyTrendSlots.first?.day, let last = dailyTrendSlots.last?.day {
                HStack {
                    Text(dailyBoundaryDateFormatter.string(from: first))
                    Spacer()
                    Text(dailyBoundaryDateFormatter.string(from: last))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
    }

    private var monthlyTrendChart: some View {
        VStack(spacing: 0) {
            Text(selectedMonthlyDateText)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(selectedMonthlySlotAmountText)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(selectedMonthlySlotAmountColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

            Chart {
                ForEach(monthlyTrendSlots) { slot in
                    if let amount = slot.amount {
                        switch trendChartStyle {
                        case .bar:
                            BarMark(
                                x: .value("月份", slot.plotDate),
                                y: .value("金额", amount),
                                width: .fixed(14)
                            )
                            .foregroundStyle(signedAmountColor(amount))
                        case .line:
                            LineMark(
                                x: .value("月份", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(signedAmountColor(amount))
                        case .area:
                            AreaMark(
                                x: .value("月份", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(signedAmountColor(amount).opacity(0.35))
                        case .scatter:
                            PointMark(
                                x: .value("月份", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .symbolSize(48)
                            .foregroundStyle(signedAmountColor(amount))
                        }
                    }
                }

                RuleMark(y: .value("中轴", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(accentBlue.opacity(0.28))

                RuleMark(x: .value("中心线", monthlyCenteredPlotDateFromScroll))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(selectedMonthlyRuleColor)
            }
            .chartXScale(domain: monthlyChartXDomain)
            .chartYScale(domain: monthlyTrendYDomain)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 60 * 60 * 24 * 30 * 6)
            .chartScrollPosition(x: $monthlyChartScrollPosition)
            .chartScrollTargetBehavior(.valueAligned(matching: DateComponents(timeZone: marketCalendar.timeZone, day: 15)))
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, calendar: marketCalendar)) { _ in
                }
            }
            .frame(height: 220)

            if let first = monthlyTrendSlots.first?.month, let last = monthlyTrendSlots.last?.month {
                HStack {
                    Text(monthlyBoundaryDateFormatter.string(from: first))
                    Spacer()
                    Text(monthlyBoundaryDateFormatter.string(from: last))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
    }

    private var weeklyTrendChart: some View {
        VStack(spacing: 0) {
            Text(selectedWeeklyDateText)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(selectedWeeklySlotAmountText)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(selectedWeeklySlotAmountColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

            Chart {
                ForEach(weeklyTrendSlots) { slot in
                    if let amount = slot.amount {
                        switch trendChartStyle {
                        case .bar:
                            BarMark(
                                x: .value("周", slot.plotDate),
                                y: .value("金额", amount),
                                width: .fixed(12)
                            )
                            .foregroundStyle(signedAmountColor(amount))
                        case .line:
                            LineMark(
                                x: .value("周", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(signedAmountColor(amount))
                        case .area:
                            AreaMark(
                                x: .value("周", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(signedAmountColor(amount).opacity(0.35))
                        case .scatter:
                            PointMark(
                                x: .value("周", slot.plotDate),
                                y: .value("金额", amount)
                            )
                            .symbolSize(44)
                            .foregroundStyle(signedAmountColor(amount))
                        }
                    }
                }

                RuleMark(y: .value("中轴", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(accentBlue.opacity(0.28))

                RuleMark(x: .value("中心线", weeklyCenteredPlotDateFromScroll))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(selectedWeeklyRuleColor)
            }
            .chartXScale(domain: weeklyChartXDomain)
            .chartYScale(domain: weeklyTrendYDomain)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 60 * 60 * 24 * 7 * 8)
            .chartScrollPosition(x: $weeklyChartScrollPosition)
            .chartScrollTargetBehavior(.valueAligned(matching: DateComponents(timeZone: marketCalendar.timeZone, weekday: marketCalendar.firstWeekday)))
            .chartXAxis(.hidden)
            .frame(height: 220)

            if let first = weeklyTrendSlots.first?.weekStart, let last = weeklyTrendSlots.last?.weekStart {
                HStack {
                    Text(weeklyBoundaryDateFormatter.string(from: first))
                    Spacer()
                    Text(weeklyBoundaryDateFormatter.string(from: last))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            trendHeader

            if trendPeriod == .daily {
                if !dailyTrendSlots.isEmpty {
                    dailyTrendChart
                } else {
                    Text("该周期下至少需要一个数据点才能展示趋势")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                if !monthlyTrendSlots.isEmpty {
                    monthlyTrendChart
                } else {
                    Text("该周期下至少需要一个数据点才能展示趋势")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(glassCardBackground(cornerRadius: 28))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text(summaryTitleText)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(titleColor)
                Spacer()
                Picker("汇总范围", selection: $summaryPeriod) {
                    ForEach(SummaryPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 202)
            }

            Text(summaryMainAmountText)
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundStyle(signedAmountColor(summaryMainAmount, zeroColor: .primary))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.64)

            if let hint = displayedConsecutiveTrendHint {
                let hintToneColor = hideStatsNumbers ? subtitleColor : hint.accentColor
                let hintBackgroundColor = hideStatsNumbers ? Color.gray.opacity(0.10) : hint.backgroundColor
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: hint.symbolName)
                        Text(hint.message)
                            .lineLimit(2)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(hintToneColor)
                    Text(hideStatsNumbers ? "已连续****天" : hint.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(hintToneColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(hintBackgroundColor, in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCardBackground(cornerRadius: 28))
    }

    private var keyStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关键统计")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)

            VStack(spacing: 8) {
                ForEach(Array(keyStatsItems.enumerated()), id: \.offset) { _, item in
                    keyStatRow(item)
                }
            }
        }
        .padding(16)
        .background(glassCardBackground(cornerRadius: 28))
    }

    private func keyStatRow(_ item: KeyStatItem) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(item.tone)
                .frame(width: 2, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.day)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(titleColor.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Text(item.amount)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(item.tone)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 190, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(glassStrokeColor, lineWidth: 1)
        }
    }

    private struct CalendarMoodBadgeView: View {
        let mood: KeyStatMood
        let positiveColor: Color
        let negativeColor: Color
        let isMuted: Bool

        private var accentColor: Color {
            switch mood {
            case .profit:
                return isMuted ? Color(uiColor: .tertiaryLabel) : positiveColor
            case .loss:
                return isMuted ? Color(uiColor: .tertiaryLabel) : negativeColor
            }
        }

        private var badgeBaseColor: Color {
            Color(uiColor: .systemBackground).opacity(isMuted ? 0.10 : 0.16)
        }

        var body: some View {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(isMuted ? 0.08 : 0.18))
                    .scaleEffect(1.14)
                    .opacity(isMuted ? 0.16 : 0.28)

                Circle()
                    .fill(badgeBaseColor)
                    .shadow(color: accentColor.opacity(isMuted ? 0.04 : 0.12), radius: 6, x: 0, y: 2)

                MoodBadgeView(
                    mood: mood,
                    positiveColor: positiveColor,
                    negativeColor: negativeColor,
                    isMuted: isMuted
                )
                .padding(3)
            }
        }
    }

    private struct MoodBadgeView: View {
        let mood: KeyStatMood
        let positiveColor: Color
        let negativeColor: Color
        let isMuted: Bool

        private var accentColor: Color {
            switch mood {
            case .profit:
                return isMuted ? Color(uiColor: .tertiaryLabel) : positiveColor.opacity(0.92)
            case .loss:
                return isMuted ? Color(uiColor: .tertiaryLabel) : negativeColor.opacity(0.96)
            }
        }

        private var fillColor: Color {
            switch mood {
            case .profit:
                return isMuted ? Color(uiColor: .secondarySystemFill) : positiveColor.opacity(0.14)
            case .loss:
                return isMuted ? Color(uiColor: .secondarySystemFill) : negativeColor.opacity(0.16)
            }
        }

        private var highlightColor: Color {
            Color.white.opacity(isMuted ? 0.32 : 0.54)
        }

        var body: some View {
            GeometryReader { proxy in
                let size = proxy.size
                let mouthY = mood == .profit ? size.height * 0.58 : size.height * 0.66
                let controlY = mood == .profit ? size.height * 0.72 : size.height * 0.52

                ZStack {
                    Circle()
                        .fill(fillColor)

                    Circle()
                        .stroke(accentColor.opacity(isMuted ? 0.18 : 0.24), lineWidth: 1)

                    Circle()
                        .fill(highlightColor)
                        .frame(width: size.width * 0.30, height: size.height * 0.30)
                        .offset(x: -size.width * 0.16, y: -size.height * 0.18)

                    HStack(spacing: size.width * 0.20) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: size.width * 0.11, height: size.height * 0.11)
                        Circle()
                            .fill(accentColor)
                            .frame(width: size.width * 0.11, height: size.height * 0.11)
                    }
                    .offset(y: -size.height * 0.10)

                    Path { path in
                        path.move(to: CGPoint(x: size.width * 0.32, y: mouthY))
                        path.addQuadCurve(
                            to: CGPoint(x: size.width * 0.68, y: mouthY),
                            control: CGPoint(x: size.width * 0.50, y: controlY)
                        )
                    }
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }

    private func glassCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(glassFillColor)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(glassStrokeColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 5)
    }

    private var pageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [pageBackgroundTop, pageBackgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(uiColor: .systemGray5).opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 46)
                .offset(x: -110, y: -360)

            Circle()
                .fill(accentBlue.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 52)
                .offset(x: 130, y: -240)
        }
    }
}
