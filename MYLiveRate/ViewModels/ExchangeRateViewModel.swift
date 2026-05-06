import Foundation
import Combine
import UIKit

@MainActor
final class ExchangeRateViewModel: ObservableObject {
    @Published var amountText = "1"
    @Published var baseCurrency: Currency = .USD
    @Published var statsDisplayCurrency: Currency = .USD
    @Published var rates: [Currency: Double] = [:]
    @Published var lastUpdatedAt: Date?
    @Published var isLoading = false
    @Published var isRecognizingAmount = false
    @Published var errorMessage: String?
    @Published var ocrMessage: String?
    @Published var uploadRecords: [UploadRecord] = []
    @Published var latestUploadImageData: Data?
    @Published var latestUploadThumbnailData: Data?
    @Published var isRecognizingHolding = false
    @Published var holdingMessage: String?
    @Published var holdingRecords: [HoldingRecord] = []
    @Published var liveStockQuote: StockQuote?
    @Published var stockErrorMessage: String?
    @Published var intradayPricePoints: [IntradayPricePoint] = []
    @Published var intradayErrorMessage: String?
    @Published var holdingLiveStockQuotes: [HoldingLiveStockQuote] = []
    @Published var holdingStockErrorMessage: String?
    @Published var stockSymbol: String = "AAPL" {
        didSet {
            let normalized = stockSymbol
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if normalized != stockSymbol {
                stockSymbol = normalized
                return
            }
            persistStockSymbol()
        }
    }
    @Published var alphaVantageAPIKey: String = "demo" {
        didSet {
            persistAlphaVantageAPIKey()
        }
    }

    private let service = ExchangeRateService()
    private let alphaVantageService = AlphaVantageService()
    private let ocrService = DollarOCRService()
    private let holdingsOCRService = HoldingsOCRService()
    private let uploadRecordsStorageKey = "myliverate.upload_records.v1"
    private let latestThumbnailStorageKey = "myliverate.latest_upload_thumbnail.v1"
    private let holdingRecordsStorageKey = "myliverate.holding_records.v1"
    private let stockSymbolStorageKey = "myliverate.stock_symbol.v1"
    private let alphaVantageAPIKeyStorageKey = "myliverate.alphavantage_api_key.v1"
    private static let usMarketTimeZone = TimeZone(identifier: "America/New_York") ?? .current

    init() {
        uploadRecords = loadPersistedUploadRecords()
        latestUploadThumbnailData = UserDefaults.standard.data(forKey: latestThumbnailStorageKey)
        holdingRecords = loadPersistedHoldingRecords()
        stockSymbol = loadPersistedStockSymbol()
        alphaVantageAPIKey = loadPersistedAlphaVantageAPIKey()
    }

    var targetCurrencies: [Currency] {
        Currency.allCases.filter { $0 != baseCurrency }
    }

