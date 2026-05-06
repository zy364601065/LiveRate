import Foundation

final class ExchangeRateService {
    func fetch(base: Currency) async throws -> RateSnapshot {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(base.rawValue)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        Self.logJSONResponse(data, endpoint: "汇率接口 /latest/\(base.rawValue)")
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(RateResponse.self, from: data)
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
