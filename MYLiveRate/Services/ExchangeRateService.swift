import Foundation

final class ExchangeRateService {
    func fetch(base: Currency) async throws -> RateSnapshot {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(base.rawValue)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
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
}
