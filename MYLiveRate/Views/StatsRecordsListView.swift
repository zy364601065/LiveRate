import SwiftUI

struct StatsRecordsListView: View {
    enum RecordTab: String, CaseIterable, Identifiable {
        case uploadRecords = "上传记录"
        case tableStats = "表格统计"
        var id: String { rawValue }
    }

    @ObservedObject var viewModel: ExchangeRateViewModel
    let selectedDay: Date
    @State private var currentDay: Date
    @State private var selectedTab: RecordTab = .uploadRecords

    init(viewModel: ExchangeRateViewModel, selectedDay: Date) {
        self.viewModel = viewModel
        self.selectedDay = selectedDay
        self._currentDay = State(initialValue: selectedDay)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = viewModel.marketCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var dateTitleFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = viewModel.marketCalendar.timeZone
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }

    private var selectedDayEntries: [DayUploadEntry] {
        viewModel.uploadEntries(on: currentDay, currency: viewModel.statsDisplayCurrency)
    }

    private var rows: [DailyAmountRow] {
        viewModel.dailyAmountRows(for: viewModel.statsDisplayCurrency)
    }

    private func signedAmountColor(_ value: Double) -> Color {
        if value > 0 { return Color(red: 0.93, green: 0.19, blue: 0.23) }
        if value < 0 { return Color(red: 0.12, green: 0.72, blue: 0.67) }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("查看模式", selection: $selectedTab) {
                ForEach(RecordTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == .uploadRecords {
                        uploadRecordsSection
                    } else {
                        tableStatsSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var uploadRecordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("按美东交易日统计（America/New_York）")
                .font(.caption)
                .foregroundStyle(.secondary)
                
            HStack {
                Button {
                    currentDay = viewModel.marketCalendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text(dateTitleFormatter.string(from: currentDay))
                    .font(.headline)
                
                Spacer()
                
                Button {
                    currentDay = viewModel.marketCalendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            Text("该日期上传金额")
                .font(.headline)
                .padding(.top, 4)

            if selectedDayEntries.isEmpty {
                Text("这一天还没有上传记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                ForEach(selectedDayEntries) { entry in
                    HStack {
                        Text(timeFormatter.string(from: entry.timestamp))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%+.2f %@", entry.convertedAmount, viewModel.statsDisplayCurrency.rawValue))
                            .font(.subheadline.bold())
                            .foregroundStyle(signedAmountColor(entry.convertedAmount))
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
    }

    private var tableStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            .foregroundStyle(signedAmountColor(row.convertedAmount))
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
        }
    }
}
