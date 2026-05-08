import Foundation
import Moya
import Alamofire

enum NetworkServiceError: LocalizedError {
    case invalidSymbol
    case invalidAPIKey
    case apiResponse(String)
    case parseFailed
    case badStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidSymbol:
            return "请输入有效股票代码"
        case .invalidAPIKey:
            return "请先在设置中填写行情接口密钥"
        case .apiResponse(let message):
            return message
        case .parseFailed:
            return "解析股票行情失败，请稍后重试"
        case .badStatusCode:
            return "接口请求失败，请稍后重试"
        }
    }
}

private enum LiveRateAPI {
    case exchangeRates(base: Currency)
    case quote(symbol: String, token: String)
    case candle(symbol: String, resolution: String, from: Int, to: Int, token: String)
}

extension LiveRateAPI: TargetType {
    var baseURL: URL {
        switch self {
        case .exchangeRates:
            return URL(string: "https://open.er-api.com")!
        case .quote, .candle:
            return URL(string: "https://finnhub.io")!
        }
    }

    var path: String {
        switch self {
        case .exchangeRates(let base):
            return "/v6/latest/\(base.rawValue)"
        case .quote:
            return "/api/v1/quote"
        case .candle:
            return "/api/v1/stock/candle"
        }
    }

    var method: Moya.Method {
        .get
    }

    var task: Task {
        switch self {
        case .exchangeRates:
            return .requestPlain
        case .quote(let symbol, let token):
            return .requestParameters(
                parameters: [
                    "symbol": symbol,
                    "token": token
                ],
                encoding: URLEncoding.default
            )
        case .candle(let symbol, let resolution, let from, let to, let token):
            return .requestParameters(
                parameters: [
                    "symbol": symbol,
                    "resolution": resolution,
                    "from": from,
                    "to": to,
                    "token": token
                ],
                encoding: URLEncoding.default
            )
        }
    }

    var headers: [String: String]? {
        ["Accept": "application/json"]
    }

    var validationType: ValidationType {
        .successCodes
    }
}

private struct JSONResponseLoggerPlugin: PluginType {
    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        switch result {
        case .success(let response):
            Self.logJSONResponse(response.data, endpoint: target.path)
        case .failure(let error):
            if let response = error.response {
                Self.logJSONResponse(response.data, endpoint: target.path)
            }
        }
    }

    private static func logJSONResponse(_ data: Data, endpoint: String) {
        if let object = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let prettyText = String(data: prettyData, encoding: .utf8) {
            print("[接口响应] \(endpoint)\n\(prettyText)")
            return
        }

        if let rawText = String(data: data, encoding: .utf8) {
            print("[接口响应] \(endpoint)\n\(rawText)")
        } else {
            print("[接口响应] \(endpoint)\n<无法解析为字符串>")
        }
    }
}

final class NetworkService {
    private let provider: MoyaProvider<LiveRateAPI>
    private let decoder = JSONDecoder()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        let session = Session(configuration: config)
        self.provider = MoyaProvider<LiveRateAPI>(
            session: session,
            plugins: [JSONResponseLoggerPlugin()]
        )
    }

    func fetch(base: Currency) async throws -> RateSnapshot {
        let data = try await requestData(for: .exchangeRates(base: base))
        let decoded = try decoder.decode(RateResponse.self, from: data)

        var mappedRates: [Currency: Double] = [:]
        for currency in Currency.allCases {
            if currency == base {
                mappedRates[currency] = 1
            } else if let value = decoded.rates[currency.rawValue] {
                mappedRates[currency] = value
            }
        }

        return RateSnapshot(
            updatedAt: Date(timeIntervalSince1970: decoded.time_last_update_unix),
            rates: mappedRates
        )
    }

    func fetchQuote(symbol: String, apiKey: String) async throws -> StockQuote {
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedSymbol.isEmpty else { throw NetworkServiceError.invalidSymbol }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { throw NetworkServiceError.invalidAPIKey }

        let data = try await requestData(for: .quote(symbol: normalizedSymbol, token: normalizedKey))

        if let responseError = try? decoder.decode(FinnhubErrorEnvelope.self, from: data),
           let message = responseError.error,
           !message.isEmpty {
            throw NetworkServiceError.apiResponse(localizedServerMessage(message))
        }

        let payload = try decoder.decode(FinnhubQuoteResponse.self, from: data)
        guard payload.c > 0 || payload.pc > 0 else {
            throw NetworkServiceError.parseFailed
        }

        return StockQuote(
            symbol: normalizedSymbol,
            price: payload.c,
            previousClose: payload.pc,
            change: payload.d,
            changePercent: payload.dp,
            updatedAt: payload.t > 0 ? Date(timeIntervalSince1970: payload.t) : Date()
        )
    }

    func fetchIntradaySeries(symbol: String, apiKey: String) async throws -> [IntradayPricePoint] {
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedSymbol.isEmpty else { throw NetworkServiceError.invalidSymbol }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { throw NetworkServiceError.invalidAPIKey }

        let now = Date()
        let fromDate = Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now
        let from = Int(fromDate.timeIntervalSince1970)
        let to = Int(now.timeIntervalSince1970)

        let data = try await requestData(
            for: .candle(
                symbol: normalizedSymbol,
                resolution: "5",
                from: from,
                to: to,
                token: normalizedKey
            )
        )

        if let responseError = try? decoder.decode(FinnhubErrorEnvelope.self, from: data),
           let message = responseError.error,
           !message.isEmpty {
            throw NetworkServiceError.apiResponse(localizedServerMessage(message))
        }

        let payload = try decoder.decode(FinnhubCandleResponse.self, from: data)
        guard payload.s == "ok",
              payload.c.count == payload.t.count else {
            throw NetworkServiceError.parseFailed
        }

        return zip(payload.t, payload.c).map { timestamp, close in
            let date = Date(timeIntervalSince1970: timestamp)
            return IntradayPricePoint(
                timestamp: date,
                close: close,
                session: classifySession(for: date)
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    private func requestData(for target: LiveRateAPI) async throws -> Data {
        let response = try await withCheckedThrowingContinuation { continuation in
            provider.request(target) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        guard (200..<300).contains(response.statusCode) else {
            throw NetworkServiceError.badStatusCode(response.statusCode)
        }
        return response.data
    }

    private func classifySession(for date: Date) -> TradingSessionType {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
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

    private func localizedServerMessage(_ message: String) -> String {
        let lowercased = message.lowercased()

        if lowercased.contains("api limit") || lowercased.contains("rate limit") {
            return "接口返回错误：请求频率过高，请稍后重试。"
        }
        if lowercased.contains("symbol") || lowercased.contains("invalid") {
            return "接口返回错误：股票代码或请求参数无效。"
        }
        if lowercased.contains("token") || lowercased.contains("api key") {
            return "接口返回错误：接口密钥无效，请检查后重试。"
        }
        if lowercased.contains("don't have access to this resource") {
            return "接口返回错误：你没有访问此资源的权限。"
        }

        return "接口返回错误（原文）：\(message)"
    }
}

private struct FinnhubErrorEnvelope: Decodable {
    let error: String?
}

private struct FinnhubQuoteResponse: Decodable {
    let c: Double
    let d: Double
    let dp: Double
    let pc: Double
    let t: TimeInterval
}

private struct FinnhubCandleResponse: Decodable {
    let c: [Double]
    let t: [TimeInterval]
    let s: String
}
