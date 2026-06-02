import SwiftUI
import PhotosUI
import UIKit

struct HoldingsTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @Binding var selectedHoldingPhotoItem: PhotosPickerItem?
    @State private var editingHoldingID: UUID?
    @State private var draftName = ""
    @State private var draftCode = ""
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

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PhotosPicker(selection: $selectedHoldingPhotoItem, matching: .images) {
                        Label("上传持仓截图", systemImage: "chart.bar.doc.horizontal")
                            .font(.subheadline.weight(.semibold))
                    }

                    if viewModel.isRecognizingHolding {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在识别持仓数据...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let message = viewModel.holdingMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.holdingRecords.isEmpty {
                    Section {
                        Text("还没有持仓记录，先上传持仓截图吧")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("持仓列表（左滑可删除）") {
                        ForEach(viewModel.holdingRecords) { record in
                            holdingCard(record)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("删除", role: .destructive) {
                                        withAnimation {
                                            viewModel.removeHoldingRecord(id: record.id)
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(pageBackground.ignoresSafeArea())
            .navigationTitle("持仓明细")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [pageBackgroundTop, pageBackgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func holdingCard(_ record: HoldingRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if editingHoldingID == record.id {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("输入股票名称", text: $draftName)
                            .textFieldStyle(.roundedBorder)

                        TextField("输入股票代码（可选）", text: $draftCode)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        HStack(spacing: 10) {
                            Button("保存") {
                                viewModel.updateHoldingIdentity(
                                    id: record.id,
                                    newName: draftName,
                                    newCode: draftCode
                                )
                                editingHoldingID = nil
                                draftName = ""
                                draftCode = ""
                            }
                            .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .buttonStyle(.borderedProminent)

                            Button("取消") {
                                editingHoldingID = nil
                                draftName = ""
                                draftCode = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryName(record))
                            .font(.title3.bold())
                            .lineLimit(1)

                        if let code = secondaryCode(record) {
                            Text(code)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                if editingHoldingID != record.id {
                    VStack(alignment: .trailing, spacing: 6) {
                        Button("编辑") {
                            editingHoldingID = record.id
                            draftName = primaryName(record)
                            draftCode = secondaryCode(record) ?? ""
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)

                        Text(timeFormatter.string(from: record.timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                holdingMetric(
                    title: "市值 / 数量",
                    value: formattedPair(record.marketValue, record.quantity)
                )
                holdingMetric(
                    title: "现价 / 成本",
                    value: formattedPair(record.currentPrice, record.costPrice)
                )
            }

            HStack(spacing: 12) {
                holdingMetric(
                    title: "今日盈亏",
                    value: formattedSignedWithPercent(record.todayPnL, record.todayPnLPercent),
                    tint: signedColor(record.todayPnL)
                )
                holdingMetric(
                    title: "持仓盈亏",
                    value: formattedSignedWithPercent(record.holdingPnL, record.holdingPnLPercent),
                    tint: signedColor(record.holdingPnL)
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func holdingMetric(title: String, value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func formattedPair(_ left: Double?, _ right: Double?) -> String {
        "\(formattedNumber(left)) / \(formattedNumber(right))"
    }

    private func formattedSigned(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.2f", value)
    }

    private func formattedSignedWithPercent(_ value: Double?, _ percent: Double?) -> String {
        let amount = formattedSigned(value)
        guard let percent else { return amount }
        return amount + String(format: " (%.2f%%)", percent)
    }

    private func signedColor(_ value: Double?) -> Color {
        guard let value else { return .primary }
        if value > 0 { return Color(red: 0.93, green: 0.19, blue: 0.23) }
        if value < 0 { return Color(red: 0.12, green: 0.72, blue: 0.67) }
        return .primary
    }

    private func formattedNumber(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }

    private func primaryName(_ record: HoldingRecord) -> String {
        if record.stockName.contains("\n") {
            return record.stockName.components(separatedBy: "\n").first ?? record.stockName
        }
        return record.stockName
    }

    private func secondaryCode(_ record: HoldingRecord) -> String? {
        if let code = record.stockCode, !code.isEmpty {
            return code
        }

        if record.stockName.contains("\n") {
            let parts = record.stockName.components(separatedBy: "\n").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            if parts.count >= 2 {
                return parts[1]
            }
        }

        return nil
    }
}
