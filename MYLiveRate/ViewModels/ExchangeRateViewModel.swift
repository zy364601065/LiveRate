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
    @Published var portfolioMarketSession: PortfolioMarketSession = .closed
    @Published var portfolioSessionPercent: Double?
    @Published var portfolioSessionPnLUSD: Double?
    @Published var portfolioQuoteProvider: String?
    @Published var portfolioQuoteAt: Date?
    @Published var portfolioQuoteIsStale = false
    @Published var holdingDailySettlements: [HoldingDailySettlement] = []
    @Published var portfolioQuotesBySymbol: [String: PortfolioSessionQuotes] = [:]

    private let localRecordsStore: LocalRecordsStore
    private let networkService = NetworkService()
    private let ocrService = DollarOCRService()
    private let holdingsOCRService = HoldingsOCRService()
    private let holdingsSyncService = HoldingsSyncService()
    private let statsRecordSyncService = StatsRecordSyncService()
    private let amountTextStorageKey = "myliverate.amount_text.v1"
    private let latestThumbnailStorageKey = "myliverate.latest_upload_thumbnail.v1"
    private let pendingHoldingUpsertsStorageKey = "myliverate.holdings.pending_upserts.v1"
    private var isSyncingHoldings = false
    private static let usMarketTimeZone = TimeZone(identifier: "America/New_York") ?? .current

    init(localRecordsStore: LocalRecordsStore) {
        self.localRecordsStore = localRecordsStore
        amountText = loadPersistedAmountText()
        uploadRecords = localRecordsStore.fetchUploadRecords()
        latestUploadThumbnailData = UserDefaults.standard.data(forKey: latestThumbnailStorageKey)
        holdingRecords = localRecordsStore.fetchHoldingRecords()
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

    func refresh() async {
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

        isLoading = false
    }

    func syncStatUploadRecords() async {
        let localRecords = uploadRecords
        logStatsSync("syncStatUploadRecords: starting, localCount=\(localRecords.count)")

        do {
            let remoteRecords = try await statsRecordSyncService.fetchUploadRecords()
            logStatsSync("syncStatUploadRecords: fetched remoteCount=\(remoteRecords.count)")

            let mergedRecords = mergedUploadRecords(localRecords + remoteRecords)
            logStatsSync("syncStatUploadRecords: mergedCount=\(mergedRecords.count)")

            uploadRecords = mergedRecords
            localRecordsStore.upsertUploadRecords(mergedRecords)

            try await statsRecordSyncService.upsertUploadRecords(mergedRecords)
            logStatsSync("syncStatUploadRecords: completed upsertCount=\(mergedRecords.count)")
        } catch {
            logStatsSyncError("syncStatUploadRecords: failed", error: error)
            // Sync requires a signed-in Supabase user. Local stats remain available offline.
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
            print("[持仓同步] OCR 已保存到本地：识别=\(holdings.count)，本地总数=\(holdingRecords.count)，待上传=\(pendingHoldingUpsertIDs.count)")
            holdingMessage = "已识别持仓 \(holdings.count) 条，已保存在本机"
            // Cloud persistence is deliberately fire-and-forget. Local SwiftData is
            // the source of truth for the current session and must never wait for or
            // be replaced by a remote response.
            Task { await syncHoldings() }
        } catch {
            holdingMessage = "识别持仓失败，请稍后重试"
        }
    }

    func syncHoldings() async {
        guard !isSyncingHoldings else {
            print("[持仓同步] 已跳过重复的同步请求")
            return
        }
        isSyncingHoldings = true
        defer { isSyncingHoldings = false }

        print("[持仓同步] 开始同步：本地数量=\(holdingRecords.count)，待上传数量=\(pendingHoldingUpsertIDs.count)")

        do {
            try await holdingsSyncService.flushPendingDeletes()
        } catch {
            // A stale delete must never block uploading newly recognized holdings.
            print("[持仓同步] 待删除记录重试失败，但将继续上传持仓：错误=\(String(reflecting: error))")
        }

        do {
            // Remote data is only a recovery source for a genuinely empty device.
            // Once local records exist, never merge a remote snapshot back into them.
            if holdingRecords.isEmpty {
                let remoteRows = try await holdingsSyncService.fetch()
                print("[持仓同步] 本地为空，已读取云端记录：数量=\(remoteRows.count)")
                let recovered = remoteRows.filter { $0.deletedAt == nil }.map(\.record)
                if !recovered.isEmpty {
                    holdingRecords = recovered.sorted { $0.timestamp > $1.timestamp }
                    localRecordsStore.mergeHoldingRecords(recovered)
                }
            }

            guard !holdingRecords.isEmpty else { return }
            let recordsBeingUploaded = holdingRecords
            let uploadedIDs = Set(recordsBeingUploaded.map(\.id))
            try await holdingsSyncService.upsert(recordsBeingUploaded)
            // A new OCR import can arrive while the network request is suspended.
            // Only acknowledge IDs included in this successful request.
            pendingHoldingUpsertIDs.subtract(uploadedIDs)
            print("[持仓同步] 同步完成：已上传=\(uploadedIDs.count)，剩余待上传=\(pendingHoldingUpsertIDs.count)")
            holdingMessage = holdingRecords.isEmpty ? nil : "持仓已同步"
        } catch {
            print("[持仓同步] 同步失败，本地数据已保留：本地数量=\(holdingRecords.count)，错误=\(String(reflecting: error))")
            holdingMessage = "持仓已保存在本机，联网后可重试同步"
        }
    }

    func refreshPortfolioMarketData() async {
        guard !holdingRecords.isEmpty else { return }
        do {
            let response = try await holdingsSyncService.refreshPortfolioQuotes()
            portfolioMarketSession = response.session
            portfolioQuoteAt = response.refreshedAt
            portfolioQuotesBySymbol = Dictionary(uniqueKeysWithValues: response.items.map { ($0.symbol, $0.sessions) })
            let activeQuotes = response.items.compactMap { $0.sessions.quote(for: response.session) }
            portfolioQuoteProvider = Array(Set(activeQuotes.compactMap(\.provider))).sorted().joined(separator: " / ")
            portfolioQuoteIsStale = activeQuotes.contains { $0.isStale == true }
            var quantities: [String: Double] = [:]
            for record in holdingRecords {
                guard let symbol = record.stockCode?.uppercased(), let quantity = record.quantity else { continue }
                quantities[symbol, default: 0] += quantity
            }
            let totals = response.items.reduce(into: (change: 0.0, baseline: 0.0)) { result, item in
                guard let quantity = quantities[item.symbol] else { return }
                guard let quote = item.sessions.quote(for: response.session),
                      let change = quote.changeAmount, let baseline = quote.baselinePrice else { return }
                result.change += change * quantity
                result.baseline += baseline * quantity
            }
            portfolioSessionPercent = totals.baseline > 0 ? totals.change / totals.baseline * 100 : nil
            portfolioSessionPnLUSD = totals.baseline > 0 ? totals.change : nil
            holdingDailySettlements = try await holdingsSyncService.fetchDailySettlements()
        } catch {
            holdingMessage = "行情刷新失败，继续显示最近持仓数据"
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
        localRecordsStore.addUploadRecord(record)
        syncUploadRecordToSupabase(record)
    }

    private func syncUploadRecordToSupabase(_ record: UploadRecord) {
        Task {
            logStatsSync("syncUploadRecordToSupabase: starting id=\(record.id.uuidString), timestamp=\(record.timestamp), usdAmount=\(record.usdAmount)")
            do {
                try await statsRecordSyncService.upsertUploadRecord(record)
                logStatsSync("syncUploadRecordToSupabase: completed id=\(record.id.uuidString)")
            } catch {
                logStatsSyncError("syncUploadRecordToSupabase: failed id=\(record.id.uuidString)", error: error)
                // Keep the local record; a later signed-in sync can upload it.
            }
        }
    }

    private func logStatsSync(_ message: String) {
        print("[StatsSync] \(message)")
    }

    private func logStatsSyncError(_ message: String, error: Error) {
        let nsError = error as NSError
        print("[StatsSync][Error] \(message): domain=\(nsError.domain), code=\(nsError.code), localized=\(nsError.localizedDescription), debug=\(String(describing: error))")
    }

    private func mergedUploadRecords(_ records: [UploadRecord]) -> [UploadRecord] {
        var recordsByID: [UUID: UploadRecord] = [:]

        for record in records {
            recordsByID[record.id] = record
        }

        return recordsByID.values.sorted { $0.timestamp < $1.timestamp }
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

    private func addHoldingRecords(_ records: [HoldingRecord]) {
        var mergedByKey: [String: HoldingRecord] = [:]

        for record in holdingRecords {
            mergedByKey[holdingKey(for: record)] = record
        }

        for record in records {
            // 新识别到的同名股票会覆盖旧记录，达到“只保留最新一条”的效果
            let key = holdingKey(for: record)
            if let existing = mergedByKey[key] {
                mergedByKey[key] = HoldingRecord(
                    id: existing.id, timestamp: record.timestamp, stockName: record.stockName,
                    stockCode: record.stockCode, marketValue: record.marketValue, quantity: record.quantity,
                    currentPrice: record.currentPrice, costPrice: record.costPrice, todayPnL: record.todayPnL,
                    todayPnLPercent: record.todayPnLPercent, holdingPnL: record.holdingPnL,
                    holdingPnLPercent: record.holdingPnLPercent
                )
            } else {
                mergedByKey[key] = record
            }
        }

        holdingRecords = Array(mergedByKey.values).sorted { $0.timestamp > $1.timestamp }
        pendingHoldingUpsertIDs.formUnion(holdingRecords.map(\.id))
        localRecordsStore.mergeHoldingRecords(records)
    }

    func removeHoldingRecord(id: UUID) {
        let sourceKey = holdingRecords.first(where: { $0.id == id }).map(holdingKey(for:))
        pendingHoldingUpsertIDs.remove(id)
        holdingRecords.removeAll { $0.id == id }
        localRecordsStore.removeHoldingRecord(id: id)
        Task {
            do {
                guard let sourceKey else { throw CocoaError(.fileNoSuchFile) }
                try await holdingsSyncService.queueAndSoftDelete(id: id, sourceKey: sourceKey)
            }
            catch { holdingMessage = "已从本机删除，联网后请重试同步" }
        }
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

        let updatedRecord = HoldingRecord(
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
        holdingRecords[index] = updatedRecord
        holdingRecords.sort { $0.timestamp > $1.timestamp }
        localRecordsStore.updateHoldingIdentity(id: id, newName: trimmedName, newCode: normalizedCode)
        pendingHoldingUpsertIDs.insert(id)
        Task {
            do { try await holdingsSyncService.upsert([updatedRecord]) }
            catch { holdingMessage = "修改已保存在本机，联网后可重试同步" }
        }
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

    private var pendingHoldingUpsertIDs: Set<UUID> {
        get {
            Set((UserDefaults.standard.stringArray(forKey: pendingHoldingUpsertsStorageKey) ?? []).compactMap(UUID.init(uuidString:)))
        }
        set {
            UserDefaults.standard.set(newValue.map(\.uuidString), forKey: pendingHoldingUpsertsStorageKey)
        }
    }

}
