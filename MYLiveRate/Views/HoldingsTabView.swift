import SwiftUI
import PhotosUI
import UIKit

struct HoldingsTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @Binding var selectedHoldingPhotoItem: PhotosPickerItem?
    @State private var editingHoldingID: UUID?
    @State private var draftName = ""
    @State private var draftCode = ""
    @State private var analysisRecord: HoldingRecord?
    @State private var isShowingCalculator = false
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    toolsSection
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    PortfolioPositionSummaryView(viewModel: viewModel)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if viewModel.holdingRecords.isEmpty {
                    Section {
                        holdingsEmptyState
                            .listRowInsets(EdgeInsets(top: 22, leading: 16, bottom: 22, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
            .navigationDestination(isPresented: $isShowingCalculator) {
                LeveragedTargetPriceCalculatorView(viewModel: viewModel)
            }
        }
        .sheet(item: $analysisRecord) { record in
            StockAnalysisView(record: record)
        }
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [pageBackgroundTop, pageBackgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("常用工具")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("快捷入口")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 10) {
                Button {
                    isShowingCalculator = true
                } label: {
                    leveragedCalculatorEntry
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                uploadEntry
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
    }

    private var leveragedCalculatorEntry: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.orange.opacity(0.16))
                    Image(systemName: "function")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.orange)
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                Spacer(minLength: 4)

                Text("2×")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("目标价换算")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("估算 2 倍做多价格")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.orange.opacity(0.065)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.orange.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("目标价换算")
        .accessibilityHint("进入二级页面，估算正股目标价对应的 2 倍做多价格")
    }

    private var uploadEntry: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                Spacer(minLength: 4)

                PhotosPicker(selection: $selectedHoldingPhotoItem, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.blue, in: Circle())
                }
                .disabled(viewModel.isRecognizingHolding)
                .accessibilityLabel("选择持仓截图")
                .accessibilityHint("从照片中选择券商持仓截图并自动识别")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("上传持仓截图")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(viewModel.isRecognizingHolding ? "正在识别..." : "自动识别持仓数据")
                    .font(.caption2)
                    .foregroundStyle(viewModel.isRecognizingHolding ? .blue : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !viewModel.isRecognizingHolding, let message = viewModel.holdingMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.blue.opacity(0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.blue.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var holdingsEmptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 78, height: 78)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .frame(width: 54, height: 60)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 5)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            VStack(spacing: 9) {
                Text("还没有持仓记录")
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("上传截图后，识别结果会显示在下面。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                emptyStateFeature(
                    icon: "text.viewfinder",
                    title: "自动识别",
                    description: "支持一张截图导入多条持仓"
                )
                emptyStateFeature(
                    icon: "lock.shield",
                    title: "本机处理",
                    description: "图片仅用于提取持仓数据"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func emptyStateFeature(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func holdingCard(_ record: HoldingRecord) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 14) {
                Text(stockInitial(record))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(avatarColor, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryName(record))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let code = secondaryCode(record) {
                        Text(code)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Menu {
                    Button {
                        analysisRecord = record
                    } label: {
                        Label("AI 分析", systemImage: "sparkles")
                    }
                    .disabled(secondaryCode(record) == nil)

                    Button {
                        editingHoldingID = record.id
                        draftName = primaryName(record)
                        draftCode = secondaryCode(record) ?? ""
                    } label: {
                        Label("编辑名称与代码", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.removeHoldingRecord(id: record.id)
                        }
                    } label: {
                        Label("删除持仓", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("更多持仓操作")
            }

            if editingHoldingID == record.id {
                holdingEditor(record)
            } else {
                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 26) {
                    holdingMetric(
                        title: "市值 / 数量",
                        primary: formattedNumber(record.marketValue, minimumFractionDigits: 2, maximumFractionDigits: 2),
                        secondary: formattedNumber(record.quantity, minimumFractionDigits: 0, maximumFractionDigits: 4)
                    )
                    holdingMetric(
                        title: "今日盈亏",
                        primary: formattedSigned(sessionPnL(record, session: .regular) ?? record.todayPnL),
                        secondary: formattedPercent(sessionPercent(record, session: .regular) ?? record.todayPnLPercent),
                        tint: signedColor(sessionPnL(record, session: .regular) ?? record.todayPnL),
                        isSemanticValue: true
                    )

                    holdingMetric(
                        title: "现价 / 成本",
                        primary: formattedNumber(record.currentPrice, minimumFractionDigits: 3, maximumFractionDigits: 4),
                        secondary: formattedNumber(record.costPrice, minimumFractionDigits: 4, maximumFractionDigits: 4)
                    )
                    holdingMetric(
                        title: "持仓盈亏",
                        primary: formattedSigned(record.holdingPnL),
                        secondary: formattedPercent(record.holdingPnLPercent),
                        tint: signedColor(record.holdingPnL),
                        isSemanticValue: true
                    )
                    sessionMetric(record, title: "盘后盈亏", session: .afterHours)
                    sessionMetric(record, title: "夜盘盈亏", session: nil)
                    sessionMetric(record, title: "盘前盈亏", session: .preMarket)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.055), radius: 14, y: 5)
    }

    private func sessionMetric(_ record: HoldingRecord, title: String, session: PortfolioMarketSession?) -> some View {
        let pnl = session.flatMap { sessionPnL(record, session: $0) }
        let percent = session.flatMap { sessionPercent(record, session: $0) }
        return holdingMetric(
            title: title,
            primary: formattedSigned(pnl),
            secondary: formattedPercent(percent),
            tint: signedColor(pnl),
            isSemanticValue: true
        )
    }

    private func sessionQuote(_ record: HoldingRecord, session: PortfolioMarketSession) -> PortfolioSessionQuote? {
        guard let symbol = secondaryCode(record)?.uppercased(),
              let sessions = viewModel.portfolioQuotesBySymbol[symbol] else { return nil }
        switch session { case .preMarket: return sessions.preMarket; case .regular: return sessions.regular; case .afterHours: return sessions.afterHours; case .closed: return nil }
    }

    private func sessionPnL(_ record: HoldingRecord, session: PortfolioMarketSession) -> Double? {
        guard let quantity = record.quantity, let change = sessionQuote(record, session: session)?.changeAmount else { return nil }
        return quantity * change
    }

    private func sessionPercent(_ record: HoldingRecord, session: PortfolioMarketSession) -> Double? {
        sessionQuote(record, session: session)?.changePercent
    }

    private var avatarColor: Color {
        Color(red: 0.10, green: 0.13, blue: 0.21)
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 110), spacing: 22, alignment: .leading),
            GridItem(.flexible(minimum: 110), spacing: 22, alignment: .leading)
        ]
    }

    private func holdingMetric(
        title: String,
        primary: String,
        secondary: String,
        tint: Color = .primary,
        isSemanticValue: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(primary)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)

                Text("/ \(secondary)")
                    .font(.body)
                    .foregroundStyle(isSemanticValue ? tint.opacity(0.82) : Color.secondary)
            }
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)，\(primary)，\(secondary)")
    }

    private func holdingEditor(_ record: HoldingRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("输入股票名称", text: $draftName)
                .textFieldStyle(.roundedBorder)

            TextField("输入股票代码（可选）", text: $draftCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            HStack(spacing: 10) {
                Button("保存") {
                    viewModel.updateHoldingIdentity(id: record.id, newName: draftName, newCode: draftCode)
                    finishEditing()
                }
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)

                Button("取消") {
                    finishEditing()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func finishEditing() {
        editingHoldingID = nil
        draftName = ""
        draftCode = ""
    }

    private func formattedSigned(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.2f", value)
    }

    private func formattedPercent(_ value: Double?) -> String {
        guard let value else { return "--%" }
        return String(format: "%+.2f%%", value)
    }

    private func signedColor(_ value: Double?) -> Color {
        guard let value else { return .primary }
        if value > 0 { return Color(red: 0.93, green: 0.19, blue: 0.23) }
        if value < 0 { return Color(red: 0.12, green: 0.72, blue: 0.67) }
        return .primary
    }

    private func formattedNumber(
        _ value: Double?,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int
    ) -> String {
        guard let value else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "--"
    }

    private func stockInitial(_ record: HoldingRecord) -> String {
        guard let character = primaryName(record).trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "—"
        }
        return String(character).uppercased()
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
