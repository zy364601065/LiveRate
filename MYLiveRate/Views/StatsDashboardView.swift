import SwiftUI
import Charts

struct StatsDashboardView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @State private var selectedDay = Date()
    @State private var trendPeriod: TrendPeriod = .daily
    @State private var displayedMonth = Date()

    private var marketCalendar: Calendar {
        var calendar = viewModel.marketCalendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.firstWeekday = 2
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
        Dictionary(uniqueKeysWithValues: rows.map { ($0.day, $0.convertedAmount) })
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

    private var weekdaySymbols: [String] { ["一", "二", "三", "四", "五", "六", "日"] }

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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("上传日历")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 10) {
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

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            ForEach(weekdaySymbols, id: \.self) { symbol in
                                Text(symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }

                            ForEach(Array(calendarGridDays.enumerated()), id: \.offset) { _, date in
                                if let date {
                                    let amount = monthAmountMap[date]
                                    VStack(spacing: 2) {
                                        Text("\(marketCalendar.component(.day, from: date))")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if let amount {
                                            Text(String(format: "%+.2f", amount))
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(amount >= 0 ? Color.red : Color.green)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        } else {
                                            Text(" ")
                                                .font(.caption2)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedDay = date
                                    }
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("按美东交易日统计（America/New_York）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("该日期上传金额")
                            .font(.headline)

                        if selectedDayEntries.isEmpty {
                            Text("这一天还没有上传记录")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(selectedDayEntries) { entry in
                                HStack {
                                    Text(timeFormatter.string(from: entry.timestamp))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(String(format: "%+.2f %@", entry.convertedAmount, viewModel.statsDisplayCurrency.rawValue))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(entry.convertedAmount >= 0 ? Color.red : Color.green)
                                }
                                .padding(.vertical, 6)

                                if entry.id != selectedDayEntries.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    Text("日历表格统计")
                        .font(.headline)

                    if rows.isEmpty {
                        Text("还没有上传记录，先去汇率页上传图片吧")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            HStack {
                                Text("日期")
                                Spacer()
                                Text("最后金额")
                            }
                            .font(.subheadline.bold())
                            .padding(.vertical, 10)

                            Divider()

                            ForEach(rows) { row in
                                HStack {
                                    Text(dayFormatter.string(from: row.day))
                                        .monospacedDigit()
                                    Spacer()
                                    Text(viewModel.formatAmount(
                                        row.convertedAmount,
                                        currency: viewModel.statsDisplayCurrency
                                    ))
                                    .monospacedDigit()
                                }
                                .font(.subheadline)
                                .padding(.vertical, 10)

                                if row.id != rows.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("趋势走向")
                                .font(.headline)
                            Spacer()
                            Picker("趋势周期", selection: $trendPeriod) {
                                ForEach(TrendPeriod.allCases) { period in
                                    Text(period.displayName).tag(period)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                        }

                        if trendRows.count >= 2 {
                            if #available(iOS 16.0, *) {
                                Chart(trendRows) { row in
                                    LineMark(
                                        x: .value("日期", row.periodStart),
                                        y: .value("金额", row.amount)
                                    )
                                    .interpolationMethod(.linear)
                                    .foregroundStyle(.secondary)

                                    PointMark(
                                        x: .value("日期", row.periodStart),
                                        y: .value("金额", row.amount)
                                    )
                                    .symbol(Circle())
                                    .symbolSize(70)
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
                        } else {
                            Text("该周期下至少需要两个数据点才能展示趋势")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

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
                .padding()
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let latestDay = rows.first?.day {
                    displayedMonth = latestDay
                    selectedDay = latestDay
                } else {
                    let todayInMarket = marketCalendar.startOfDay(for: Date())
                    displayedMonth = todayInMarket
                    selectedDay = todayInMarket
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            }
        }
    }
}
