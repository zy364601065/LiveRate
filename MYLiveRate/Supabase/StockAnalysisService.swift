import Foundation
import Supabase

struct StockAnalysisResult: Codable {
    let symbol: String
    let name: String?
    let content: String
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case symbol, name, content; case createdAt = "created_at" }
}

struct StockAnalysisService {
    func analyze(symbol: String, name: String) async throws -> StockAnalysisResult {
        struct Request: Encodable { let symbol: String; let name: String }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try await supabase.functions.invoke("stock-analysis", options: .init(body: Request(symbol: symbol, name: name)), decoder: decoder)
    }
}
