import Foundation

enum Currency: String, CaseIterable, Identifiable {
    case USD
    case HKD
    case CNY

    var id: String { rawValue }

    var chineseName: String {
        switch self {
        case .USD: return "美元"
        case .HKD: return "港币"
        case .CNY: return "人民币"
        }
    }

    var symbol: String {
        switch self {
        case .USD: return "$"
        case .HKD: return "HK$"
        case .CNY: return "¥"
        }
    }

    var displayName: String {
        "\(chineseName) (\(rawValue))"
    }
}

struct UploadRecord: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let usdAmount: Double

    init(id: UUID = UUID(), timestamp: Date, usdAmount: Double) {
        self.id = id
        self.timestamp = timestamp
        self.usdAmount = usdAmount
    }
}

struct DailyLatestRecord: Identifiable {
    let day: Date
    let record: UploadRecord

    var id: Date { day }
}

enum TrendPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "按日"
        case .weekly: return "按周"
        case .monthly: return "按月"
        }
    }

    func startDate(for date: Date, calendar: Calendar) -> Date {
        switch self {
        case .daily:
            return calendar.startOfDay(for: date)
        case .weekly:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

struct TrendDataPoint: Identifiable {
    let periodStart: Date
    let amount: Double

    var id: Date { periodStart }
}

struct DailyAmountRow: Identifiable {
    let day: Date
    let convertedAmount: Double
    let sourceTime: Date
    let currency: Currency

    var id: Date { day }
}

struct DayUploadEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let convertedAmount: Double
    let currency: Currency
}

struct HoldingRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let stockName: String
    let stockCode: String?
    let marketValue: Double?
    let quantity: Double?
    let currentPrice: Double?
    let costPrice: Double?
    let todayPnL: Double?
    let todayPnLPercent: Double?
    let holdingPnL: Double?
    let holdingPnLPercent: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        stockName: String,
        stockCode: String?,
        marketValue: Double?,
        quantity: Double?,
        currentPrice: Double?,
        costPrice: Double?,
        todayPnL: Double?,
        todayPnLPercent: Double?,
        holdingPnL: Double?,
        holdingPnLPercent: Double?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stockName = stockName
        self.stockCode = stockCode
        self.marketValue = marketValue
        self.quantity = quantity
        self.currentPrice = currentPrice
        self.costPrice = costPrice
        self.todayPnL = todayPnL
        self.todayPnLPercent = todayPnLPercent
        self.holdingPnL = holdingPnL
        self.holdingPnLPercent = holdingPnLPercent
    }
}

struct RateResponse: Decodable {
    let time_last_update_unix: TimeInterval
    let rates: [String: Double]
}

struct RateSnapshot {
    let updatedAt: Date
    let rates: [Currency: Double]
}

struct StockQuote {
    let symbol: String
    let price: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let updatedAt: Date
}

struct HoldingLiveStockQuote: Identifiable {
    let stockName: String
    let symbol: String
    let quote: StockQuote

    var id: String { symbol }
}

enum TradingSessionFilter: String, CaseIterable, Identifiable {
    case all
    case overnight
    case preMarket
    case regular
    case afterHours

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .overnight: return "夜盘"
        case .preMarket: return "盘前"
        case .regular: return "盘中"
        case .afterHours: return "盘后"
        }
    }
}

enum TradingSessionType: String {
    case overnight
    case preMarket
    case regular
    case afterHours
}

struct IntradayPricePoint: Identifiable {
    let timestamp: Date
    let close: Double
    let session: TradingSessionType

    var id: Date { timestamp }
}
