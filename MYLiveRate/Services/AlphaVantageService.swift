import Foundation

enum AlphaVantageServiceError: LocalizedError {
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

final class AlphaVantageService {
    func fetchQuote(symbol: String, apiKey: String) async throws -> StockQuote {
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedSymbol.isEmpty else {
            throw AlphaVantageServiceError.invalidSymbol
        }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw AlphaVantageServiceError.invalidAPIKey
        }

        var components = URLComponents(string: "https://www.alphavantage.co/query")
        components?.queryItems = [
            URLQueryItem(name: "function", value: "GLOBAL_QUOTE"),
            URLQueryItem(name: "symbol", value: normalizedSymbol),
            URLQueryItem(name: "apikey", value: normalizedKey)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        Self.logJSONResponse(data, endpoint: "Alpha Vantage GLOBAL_QUOTE \(normalizedSymbol)")
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        if let responseError = try? JSONDecoder().decode(AlphaVantageErrorEnvelope.self, from: data),
           let message = responseError.message {
            throw AlphaVantageServiceError.apiResponse(localizedServerMessage(message))
        }

        let decoded = try JSONDecoder().decode(AlphaVantageGlobalQuoteResponse.self, from: data)
        let payload = decoded.globalQuote

        guard let price = parseNumber(payload.price),
              let previousClose = parseNumber(payload.previousClose),
              let change = parseNumber(payload.change),
              let changePercent = parsePercent(payload.changePercent) else {
            throw AlphaVantageServiceError.parseFailed
        }

        return StockQuote(
            symbol: payload.symbol.isEmpty ? normalizedSymbol : payload.symbol,
            price: price,
            previousClose: previousClose,
            change: change,
            changePercent: changePercent,
            updatedAt: Date()
        )
    }

    private func parseNumber(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: "")
        return Double(normalized)
    }

    private func parsePercent(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(normalized)
    }

    func fetchIntradaySeries(symbol: String, apiKey: String) async throws -> [IntradayPricePoint] {
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedSymbol.isEmpty else {
            throw AlphaVantageServiceError.invalidSymbol
        }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw AlphaVantageServiceError.invalidAPIKey
        }

        var components = URLComponents(string: "https://www.alphavantage.co/query")
        components?.queryItems = [
            URLQueryItem(name: "function", value: "TIME_SERIES_INTRADAY"),
            URLQueryItem(name: "symbol", value: normalizedSymbol),
            URLQueryItem(name: "interval", value: "5min"),
            URLQueryItem(name: "outputsize", value: "full"),
            URLQueryItem(name: "extended_hours", value: "true"),
            URLQueryItem(name: "apikey", value: normalizedKey)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        Self.logJSONResponse(data, endpoint: "Alpha Vantage TIME_SERIES_INTRADAY \(normalizedSymbol)")
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        if let responseError = try? JSONDecoder().decode(AlphaVantageErrorEnvelope.self, from: data),
           let message = responseError.message {
            throw AlphaVantageServiceError.apiResponse(localizedServerMessage(message))
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw AlphaVantageServiceError.parseFailed
        }

        guard let seriesEntry = dictionary.first(where: { $0.key.contains("Time Series") }),
              let seriesMap = seriesEntry.value as? [String: [String: String]] else {
            throw AlphaVantageServiceError.parseFailed
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let points: [IntradayPricePoint] = seriesMap.compactMap { timeText, values in
            guard let date = formatter.date(from: timeText),
                  let closeText = values["4. close"],
                  let close = Double(closeText) else {
                return nil
            }
            return IntradayPricePoint(
                timestamp: date,
                close: close,
                session: classifySession(for: date)
            )
        }
        .sorted { $0.timestamp < $1.timestamp }

        return points
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

        if lowercased.contains("25 requests per day") || lowercased.contains("daily rate limit") {
            return "接口返回错误：今日免费调用次数已达上限（25次/天），请明天再试或升级套餐。"
        }
        if lowercased.contains("per minute") || lowercased.contains("frequency") {
            return "接口返回错误：请求频率过高，请稍后重试。"
        }
        if lowercased.contains("invalid api call") {
            return "接口返回错误：请求参数无效（可能是股票代码或接口函数不正确）。"
        }
        if lowercased.contains("api key") || lowercased.contains("apikey") {
            return "接口返回错误：接口密钥无效，请检查后重试。"
        }

        return "接口返回错误（原文）：\(message)"
    }
}

private struct AlphaVantageErrorEnvelope: Decodable {
    let note: String?
    let information: String?
    let errorMessage: String?

    var message: String? {
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        if let note, !note.isEmpty {
            return note
        }
        if let information, !information.isEmpty {
            return information
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case note = "Note"
        case information = "Information"
        case errorMessage = "Error Message"
    }
}

private struct AlphaVantageGlobalQuoteResponse: Decodable {
    let globalQuote: AlphaVantageGlobalQuote

    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

private struct AlphaVantageGlobalQuote: Decodable {
    let symbol: String
    let price: String
    let previousClose: String
    let change: String
    let changePercent: String

    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case price = "05. price"
        case previousClose = "08. previous close"
        case change = "09. change"
        case changePercent = "10. change percent"
    }
}
