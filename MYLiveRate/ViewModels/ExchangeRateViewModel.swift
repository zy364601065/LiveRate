import Foundation
import Combine
import UIKit

@MainActor
final class ExchangeRateViewModel: ObservableObject {
    @Published var amountText = "1" {
        didSet {
            persistAmountText()
        }
    }
    @Published var baseCurrency: Currency = .USD
    @Published var statsDisplayCurrency: Currency = .USD
    @Published var rates: [Currency: Double] = [:]
    @Published var allRates: [String: Double] = [:]
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
    @Published var liveStockQuote: StockQuote? {
        didSet { persistLiveStockQuote() }
    }
    @Published var stockErrorMessage: String?
    @Published var intradayPricePoints: [IntradayPricePoint] = []
    @Published var intradayErrorMessage: String?
    @Published var holdingLiveStockQuotes: [HoldingLiveStockQuote] = [] {
        didSet { persistHoldingLiveStockQuotes() }
    }
    @Published var holdingStockErrorMessage: String?
    @Published var watchlistStockQuotes: [WatchlistStockQuote] = [] {
        didSet { persistWatchlistStockQuotes() }
    }
    @Published var hiddenRealtimeHoldingSymbols: Set<String> = [] {
        didSet { persistHiddenRealtimeHoldingSymbols() }
    }
    @Published var currentTradingSession: TradingSessionType = .overnight
    @Published var usMarketTimeText: String = "--:--"
    @Published var sessionPriceNoticeMessage: String?
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
    @Published var finnhubAPIKey: String = "d7tvh11r01qvtspvv84gd7tvh11r01qvtspvv850" {
        didSet {
            persistFinnhubAPIKey()
        }
    }

    private let networkService = NetworkService()
    private let ocrService = DollarOCRService()
    private let holdingsOCRService = HoldingsOCRService()
    private let uploadRecordsStorageKey = "myliverate.upload_records.v1"
    private let amountTextStorageKey = "myliverate.amount_text.v1"
    private let latestThumbnailStorageKey = "myliverate.latest_upload_thumbnail.v1"
    private let holdingRecordsStorageKey = "myliverate.holding_records.v1"
    private let stockSymbolStorageKey = "myliverate.stock_symbol.v1"
    private let finnhubAPIKeyStorageKey = "myliverate.finnhub_api_key.v1"
    private let liveStockQuoteStorageKey = "myliverate.realtime.live_quote.v1"
    private let holdingLiveQuotesStorageKey = "myliverate.realtime.holding_quotes.v1"
    private let watchlistQuotesStorageKey = "myliverate.realtime.watchlist_quotes.v1"
    private let hiddenRealtimeSymbolsStorageKey = "myliverate.realtime.hidden_symbols.v1"
    private static let usMarketTimeZone = TimeZone(identifier: "America/New_York") ?? .current

    init() {
        amountText = loadPersistedAmountText()
        uploadRecords = loadPersistedUploadRecords()
        latestUploadThumbnailData = UserDefaults.standard.data(forKey: latestThumbnailStorageKey)
        holdingRecords = loadPersistedHoldingRecords()
        stockSymbol = loadPersistedStockSymbol()
        finnhubAPIKey = loadPersistedFinnhubAPIKey()
        liveStockQuote = loadPersistedLiveStockQuote()
        holdingLiveStockQuotes = loadPersistedHoldingLiveStockQuotes()
        watchlistStockQuotes = loadPersistedWatchlistStockQuotes()
        hiddenRealtimeHoldingSymbols = loadPersistedHiddenRealtimeHoldingSymbols()
        updateCurrentTradingSession()
        syncHoldingLiveQuotesWithPlaceholders()
    }

    var targetCurrencies: [Currency] {
        Currency.displayOrder.filter { $0 != baseCurrency }
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
            let snapshot = try await networkService.fetch(base: baseCurrency)
            rates = snapshot.rates
            allRates = snapshot.allRates
            lastUpdatedAt = snapshot.updatedAt
        } catch {
            errorMessage = "汇率更新失败，请稍后重试"
        }

