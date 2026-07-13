import SwiftUI

struct PortfolioPositionSummaryView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @AppStorage("myliverate.stats.hide_numbers") private var hideStatsNumbers = false

    private let positiveColor = Color(red: 0.93, green: 0.19, blue: 0.23)
    private let negativeColor = Color(red: 0.12, green: 0.72, blue: 0.67)
    private let accentBlue = Color(red: 0.95, green: 0.52, blue: 0.16)
    private let titleColor = Color(uiColor: .label)
    private let subtitleColor = Color(uiColor: .secondaryLabel)
    private let glassStrokeColor = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(white: 1, alpha: 0.62)
    })

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentBlue)
                    .frame(width: 32, height: 32)
                    .background(accentBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("总仓位")
                        .font(.headline.weight(.semibold))

                    if let quoteAt = viewModel.portfolioQuoteAt {
                        Text("更新于 \(timeFormatter.string(from: quoteAt))")
                            .font(.caption2)
                            .foregroundStyle(subtitleColor)
                    }
                }

                Spacer(minLength: 8)

                if viewModel.portfolioQuoteIsStale {
                    Text("可能延迟")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(subtitleColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(totalPositionAmountText)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(accentBlue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("盘中 / 收盘")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(subtitleColor)
                    Text(hideStatsNumbers ? "--%" : totalPositionPercentText)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(
                            hideStatsNumbers
                                ? subtitleColor
                                : signedAmountColor(totalTodayPnLPercent ?? 0, zeroColor: subtitleColor)
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("总仓位")
            .accessibilityValue(
                hideStatsNumbers
                    ? "资产数据已隐藏"
                    : "\(totalPositionAmountText)，盘中或收盘盈亏 \(totalPositionPercentText)"
            )

            Divider()
                .overlay(Color.primary.opacity(0.08))

            LazyVGrid(columns: sessionMetricColumns, alignment: .leading, spacing: 8) {
                portfolioSessionMetric(title: "盘后", session: .afterHours)
                portfolioSessionMetric(title: "夜盘", session: .overnight)
                portfolioSessionMetric(title: "盘前", session: .preMarket)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.50)
                    : UIColor(white: 1, alpha: 0.20)
            }),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(glassStrokeColor, lineWidth: 1)
        }
    }

    private var totalPositionUSD: Double? {
        let values = viewModel.holdingRecords.compactMap(\.marketValue)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private var totalTodayPnLUSD: Double? {
        let values = viewModel.holdingRecords.compactMap(\.todayPnL)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private var totalPositionValue: Double? {
        guard let totalPositionUSD else { return nil }
        return viewModel.convertedFromUSD(totalPositionUSD, to: viewModel.statsDisplayCurrency)
    }

    private var totalTodayPnLPercent: Double? {
        if let regularPercent = portfolioMetrics(for: .regular).percent {
            return regularPercent
        }

        guard let marketValue = totalPositionUSD,
              let todayPnL = totalTodayPnLUSD else {
            return nil
        }

        let previousCloseValue = marketValue - todayPnL
        guard previousCloseValue > 0 else { return nil }
        return todayPnL / previousCloseValue * 100
    }

    private var totalPositionAmountText: String {
        guard !hideStatsNumbers else { return "******" }
        guard let value = totalPositionValue else { return "--" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(viewModel.statsDisplayCurrency.symbol)\(number)"
    }

    private var totalPositionPercentText: String {
        guard !hideStatsNumbers else { return "--%" }
        guard let value = totalTodayPnLPercent else { return "--%" }
        return String(format: "(%+.2f%%)", value)
    }

    private var sessionMetricColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8, alignment: .leading), count: 3)
    }

    private func portfolioSessionMetric(title: String, session: TradingSessionType) -> some View {
        let metrics = portfolioMetrics(for: session)
        let amount = metrics.pnl.flatMap { viewModel.convertedFromUSD($0, to: viewModel.statsDisplayCurrency) }
        let valueColor = signedAmountColor(metrics.percent, zeroColor: .gray)

        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)

            Text(hideStatsNumbers ? "******" : amount.map { viewModel.formatAmount($0, currency: viewModel.statsDisplayCurrency) } ?? "--")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(hideStatsNumbers ? subtitleColor : valueColor)
                .lineLimit(1)

            Text(hideStatsNumbers ? "--%" : metrics.percent.map(percentText) ?? "--%")
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(hideStatsNumbers ? subtitleColor : valueColor.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)盈亏")
        .accessibilityValue(
            hideStatsNumbers
                ? "资产数据已隐藏"
                : amount.flatMap { amountValue in
                    metrics.percent.map {
                        "\(viewModel.formatAmount(amountValue, currency: viewModel.statsDisplayCurrency))，\(percentText($0))"
                    }
                } ?? "无数据"
        )
    }

    private func portfolioQuote(for record: HoldingRecord, session: TradingSessionType) -> PortfolioSessionQuote? {
        guard let symbol = record.stockCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !symbol.isEmpty,
              let sessions = viewModel.portfolioQuotesBySymbol[symbol] else {
            return nil
        }

        switch session {
        case .afterHours: return sessions.afterHours
        case .overnight: return sessions.overnight
        case .preMarket: return sessions.preMarket
        case .regular: return sessions.regular
        }
    }

    private func portfolioMetrics(for session: TradingSessionType) -> (pnl: Double?, percent: Double?) {
        var totalChange = 0.0
        var totalBaseline = 0.0
        var hasData = false

        for record in viewModel.holdingRecords {
            guard let quantity = record.quantity,
                  let quote = portfolioQuote(for: record, session: session),
                  quote.isAvailable,
                  let change = quote.changeAmount,
                  let baseline = quote.baselinePrice,
                  baseline > 0 else {
                continue
            }

            totalChange += change * quantity
            totalBaseline += baseline * quantity
            hasData = true
        }

        guard hasData, totalBaseline > 0 else { return (nil, nil) }
        return (totalChange, totalChange / totalBaseline * 100)
    }

    private func signedAmountColor(_ value: Double?, zeroColor: Color) -> Color {
        guard let value else { return zeroColor }
        if value > 0 { return positiveColor }
        if value < 0 { return negativeColor }
        return zeroColor
    }

    private func percentText(_ value: Double) -> String {
        String(format: "%+.2f%%", value)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
}
