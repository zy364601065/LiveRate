import SwiftUI

struct StatsRecordsListView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    let selectedDay: Date

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

    private var selectedDayEntries: [DayUploadEntry] {
        viewModel.uploadEntries(on: selectedDay, currency: viewModel.statsDisplayCurrency)
    }

    private var rows: [DailyAmountRow] {
        viewModel.dailyAmountRows(for: viewModel.statsDisplayCurrency)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
            }
            .padding()
        }
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
