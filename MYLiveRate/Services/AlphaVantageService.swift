import Foundation

enum FinnhubServiceError: LocalizedError {
    case invalidSymbol
    case invalidAPIKey
    case apiResponse(String)
    case parseFailed

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
        }
    }
}

final class FinnhubService {
    func fetchQuote(symbol: String, apiKey: String) async throws -> StockQuote {
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedSymbol.isEmpty else {
            throw FinnhubServiceError.invalidSymbol
        }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw FinnhubServiceError.invalidAPIKey
        }

        var components = URLComponents(string: "https://finnhub.io/api/v1/quote")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: normalizedSymbol),
            URLQueryItem(name: "token", value: normalizedKey)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        Self.logJSONResponse(data, endpoint: "Finnhub quote \(normalizedSymbol)")
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        if let responseError = try? JSONDecoder().decode(FinnhubErrorEnvelope.self, from: data),
           let message = responseError.error,
           !message.isEmpty {
            throw FinnhubServiceError.apiResponse(localizedServerMessage(message))
        }

        let payload = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)
        guard payload.c > 0 || payload.pc > 0 else {
            throw FinnhubServiceError.parseFailed
        }

        let price = payload.c
        let previousClose = payload.pc
        let change = payload.d
        let changePercent = payload.dp

        return StockQuote(
            symbol: normalizedSymbol,
            price: price,
            previousClose: previousClose,
            change: change,
            changePercent: changePercent,
            updatedAt: payload.t > 0 ? Date(timeIntervalSince1970: payload.t) : Date()
        )
    }

    func fetchIntradaySeries(symbol: String, apiKey: String) async throws -> [IntradayPricePoint] {
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedSymbol.isEmpty else {
            throw FinnhubServiceError.invalidSymbol
        }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw FinnhubServiceError.invalidAPIKey
        }

        let now = Date()
        let fromDate = Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now
        let from = Int(fromDate.timeIntervalSince1970)
        let to = Int(now.timeIntervalSince1970)

        var components = URLComponents(string: "https://finnhub.io/api/v1/stock/candle")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: normalizedSymbol),
            URLQueryItem(name: "resolution", value: "5"),
            URLQueryItem(name: "from", value: "\(from)"),
            URLQueryItem(name: "to", value: "\(to)"),
            URLQueryItem(name: "token", value: normalizedKey)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        Self.logJSONResponse(data, endpoint: "Finnhub candle \(normalizedSymbol)")
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        if let responseError = try? JSONDecoder().decode(FinnhubErrorEnvelope.self, from: data),
           let message = responseError.error,
           !message.isEmpty {
            throw FinnhubServiceError.apiResponse(localizedServerMessage(message))
        }

        let payload = try JSONDecoder().decode(FinnhubCandleResponse.self, from: data)
        guard payload.s == "ok",
              payload.c.count == payload.t.count else {
            throw FinnhubServiceError.parseFailed
        }

        return zip(payload.t, payload.c).map { timestamp, close in
            let date = Date(timeIntervalSince1970: timestamp)
            return IntradayPricePoint(
                timestamp: date,
                close: close,
                session: classifySession(for: date)
            )
        }.sorted { $0.timestamp < $1.timestamp }
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
