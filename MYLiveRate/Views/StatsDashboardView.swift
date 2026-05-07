import SwiftUI
import Charts

struct StatsDashboardView: View {
    private struct DailyTrendSlot: Identifiable {
        let day: Date
        let amount: Double?
        let plotDate: Date

        var id: Date { day }
    }

    @ObservedObject var viewModel: ExchangeRateViewModel
    @State private var selectedDay = Date()
    @State private var trendPeriod: TrendPeriod = .daily
    @State private var displayedMonth = Date()
    @State private var dailyChartScrollPosition: Date = Date()
    @State private var selectedDailySlotDate: Date = Date()
    @State private var calendarGridWidth: CGFloat = 0
    @State private var hasInitializedSelection = false
    private let trendPeriodOptions: [TrendPeriod] = [.daily, .monthly]
    private let calendarCellSpacing: CGFloat = 2
    private let dailyVisibleDays = 7

    private var marketCalendar: Calendar {
        var calendar = viewModel.marketCalendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
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
        String(format: "%+.2f", selectedDailySlotAmount)
    }

    private var selectedDailySlotAmountColor: Color {
        if selectedDailySlotAmount > 0 { return .red }
        if selectedDailySlotAmount < 0 { return .green }
        return .secondary
    }

    private var selectedDailyRuleColor: Color {
        if selectedDailySlotAmount > 0 { return .red }
        return .green
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

    private var todayInMarketCalendar: Date {
        marketCalendar.startOfDay(for: Date())
    }

    private func normalizedCalendarDay(_ day: Date) -> Date {
        marketCalendar.startOfDay(for: day)
    }

    private func amountText(for day: Date) -> String? {
        let normalizedDay = normalizedCalendarDay(day)
        if let amount = monthAmountMap[normalizedDay] {
            if amount == 0 {
                return "0.00"
            }
            return String(format: "%+.2f", amount)
        }

        if marketCalendar.isDate(normalizedDay, inSameDayAs: todayInMarketCalendar) {
            return "未更新"
        }

        if normalizedDay < todayInMarketCalendar {
            return "0.00"
        }

        return nil
    }

    private func amountValue(for day: Date) -> Double? {
        monthAmountMap[normalizedCalendarDay(day)]
    }

    private func isFutureCalendarDay(_ day: Date) -> Bool {
        normalizedCalendarDay(day) > todayInMarketCalendar
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
        let strongOpacity = 0.50
        let weakOpacity = 0.16
        let opacity = isSelected ? strongOpacity : weakOpacity

        if amount > 0 {
            return Color.red.opacity(opacity)
        }
        if amount < 0 {
            return Color.green.opacity(opacity)
        }
        return Color.gray.opacity(isSelected ? 0.30 : 0.12)
    }

    private func dayPrimaryTextColor(for day: Date, isSelected: Bool) -> Color {
        let amount = amountValue(for: day) ?? 0
        if isSelected, amount != 0 {
            return .white
        }
        return .primary
    }

    private func amountDisplayColor(for day: Date, isSelected: Bool) -> Color {
        guard let amount = amountValue(for: day) else {
            return .secondary
        }

        if isSelected, amount != 0 {
            return .white
        }
        if amount > 0 {
            return .red
        }
        if amount < 0 {
            return .green
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
        HStack(alignment: .bottom) {
            Text("收益日历")
                .font(.title2.bold())
            Spacer()
            NavigationLink(destination: StatsRecordsListView(viewModel: viewModel, selectedDay: selectedDay)) {
                Text("查看记录详情 >")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
    }

    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleHeader
                calendarSection
                trendSection
                summarySection
            }
            .padding()
        }
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: handleOnAppear)
        .onChange(of: trendPeriod) { _, newValue in
            handleTrendPeriodChange(newValue)
        }
        .onChange(of: dailyChartScrollPosition) { _, newValue in
            handleScrollPositionChange(newValue)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                currencyMenu
            }
        }
    }

    private func handleOnAppear() {
        guard !hasInitializedSelection else { return }
        hasInitializedSelection = true

        if let latestDay = rows.first?.day {
            displayedMonth = latestDay
            selectedDay = latestDay
        } else {
            let todayInMarket = marketCalendar.startOfDay(for: Date())
            displayedMonth = todayInMarket
            selectedDay = todayInMarket
        }
        
        DispatchQueue.main.async {
            self.alignSelectedDailySlotToLatest()
        }
    }

    private func handleTrendPeriodChange(_ newValue: TrendPeriod) {
        guard newValue == .daily else { return }
        alignSelectedDailySlotToLatest()
    }

    private func handleTrendSlotsChange(_ newValue: [Date]) {
        if trendPeriod == .daily {
            alignSelectedDailySlotToLatest()
        }
    }

    private func handleScrollPositionChange(_ newValue: Date) {
        guard trendPeriod == .daily else { return }
        syncDailySelectionFromScrollPosition(newValue)
    }

    private var currencyMenu: some View {
        Menu {
            ForEach(Currency.allCases) { currency in
                Button {
                    viewModel.statsDisplayCurrency = currency
                } label: {
                    if currency == viewModel.statsDisplayCurrency {
                        Label(currency.displayName, systemImage: "checkmark")
                    } else {
                        Text(currency.displayName)
                    }
                }
            }
        } label: {
            Label(viewModel.statsDisplayCurrency.rawValue, systemImage: "arrow.triangle.2.circlepath")
        }
    }

    private var calendarHeader: some View {
        HStack {
            Button {
                let calendar = marketCalendar
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text(monthTitleFormatter.string(from: displayedMonth))
                .font(.headline)

            Spacer()

            Button {
                let calendar = marketCalendar
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
        }
    }
    private var calendarGrid: some View {
        let cellSize = max((calendarGridWidth - (calendarCellSpacing * 6)) / 7, 28)
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: calendarCellSpacing), count: 7)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: calendarCellSpacing) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize)
                }
            }

            LazyVGrid(columns: columns, spacing: calendarCellSpacing) {
                ForEach(Array(calendarGridDays.enumerated()), id: \.offset) { index, date in
                    if let date {
                        let isSelected = marketCalendar.isDate(selectedDay, inSameDayAs: date)
                        VStack(spacing: 4) {
                            Text("\(marketCalendar.component(.day, from: date))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(dayPrimaryTextColor(for: date, isSelected: isSelected))
                            if let amountText = amountText(for: date) {
                                Text(amountText)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(amountDisplayColor(for: date, isSelected: isSelected))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                        .background(dayCellBackground(for: date, isSelected: isSelected), in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDay = date
                        }
                    } else {
                        Color.clear
                            .frame(width: cellSize, height: cellSize)
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
        VStack(alignment: .leading, spacing: 10) {
            calendarHeader
            calendarGrid
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var trendHeader: some View {
        HStack {
            Text("趋势走向")
                .font(.headline)
            Spacer()
            Picker("趋势周期", selection: $trendPeriod) {
                ForEach(trendPeriodOptions) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }

    private var dailyTrendChart: some View {
        Group {
            if #available(iOS 16.0, *) {
                VStack(spacing: 0) {
                    Text(selectedDailyDateText)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(selectedDailySlotAmountText)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(selectedDailySlotAmountColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)

                    Chart {
                        ForEach(dailyTrendSlots) { slot in
                            if let amount = slot.amount {
                                BarMark(
                                    x: .value("日期", slot.plotDate),
                                    y: .value("金额", amount),
                                    width: .fixed(9)
                                )
                                .foregroundStyle(amount >= 0 ? Color.red : Color.green)
                            }
                        }

                        RuleMark(y: .value("中轴", 0))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(.gray.opacity(0.45))

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
            } else {
                Text("当前系统版本不支持趋势图")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monthlyTrendChart: some View {
        Group {
            if #available(iOS 16.0, *) {
                Chart(trendRows) { row in
                    BarMark(
                        x: .value("日期", row.periodStart),
                        y: .value("金额", row.amount),
                        width: .fixed(14)
                    )
                    .foregroundStyle(row.amount >= 0 ? Color.red : Color.green)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(chartDateText(for: date))
                            }
                        }
                    }
                }
                .frame(height: 220)
            } else {
                Text("当前系统版本不支持趋势图")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                if !trendRows.isEmpty {
                    monthlyTrendChart
                } else {
                    Text("该周期下至少需要一个数据点才能展示趋势")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("汇总金额")
                .font(.headline)
            Text(viewModel.formatAmount(
                viewModel.dailyTotalAmount(for: viewModel.statsDisplayCurrency),
                currency: viewModel.statsDisplayCurrency
            ))
            .font(.system(size: 30, weight: .bold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