        if includeStocks {
            await performStockRefresh()
        }
        isLoading = false
    }

    func refreshAllHoldingsQuotesOnly() async {
        guard !isLoading else { return }
        updateCurrentTradingSession()
        isLoading = true
        await refreshHoldingStockQuotes()
        isLoading = false
    }

    func refreshManualInputStockAndAppend(_ rawSymbol: String) async {
        let symbol = normalizedSymbol(rawSymbol)
        guard !symbol.isEmpty else {
            stockErrorMessage = "请输入有效股票代码"
            return
        }

        guard !isLoading else { return }
        updateCurrentTradingSession()
        isLoading = true

        do {
            let quote = try await networkService.fetchQuote(
                symbol: symbol,
                apiKey: finnhubAPIKey
            )
            sessionPriceNoticeMessage = nil
            let sessionAdjustedQuote = await adjustedQuoteForCurrentSession(
                symbol: symbol,
                baseQuote: quote,
                updateNotice: true
            )
            stockSymbol = symbol
            liveStockQuote = sessionAdjustedQuote
            stockErrorMessage = nil
            appendWatchlistQuote(sessionAdjustedQuote)
        } catch {
            stockErrorMessage = (error as? LocalizedError)?.errorDescription ?? "股票行情更新失败，请稍后重试"
        }

        isLoading = false
    }

    func refreshSingleHoldingQuote(symbol: String) async {
        let normalized = normalizedSymbol(symbol)
        guard !normalized.isEmpty else { return }
        updateCurrentTradingSession()

        do {
            let quote = try await networkService.fetchQuote(
                symbol: normalized,
                apiKey: finnhubAPIKey
            )
            sessionPriceNoticeMessage = nil
            let sessionAdjustedQuote = await adjustedQuoteForCurrentSession(
                symbol: normalized,
                baseQuote: quote,
                updateNotice: true
            )
            let fallbackName = holdingRecords.first(where: { normalizedSymbol($0.stockCode ?? "") == normalized })?.stockName ?? normalized
            if let index = holdingLiveStockQuotes.firstIndex(where: { $0.symbol == normalized }) {
                let old = holdingLiveStockQuotes[index]
                holdingLiveStockQuotes[index] = HoldingLiveStockQuote(
                    stockName: old.stockName,
                    symbol: normalized,
                    quote: sessionAdjustedQuote
                )
            } else {
                holdingLiveStockQuotes.append(
                    HoldingLiveStockQuote(
                        stockName: fallbackName,
                        symbol: normalized,
                        quote: sessionAdjustedQuote
                    )
                )
                holdingLiveStockQuotes.sort { $0.symbol < $1.symbol }
            }
            applyRealtimeQuoteToHoldingRecords(symbol: normalized, quote: sessionAdjustedQuote)
            holdingStockErrorMessage = nil
        } catch {
            holdingStockErrorMessage = (error as? LocalizedError)?.errorDescription ?? "持仓股票行情更新失败，请稍后重试"
        }
    }

    func removeWatchlistSymbol(_ symbol: String) {
        let normalized = normalizedSymbol(symbol)
        watchlistStockQuotes.removeAll { $0.symbol == normalized }
    }

    func hideRealtimeHoldingSymbol(_ symbol: String) {
        let normalized = normalizedSymbol(symbol)
        guard !normalized.isEmpty else { return }
        hiddenRealtimeHoldingSymbols.insert(normalized)
        holdingLiveStockQuotes.removeAll { $0.symbol == normalized }
    }

    var visibleHoldingLiveStockQuotes: [HoldingLiveStockQuote] {
        holdingLiveStockQuotes.filter { !hiddenRealtimeHoldingSymbols.contains($0.symbol) }
    }

    func updateStockSymbol(_ symbol: String) {
        stockSymbol = symbol
    }

    func updateFinnhubAPIKey(_ key: String) {
        finnhubAPIKey = key
    }

    func validateFinnhubTokenWithDefaultSymbol() async -> String? {
        let key = finnhubAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return "接口密钥不能为空"
        }

        guard !isLoading else {
            return "正在刷新，请稍后再试"
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await networkService.fetchQuote(symbol: "AAPL", apiKey: key)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? "接口校验失败，请稍后重试"
        }
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
            let amounts = records.compactMap { convertedFromUSD($0.record.usdAmount, to: currency) }
            guard !amounts.isEmpty else { return nil }
            let total = amounts.reduce(0, +)
            return TrendDataPoint(periodStart: periodStart, amount: total)
        }
        .sorted { $0.periodStart < $1.periodStart }
    }

    func rateText(for target: Currency) -> String {
        guard let rate = rates[target] else {
            return "--"
        }

        return String(format: "1 %@ = %.4f %@", baseCurrency.rawValue, rate, target.rawValue)
    }

    func rateText(for code: String) -> String {
        guard let rate = allRates[code] else {
            return "--"
        }

        return String(format: "1 %@ = %.4f %@", baseCurrency.rawValue, rate, code)
    }

    func convertedAmount(for code: String) -> Double? {
        guard let amount = parseAmountText(amountText),
              let rate = allRates[code] else {
            return nil
        }

        return amount * rate
    }

    var sortedAllRateRows: [(code: String, rate: Double)] {
        allRates
            .map { (code: $0.key, rate: $0.value) }
            .sorted { lhs, rhs in
                if lhs.code == rhs.code {
                    return lhs.rate < rhs.rate
                }
                return lhs.code < rhs.code
            }
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

    func formatAmount(_ value: Double?, code: String, fractionDigits: Int = 2) -> String {
        guard let value else { return "--" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%0.2f", value)
        return "\(number) \(code)"
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

    private func persistAmountText() {
        UserDefaults.standard.set(amountText, forKey: amountTextStorageKey)
    }

    private func loadPersistedAmountText() -> String {
        let stored = UserDefaults.standard.string(forKey: amountTextStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty {
            return stored
        }
        return "1"
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
        syncHoldingLiveQuotesWithPlaceholders()
    }

    func removeHoldingRecord(id: UUID) {
        holdingRecords.removeAll { $0.id == id }
        persistHoldingRecords()
        syncHoldingLiveQuotesWithPlaceholders()
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
        syncHoldingLiveQuotesWithPlaceholders()
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
            let quote = try await networkService.fetchQuote(
                symbol: stockSymbol,
                apiKey: finnhubAPIKey
            )
            sessionPriceNoticeMessage = nil
            liveStockQuote = await adjustedQuoteForCurrentSession(
                symbol: stockSymbol,
                baseQuote: quote,
                updateNotice: true
            )
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

    private func appendWatchlistQuote(_ quote: StockQuote) {
        watchlistStockQuotes.removeAll { $0.symbol == quote.symbol }
        watchlistStockQuotes.append(
            WatchlistStockQuote(
                symbol: quote.symbol,
                quote: quote,
                addedAt: Date()
            )
        )
    }

    private func refreshIntradayPriceSeries() async {
        do {
            let points = try await networkService.fetchIntradaySeries(
                symbol: stockSymbol,
                apiKey: finnhubAPIKey
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
        var fetchedQuotesBySymbol: [String: StockQuote] = [:]
        var failedCount = 0
        var errorCountByMessage: [String: Int] = [:]

        for target in targets {
            do {
                let quote = try await networkService.fetchQuote(
                    symbol: target.symbol,
                    apiKey: finnhubAPIKey
                )
                let sessionAdjustedQuote = await adjustedQuoteForCurrentSession(
                    symbol: target.symbol,
                    baseQuote: quote,
                    updateNotice: false
                )
                fetchedItems.append(
                    HoldingLiveStockQuote(
                        stockName: target.name,
                        symbol: target.symbol,
                        quote: sessionAdjustedQuote
                    )
                )
                fetchedQuotesBySymbol[target.symbol] = sessionAdjustedQuote
            } catch {
                failedCount += 1
                let message = (error as? LocalizedError)?.errorDescription ?? "未知错误"
                errorCountByMessage[message, default: 0] += 1
            }
        }

        holdingLiveStockQuotes = fetchedItems.sorted { $0.symbol < $1.symbol }
        applyRealtimeQuotesToHoldingRecords(fetchedQuotesBySymbol)
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
            guard let code = extractHoldingSymbol(from: record) else {
                continue
            }
            if hiddenRealtimeHoldingSymbols.contains(code) {
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

    private func syncHoldingLiveQuotesWithPlaceholders() {
        let targets = uniqueHoldingTargets()
        let existingBySymbol = Dictionary(uniqueKeysWithValues: holdingLiveStockQuotes.map { ($0.symbol, $0) })

        holdingLiveStockQuotes = targets.map { target in
            if let existing = existingBySymbol[target.symbol] {
                return existing
            }
            return HoldingLiveStockQuote(
                stockName: target.name,
                symbol: target.symbol,
                quote: StockQuote(
                    symbol: target.symbol,
                    price: 0,
                    previousClose: 0,
                    change: 0,
                    changePercent: 0,
                    updatedAt: Date()
                )
            )
        }
        .sorted { $0.symbol < $1.symbol }
    }

    private func applyRealtimeQuoteToHoldingRecords(symbol: String, quote: StockQuote) {
        applyRealtimeQuotesToHoldingRecords([symbol: quote])
    }

    private func applyRealtimeQuotesToHoldingRecords(_ quotesBySymbol: [String: StockQuote]) {
        guard !quotesBySymbol.isEmpty else { return }
        var changed = false

        holdingRecords = holdingRecords.map { record in
            guard let symbol = extractHoldingSymbol(from: record),
                  let quote = quotesBySymbol[symbol] else {
                return record
            }

            let updated = mergedHoldingRecord(record: record, quote: quote)
            if holdingRecordPayloadChanged(lhs: updated, rhs: record) {
                changed = true
            }
            return updated
        }

        if changed {
            persistHoldingRecords()
        }
    }

    private func mergedHoldingRecord(record: HoldingRecord, quote: StockQuote) -> HoldingRecord {
        let quantity = record.quantity
        let costPrice = record.costPrice
        let latestPrice = quote.price

        let marketValue: Double? = {
            guard let quantity else { return record.marketValue }
            return quantity * latestPrice
        }()

        let todayPnL: Double? = {
            guard let quantity else { return record.todayPnL }
            return quantity * quote.change
        }()

        let todayPnLPercent: Double? = {
            guard quantity != nil else { return record.todayPnLPercent }
            return quote.changePercent
        }()

        let holdingPnL: Double? = {
            guard let quantity, let costPrice else { return record.holdingPnL }
            return (latestPrice - costPrice) * quantity
        }()

        let holdingPnLPercent: Double? = {
            guard let costPrice, costPrice != 0 else { return record.holdingPnLPercent }
            return ((latestPrice - costPrice) / costPrice) * 100
        }()

        return HoldingRecord(
            id: record.id,
            timestamp: record.timestamp,
            stockName: record.stockName,
            stockCode: record.stockCode,
            marketValue: marketValue,
            quantity: quantity,
            currentPrice: latestPrice,
            costPrice: costPrice,
            todayPnL: todayPnL,
            todayPnLPercent: todayPnLPercent,
            holdingPnL: holdingPnL,
            holdingPnLPercent: holdingPnLPercent
        )
    }

    private func holdingRecordPayloadChanged(lhs: HoldingRecord, rhs: HoldingRecord) -> Bool {
        lhs.marketValue != rhs.marketValue ||
        lhs.currentPrice != rhs.currentPrice ||
        lhs.todayPnL != rhs.todayPnL ||
        lhs.todayPnLPercent != rhs.todayPnLPercent ||
        lhs.holdingPnL != rhs.holdingPnL ||
        lhs.holdingPnLPercent != rhs.holdingPnLPercent
    }

    private func updateCurrentTradingSession(at date: Date = Date()) {
        currentTradingSession = classifyTradingSession(for: date)
        usMarketTimeText = formattedUSMarketTime(date)
    }

    private func classifyTradingSession(for date: Date) -> TradingSessionType {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.usMarketTimeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        let preMarketStart = 4 * 60
        let regularStart = 9 * 60 + 30
        let regularEnd = 16 * 60
        let afterHoursEnd = 20 * 60

        if minutes >= preMarketStart && minutes < regularStart {
            return .preMarket
        }
        if minutes >= regularStart && minutes < regularEnd {
            return .regular
        }
        if minutes >= regularEnd && minutes < afterHoursEnd {
            return .afterHours
        }
        return .overnight
    }

    private func formattedUSMarketTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = Self.usMarketTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func adjustedQuoteForCurrentSession(
        symbol: String,
        baseQuote: StockQuote,
        updateNotice: Bool
    ) async -> StockQuote {
        let session = currentTradingSession
        guard session != .regular else {
            if updateNotice {
                sessionPriceNoticeMessage = nil
            }
            return baseQuote
        }

        do {
            let series = try await networkService.fetchIntradaySeries(
                symbol: symbol,
                apiKey: finnhubAPIKey
            )
            guard let latestSessionPoint = series.last(where: { $0.session == session }) else {
                if updateNotice {
                    sessionPriceNoticeMessage = "未取到\(session.displayName)分时数据，已使用最新价。"
                }
                return baseQuote
            }

            let sessionPrice = latestSessionPoint.close
            let previousClose = baseQuote.previousClose
            let change = sessionPrice - previousClose
            let changePercent = previousClose == 0 ? 0 : (change / previousClose) * 100

            if updateNotice {
                sessionPriceNoticeMessage = "已使用\(session.displayName)分时数据。"
            }

            return StockQuote(
                symbol: baseQuote.symbol,
                price: sessionPrice,
                previousClose: previousClose,
                change: change,
                changePercent: changePercent,
                updatedAt: latestSessionPoint.timestamp
            )
        } catch {
            if updateNotice {
                let message = (error as? LocalizedError)?.errorDescription ?? ""
                if message.contains("你没有访问此资源的权限") {
                    sessionPriceNoticeMessage = "当前 token 无\(session.displayName)数据权限，已使用最新价。"
                } else {
                    sessionPriceNoticeMessage = "\(session.displayName)分时请求失败，已使用最新价。"
                }
            }
            return baseQuote
        }
    }

    private func extractHoldingSymbol(from record: HoldingRecord) -> String? {
        if let code = record.stockCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
           !code.isEmpty {
            return code
        }

        let text = record.stockName.uppercased()
        let pattern = #"[A-Z]{1,5}(?:\.[A-Z]{1,2})?"#
        let blacklist = ["USD", "HKD", "CNY", "PNL"]

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: range) {
            guard let r = Range(match.range, in: text) else { continue }
            let candidate = String(text[r])
            if !blacklist.contains(candidate) {
                return candidate
            }
        }

        return nil
    }

    private func persistStockSymbol() {
        UserDefaults.standard.set(stockSymbol, forKey: stockSymbolStorageKey)
    }

    private func loadPersistedStockSymbol() -> String {
        let stored = UserDefaults.standard.string(forKey: stockSymbolStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return (stored?.isEmpty == false) ? stored! : ""
    }

    private func persistFinnhubAPIKey() {
        UserDefaults.standard.set(finnhubAPIKey, forKey: finnhubAPIKeyStorageKey)
    }

    private func loadPersistedFinnhubAPIKey() -> String {
        let stored = UserDefaults.standard.string(forKey: finnhubAPIKeyStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (stored?.isEmpty == false) ? stored! : "d7tvh11r01qvtspvv84gd7tvh11r01qvtspvv850"
    }

    private func normalizedSymbol(_ symbol: String) -> String {
        symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func persistLiveStockQuote() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(liveStockQuote)
        UserDefaults.standard.set(data, forKey: liveStockQuoteStorageKey)
    }

    private func loadPersistedLiveStockQuote() -> StockQuote? {
        guard let data = UserDefaults.standard.data(forKey: liveStockQuoteStorageKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StockQuote?.self, from: data)
    }

    private func persistHoldingLiveStockQuotes() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(holdingLiveStockQuotes) else { return }
        UserDefaults.standard.set(data, forKey: holdingLiveQuotesStorageKey)
    }

    private func loadPersistedHoldingLiveStockQuotes() -> [HoldingLiveStockQuote] {
        guard let data = UserDefaults.standard.data(forKey: holdingLiveQuotesStorageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HoldingLiveStockQuote].self, from: data)) ?? []
    }

    private func persistWatchlistStockQuotes() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(watchlistStockQuotes) else { return }
        UserDefaults.standard.set(data, forKey: watchlistQuotesStorageKey)
    }

    private func loadPersistedWatchlistStockQuotes() -> [WatchlistStockQuote] {
        guard let data = UserDefaults.standard.data(forKey: watchlistQuotesStorageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WatchlistStockQuote].self, from: data)) ?? []
    }

    private func persistHiddenRealtimeHoldingSymbols() {
        UserDefaults.standard.set(Array(hiddenRealtimeHoldingSymbols), forKey: hiddenRealtimeSymbolsStorageKey)
    }

    private func loadPersistedHiddenRealtimeHoldingSymbols() -> Set<String> {
        let symbols = UserDefaults.standard.stringArray(forKey: hiddenRealtimeSymbolsStorageKey) ?? []
        return Set(symbols.map(normalizedSymbol))
    }
}
