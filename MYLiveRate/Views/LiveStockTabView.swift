import SwiftUI
import Charts

struct LiveStockTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @FocusState private var isStockFieldFocused: Bool
    @State private var selectedSessionFilter: TradingSessionFilter = .all

    private var marketCalendar: Calendar {
        var calendar = viewModel.marketCalendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        return calendar
    }

    private var stockTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = marketCalendar.timeZone
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("实时股票涨幅")
                            .font(.title2.bold())

                        TextField("请输入股票代码（示例：AAPL）", text: $viewModel.stockSymbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .focused($isStockFieldFocused)
                            .onSubmit {
                                Task {
                                    await viewModel.refreshStocksOnly()
                                }
                            }

                        if let quote = viewModel.liveStockQuote {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quote.symbol)
                                        .font(.headline)
                                    Text(String(format: "现价 %.2f | 昨收 %.2f", quote.price, quote.previousClose))
                                        .font(.footnote)
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
                                .foregroundStyle(quote.change >= 0 ? Color.red : Color.green)
                                .monospacedDigit()
                            }
                        } else {
                            Text("暂无股票行情，稍后会自动刷新")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let stockErrorMessage = viewModel.stockErrorMessage {
                            Text(stockErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("日内股价走势")
                                .font(.headline)
                            Spacer()
                            Picker("时段", selection: $selectedSessionFilter) {
                                ForEach(TradingSessionFilter.allCases) { filter in
                                    Text(filter.displayName).tag(filter)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        let filteredPoints = viewModel.intradayPoints(for: selectedSessionFilter)
                        if filteredPoints.count >= 2 {
                            if #available(iOS 16.0, *) {
                                Chart(filteredPoints) { point in
                                    LineMark(
                                        x: .value("时间", point.timestamp),
                                        y: .value("价格", point.close)
                                    )
                                    .interpolationMethod(.linear)
                                    .foregroundStyle(.blue)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisGridLine()
                                        AxisTick()
                                        AxisValueLabel {
                                            if let date = value.as(Date.self) {
                                                Text(stockTimeFormatter.string(from: date))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 220)
                            } else {
                                Text("当前系统版本不支持走势图")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("当前时段数据不足，无法绘制走势")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let intradayErrorMessage = viewModel.intradayErrorMessage {
                            Text(intradayErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("我的持仓实时数据")
                            .font(.headline)

                        if viewModel.holdingLiveStockQuotes.isEmpty {
                            Text("暂无持仓实时数据，请先在持仓页补充股票代码并刷新")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.holdingLiveStockQuotes) { item in
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
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(String(format: "%+.2f", item.quote.change))
                                            .font(.subheadline.bold())
                                        Text(String(format: "%+.2f%%", item.quote.changePercent))
                                            .font(.subheadline.bold())
                                    }
                                    .foregroundStyle(item.quote.change >= 0 ? Color.red : Color.green)
                                    .monospacedDigit()
                                }

                                if item.id != viewModel.holdingLiveStockQuotes.last?.id {
                                    Divider()
                                }
                            }
                        }

                        if let holdingStockErrorMessage = viewModel.holdingStockErrorMessage {
                            Text(holdingStockErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    Text("提示：可在设置页填写行情接口密钥。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isStockFieldFocused = false
            }
            .navigationTitle("实时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refreshStocksOnly()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(viewModel.isLoading ? "刷新中" : "刷新")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }
}
