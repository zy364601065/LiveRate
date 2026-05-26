import SwiftUI

struct LiveStockTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @FocusState private var isStockFieldFocused: Bool
    @State private var manualInputSymbol = ""

    private var stockTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }

    private func signedChangeColor(_ value: Double) -> Color {
        if value > 0 { return .red }
        if value < 0 { return .green }
        return .secondary
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("当前交易时段：\(viewModel.currentTradingSession.displayName)（美东 \(viewModel.usMarketTimeText)）", systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let notice = viewModel.sessionPriceNoticeMessage, !notice.isEmpty {
                        Text(notice)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if let quote = viewModel.liveStockQuote {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(quote.symbol)
                                    .font(.headline)
                                Text(String(format: "现价 %.2f | 昨收 %.2f", quote.price, quote.previousClose))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("按当前时间判定：\(viewModel.currentTradingSession.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("更新于 \(stockTimeFormatter.string(from: quote.updatedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%+.2f", quote.change))
                                    .font(.headline)
                                Text(String(format: "%+.2f%%", quote.changePercent))
                                    .font(.system(size: 30, weight: .bold))
                            }
                            .foregroundStyle(signedChangeColor(quote.change))
                            .monospacedDigit()
                        }
                    }

                    if let stockErrorMessage = viewModel.stockErrorMessage {
                        Text(stockErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("我的持仓实时数据（左滑可删除）") {
                    if viewModel.visibleHoldingLiveStockQuotes.isEmpty {
                        Text("暂无持仓实时数据，请先在持仓页补充股票代码并刷新")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.visibleHoldingLiveStockQuotes) { item in
                            holdingRealtimeRow(item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("删除", role: .destructive) {
                                        withAnimation {
                                            viewModel.hideRealtimeHoldingSymbol(item.symbol)
                                        }
                                    }
                                }
                        }
                    }

                    if let holdingStockErrorMessage = viewModel.holdingStockErrorMessage {
                        Text(holdingStockErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("自选股票（左滑可删除）") {
                    if viewModel.watchlistStockQuotes.isEmpty {
                        Text("手动输入股票并在键盘上提交后，会追加到这里")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.watchlistStockQuotes) { item in
                            watchlistRow(item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("删除", role: .destructive) {
                                        withAnimation {
                                            viewModel.removeWatchlistSymbol(item.symbol)
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("请输入股票代码（示例：AAPL）", text: $manualInputSymbol)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)
                        .focused($isStockFieldFocused)
                        .onSubmit {
                            submitManualSymbol()
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        await viewModel.refreshAllHoldingsQuotesOnly()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(viewModel.isLoading ? "刷新中..." : "刷新全部持仓")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .onTapGesture {
                isStockFieldFocused = false
            }
            .navigationTitle("实时")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func submitManualSymbol() {
        let symbol = manualInputSymbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !symbol.isEmpty else { return }
        manualInputSymbol = symbol
        isStockFieldFocused = false
        Task {
            await viewModel.refreshManualInputStockAndAppend(symbol)
        }
    }

    private func holdingRealtimeRow(_ item: HoldingLiveStockQuote) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.stockName)
                    .font(.subheadline.bold())
                Text(item.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "现价 %.2f | 昨收 %.2f", item.quote.price, item.quote.previousClose))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button("刷新") {
                    Task {
                        await viewModel.refreshSingleHoldingQuote(symbol: item.symbol)
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)

                Text(String(format: "%+.2f%%", item.quote.changePercent))
                    .font(.subheadline.bold())
                    .foregroundStyle(signedChangeColor(item.quote.change))
                    .monospacedDigit()
            }
        }
    }

    private func watchlistRow(_ item: WatchlistStockQuote) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.symbol)
                    .font(.headline)
                Text(String(format: "现价 %.2f | 昨收 %.2f", item.quote.price, item.quote.previousClose))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("添加于 \(stockTimeFormatter.string(from: item.addedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%+.2f", item.quote.change))
                    .font(.subheadline.bold())
                Text(String(format: "%+.2f%%", item.quote.changePercent))
                    .font(.subheadline.bold())
            }
            .foregroundStyle(signedChangeColor(item.quote.change))
            .monospacedDigit()
        }
    }
}