    var marketCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.usMarketTimeZone
        return calendar
    }

    var dailyLatestRecords: [DailyLatestRecord] {
        let calendar = marketCalendar
        let grouped = Dictionary(grouping: uploadRecords) { record in
            calendar.startOfDay(for: record.timestamp)
        }

        return grouped.compactMap { day, records in
            guard let latest = records.max(by: { $0.timestamp < $1.timestamp }) else {
                return nil
            }
            return DailyLatestRecord(day: day, record: latest)
        }
        .sorted { $0.day < $1.day }
    }

    func updateBaseCurrency(_ currency: Currency) {
        baseCurrency = currency
    }

    func refresh(includeStocks: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await service.fetch(base: baseCurrency)
            rates = snapshot.rates
            lastUpdatedAt = snapshot.updatedAt
        } catch {
            errorMessage = "汇率更新失败，请稍后重试"
        }

        if includeStocks {
            await performStockRefresh()
        }
        isLoading = false
    }

    func refreshStocksOnly() async {
        guard !isLoading else { return }
        isLoading = true
        await performStockRefresh()
        isLoading = false
    }

    func updateStockSymbol(_ symbol: String) {
        stockSymbol = symbol
    }

    func updateAlphaVantageAPIKey(_ key: String) {
        alphaVantageAPIKey = key
    }

    func recognizeUSDAmount(from imageData: Data) async {
        setLatestUploadImage(from: imageData)
        isRecognizingAmount = true
        ocrMessage = nil

        defer {
            isRecognizingAmount = false
        }

        do {
            guard let amount = try await ocrService.extractDollarAmount(from: imageData) else {
                ocrMessage = "没有识别到美元金额，请换一张更清晰的图片"
                return
            }

            amountText = formattedAmountText(amount)
            updateBaseCurrency(.USD)
            addUploadRecord(UploadRecord(timestamp: Date(), usdAmount: amount))
            ocrMessage = "已识别美元金额：\(amountText)"
            await refresh()
        } catch {
            ocrMessage = "识别失败，请稍后重试"
        }
    }

    func recognizeHolding(from imageData: Data) async {
        isRecognizingHolding = true
        holdingMessage = nil

        defer {
            isRecognizingHolding = false
        }

        do {
            let holdings = try await holdingsOCRService.extractHoldings(from: imageData)
            guard !holdings.isEmpty else {
                holdingMessage = "没有识别到持仓信息，请换一张更清晰的持仓截图"
                return
            }

            addHoldingRecords(holdings)
            holdingMessage = "已识别持仓 \(holdings.count) 条"
        } catch {
            holdingMessage = "识别持仓失败，请稍后重试"
        }
    }

    func convertedAmount(for target: Currency) -> Double? {
        guard let amount = parseAmountText(amountText),
              let rate = rates[target] else {
            return nil
        }

        return amount * rate
    }

    func convertedFromUSD(_ usdAmount: Double, to target: Currency) -> Double? {
        if target == .USD {
            return usdAmount
        }

        guard let usdToTarget = usdToTargetRate(target: target) else {
            return nil
        }

        return usdAmount * usdToTarget
    }

    func dailyAmountRows(for currency: Currency) -> [DailyAmountRow] {
        dailyLatestRecords.compactMap { item in
            guard let converted = convertedFromUSD(item.record.usdAmount, to: currency) else {
                return nil
            }

            return DailyAmountRow(
                day: item.day,
                convertedAmount: converted,
                sourceTime: item.record.timestamp,
                currency: currency
            )
        }
        .sorted { $0.day > $1.day }
    }

    func dailyTotalAmount(for currency: Currency) -> Double? {
        let values = dailyLatestRecords.compactMap { convertedFromUSD($0.record.usdAmount, to: currency) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    func uploadEntries(on day: Date, currency: Currency) -> [DayUploadEntry] {
        let calendar = marketCalendar

        return uploadRecords
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .sorted { $0.timestamp > $1.timestamp }
            .compactMap { record in
                guard let converted = convertedFromUSD(record.usdAmount, to: currency) else {
                    return nil
                }

                return DayUploadEntry(
                    id: record.id,
                    timestamp: record.timestamp,
                    convertedAmount: converted,
                    currency: currency
                )
            }
    }

    func trendRows(for currency: Currency, period: TrendPeriod) -> [TrendDataPoint] {
        let calendar = marketCalendar
        let grouped = Dictionary(grouping: dailyLatestRecords) { item in
            period.startDate(for: item.day, calendar: calendar)
        }

        return grouped.compactMap { periodStart, records in
            guard let latest = records.max(by: { $0.record.timestamp < $1.record.timestamp }),
                  let converted = convertedFromUSD(latest.record.usdAmount, to: currency) else {
                return nil
            }

            return TrendDataPoint(periodStart: periodStart, amount: converted)
        }
        .sorted { $0.periodStart < $1.periodStart }
    }

    func rateText(for target: Currency) -> String {
        guard let rate = rates[target] else {
            return "--"
        }

        return String(format: "1 %@ = %.4f %@", baseCurrency.rawValue, rate, target.rawValue)
    }

    func formatAmount(_ value: Double?, currency: Currency, fractionDigits: Int = 2) -> String {
        guard let value else { return "--" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%0.2f", value)
        return "\(number) \(currency.rawValue)"
    }

    private func usdToTargetRate(target: Currency) -> Double? {
        if baseCurrency == .USD {
            return rates[target]
        }

        guard let baseToTarget = rates[target],
              let baseToUSD = rates[.USD],
              baseToUSD != 0 else {
            return nil
        }

        return baseToTarget / baseToUSD
    }

    private func formattedAmountText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func parseAmountText(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
        return Double(normalized)
    }

    private func addUploadRecord(_ record: UploadRecord) {
        uploadRecords.append(record)
        uploadRecords.sort { $0.timestamp < $1.timestamp }
        persistUploadRecords()
    }

    private func setLatestUploadImage(from data: Data) {
        latestUploadImageData = data

        guard let thumbnailData = makeThumbnailData(from: data, size: CGSize(width: 100, height: 100)) else {
            return
        }

        latestUploadThumbnailData = thumbnailData
        UserDefaults.standard.set(thumbnailData, forKey: latestThumbnailStorageKey)
    }

    private func makeThumbnailData(from data: Data, size: CGSize) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail.jpegData(compressionQuality: 0.82)
    }

    private func persistUploadRecords() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(uploadRecords) else { return }
        UserDefaults.standard.set(data, forKey: uploadRecordsStorageKey)
    }

    private func loadPersistedUploadRecords() -> [UploadRecord] {
        guard let data = UserDefaults.standard.data(forKey: uploadRecordsStorageKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let records = try? decoder.decode([UploadRecord].self, from: data) else {
            return []
        }

        return records.sorted { $0.timestamp < $1.timestamp }
    }

    private func addHoldingRecords(_ records: [HoldingRecord]) {
        var mergedByKey: [String: HoldingRecord] = [:]

        for record in holdingRecords {
            mergedByKey[holdingKey(for: record)] = record
        }

        for record in records {
            // 新识别到的同名股票会覆盖旧记录，达到“只保留最新一条”的效果
            mergedByKey[holdingKey(for: record)] = record
        }

        holdingRecords = Array(mergedByKey.values).sorted { $0.timestamp > $1.timestamp }
        persistHoldingRecords()
    }

    func removeHoldingRecord(id: UUID) {
        holdingRecords.removeAll { $0.id == id }
        persistHoldingRecords()
    }

    func updateHoldingName(id: UUID, newName: String) {
        updateHoldingIdentity(id: id, newName: newName, newCode: nil)
    }

    func updateHoldingIdentity(id: UUID, newName: String, newCode: String?) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        guard let index = holdingRecords.firstIndex(where: { $0.id == id }) else { return }
        let old = holdingRecords[index]
        let trimmedCode = newCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCode = (trimmedCode?.isEmpty == true) ? nil : trimmedCode

        holdingRecords[index] = HoldingRecord(
            id: old.id,
            timestamp: old.timestamp,
            stockName: trimmedName,
            stockCode: normalizedCode,
            marketValue: old.marketValue,
            quantity: old.quantity,
            currentPrice: old.currentPrice,
            costPrice: old.costPrice,
            todayPnL: old.todayPnL,
            todayPnLPercent: old.todayPnLPercent,
            holdingPnL: old.holdingPnL,
            holdingPnLPercent: old.holdingPnLPercent
        )
        holdingRecords.sort { $0.timestamp > $1.timestamp }
        persistHoldingRecords()
    }

    private func holdingKey(for record: HoldingRecord) -> String {
        let source: String
        if let code = record.stockCode, !code.isEmpty {
            source = code
        } else {
            source = record.stockName
        }
        return source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }

    private func persistHoldingRecords() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(holdingRecords) else { return }
        UserDefaults.standard.set(data, forKey: holdingRecordsStorageKey)
    }

    private func loadPersistedHoldingRecords() -> [HoldingRecord] {
        guard let data = UserDefaults.standard.data(forKey: holdingRecordsStorageKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let records = try? decoder.decode([HoldingRecord].self, from: data) else {
            return []
        }

        return records.sorted { $0.timestamp > $1.timestamp }
    }

    private func refreshStockQuote() async {
        do {
            let quote = try await alphaVantageService.fetchQuote(
                symbol: stockSymbol,
                apiKey: alphaVantageAPIKey
            )
            liveStockQuote = quote
            stockErrorMessage = nil
        } catch {
            stockErrorMessage = (error as? LocalizedError)?.errorDescription ?? "股票行情更新失败，请稍后重试"
        }
    }

    private func performStockRefresh() async {
        await refreshStockQuote()
        await refreshIntradayPriceSeries()
        await refreshHoldingStockQuotes()
    }

    private func refreshIntradayPriceSeries() async {
        do {
            let points = try await alphaVantageService.fetchIntradaySeries(
                symbol: stockSymbol,
                apiKey: alphaVantageAPIKey
            )
            intradayPricePoints = points
            intradayErrorMessage = nil
        } catch {
            intradayPricePoints = []
            intradayErrorMessage = (error as? LocalizedError)?.errorDescription ?? "日内走势更新失败，请稍后重试"
        }
    }

    func intradayPoints(for filter: TradingSessionFilter) -> [IntradayPricePoint] {
        switch filter {
        case .all:
            return intradayPricePoints
        case .overnight:
            return intradayPricePoints.filter { $0.session == .overnight }
        case .preMarket:
            return intradayPricePoints.filter { $0.session == .preMarket }
        case .regular:
            return intradayPricePoints.filter { $0.session == .regular }
        case .afterHours:
            return intradayPricePoints.filter { $0.session == .afterHours }
        }
    }

    private func refreshHoldingStockQuotes() async {
        let targets = uniqueHoldingTargets()
        guard !targets.isEmpty else {
            holdingLiveStockQuotes = []
            holdingStockErrorMessage = "持仓中暂无可查询的股票代码"
            return
        }

        var fetchedItems: [HoldingLiveStockQuote] = []
        var failedCount = 0
        var errorCountByMessage: [String: Int] = [:]

        for target in targets {
            do {
                let quote = try await alphaVantageService.fetchQuote(
                    symbol: target.symbol,
                    apiKey: alphaVantageAPIKey
                )
                fetchedItems.append(
                    HoldingLiveStockQuote(
                        stockName: target.name,
                        symbol: target.symbol,
                        quote: quote
                    )
                )
            } catch {
                failedCount += 1
                let message = (error as? LocalizedError)?.errorDescription ?? "未知错误"
                errorCountByMessage[message, default: 0] += 1
            }
        }

        holdingLiveStockQuotes = fetchedItems.sorted { $0.symbol < $1.symbol }
        let dominantErrorMessage = errorCountByMessage.max(by: { $0.value < $1.value })?.key

        if fetchedItems.isEmpty {
            if let dominantErrorMessage {
                holdingStockErrorMessage = dominantErrorMessage
            } else {
                holdingStockErrorMessage = "持仓股票行情更新失败，请稍后重试"
            }
        } else if failedCount > 0 {
            if let dominantErrorMessage {
                holdingStockErrorMessage = dominantErrorMessage
            } else {
                holdingStockErrorMessage = "部分持仓股票更新失败，请检查股票代码"
            }
        } else {
            holdingStockErrorMessage = nil
        }
    }

    private func uniqueHoldingTargets() -> [(name: String, symbol: String)] {
        var seenSymbols = Set<String>()
        var targets: [(name: String, symbol: String)] = []

        for record in holdingRecords {
            guard let code = record.stockCode?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased(),
                  !code.isEmpty else {
                continue
            }
            if seenSymbols.contains(code) {
                continue
            }
            seenSymbols.insert(code)
            targets.append((name: record.stockName, symbol: code))
        }

        return targets
    }

    private func persistStockSymbol() {
        UserDefaults.standard.set(stockSymbol, forKey: stockSymbolStorageKey)
    }

    private func loadPersistedStockSymbol() -> String {
        let stored = UserDefaults.standard.string(forKey: stockSymbolStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return (stored?.isEmpty == false) ? stored! : "AAPL"
    }

    private func persistAlphaVantageAPIKey() {
        UserDefaults.standard.set(alphaVantageAPIKey, forKey: alphaVantageAPIKeyStorageKey)
    }

    private func loadPersistedAlphaVantageAPIKey() -> String {
        let stored = UserDefaults.standard.string(forKey: alphaVantageAPIKeyStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (stored?.isEmpty == false) ? stored! : "demo"
    }
}
