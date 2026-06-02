import SwiftUI
import UIKit

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
    private let titleColor = Color(uiColor: .label)
    private let subtitleColor = Color(uiColor: .secondaryLabel)
    private let accentColor = Color(red: 0.95, green: 0.52, blue: 0.16)
    private let positiveColor = Color(red: 0.93, green: 0.19, blue: 0.23)
    private let negativeColor = Color(red: 0.12, green: 0.72, blue: 0.67)
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
        if value > 0 { return positiveColor }
        if value < 0 { return negativeColor }
        return .secondary
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerSection
                    modePicker
                    if selectedTab == .uploadRecords {
                        uploadRecordsSection
                    } else {
                        tableStatsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("记录详情")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)
            Text("按美东交易日查看上传记录与日历统计")
                .font(.footnote.weight(.medium))
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modePicker: some View {
        Picker("查看模式", selection: $selectedTab) {
            ForEach(RecordTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .tint(accentColor)
    }

    private var uploadRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    currentDay = viewModel.marketCalendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(accentColor)

                VStack(alignment: .center, spacing: 3) {
                    Text(dateTitleFormatter.string(from: currentDay))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(titleColor)
                    Text("America/New_York")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                Button {
                    currentDay = viewModel.marketCalendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(accentColor)
            }

            HStack {
                Label("上传金额", systemImage: "tray.and.arrow.up.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor)
                Spacer()
                Text("\(selectedDayEntries.count) 条")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }

            if selectedDayEntries.isEmpty {
                emptyState("这一天还没有上传记录")
            } else {
                VStack(spacing: 8) {
                    ForEach(selectedDayEntries) { entry in
                        uploadEntryRow(entry)
                    }
                }
            }
        }
        .padding(14)
        .background(glassCardBackground(cornerRadius: 18))
    }

    private var tableStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("日历表格统计", systemImage: "tablecells.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(titleColor)
                Spacer()
                Text("\(rows.count) 天")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }

            if rows.isEmpty {
                emptyState("还没有上传记录，先去汇率页上传图片吧")
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        tableRow(row)
                    }
                }
            }
        }
        .padding(14)
        .background(glassCardBackground(cornerRadius: 18))
    }

    private func uploadEntryRow(_ entry: DayUploadEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 28, height: 28)
                .background(.thinMaterial, in: Circle())

            Text(timeFormatter.string(from: entry.timestamp))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(titleColor)

            Spacer(minLength: 10)

            Text(String(format: "%+.2f %@", entry.convertedAmount, viewModel.statsDisplayCurrency.rawValue))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(signedAmountColor(entry.convertedAmount))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(glassStrokeColor, lineWidth: 1)
        }
    }

    private func tableRow(_ row: DailyAmountRow) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dayFormatter.string(from: row.day))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(titleColor)
                Text("最后金额")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            Text(viewModel.formatAmount(
                row.convertedAmount,
                currency: viewModel.statsDisplayCurrency
            ))
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(signedAmountColor(row.convertedAmount))
            .lineLimit(1)
            .minimumScaleFactor(0.68)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(glassStrokeColor, lineWidth: 1)
        }
    }

    private func emptyState(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func glassCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(glassFillColor)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(glassStrokeColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [pageBackgroundTop, pageBackgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
