import Foundation
import Supabase

struct HoldingsSyncService {
    private let pendingDeletePrefix = "myliverate.holdings.pending_deletes.v1."
    struct Row: Codable {
        let id: UUID
        let userId: UUID
        let sourceKey: String
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
        let dataTimestamp: Date
        let updatedAt: Date
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, quantity
            case userId = "user_id"
            case sourceKey = "source_key"
            case stockName = "stock_name"
            case stockCode = "stock_code"
            case marketValue = "market_value"
            case currentPrice = "current_price"
            case costPrice = "cost_price"
            case todayPnL = "today_pnl"
            case todayPnLPercent = "today_pnl_percent"
            case holdingPnL = "holding_pnl"
            case holdingPnLPercent = "holding_pnl_percent"
            case dataTimestamp = "data_timestamp"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }

        var record: HoldingRecord {
            HoldingRecord(id: id, timestamp: dataTimestamp, stockName: stockName, stockCode: stockCode,
                          marketValue: marketValue, quantity: quantity, currentPrice: currentPrice,
                          costPrice: costPrice, todayPnL: todayPnL, todayPnLPercent: todayPnLPercent,
                          holdingPnL: holdingPnL, holdingPnLPercent: holdingPnLPercent)
        }
    }

    private struct WriteRow: Encodable {
        let id: UUID; let userId: UUID; let sourceKey: String; let stockName: String; let stockCode: String?
        let marketValue: Double?; let quantity: Double?; let currentPrice: Double?; let costPrice: Double?
        let todayPnL: Double?; let todayPnLPercent: Double?; let holdingPnL: Double?; let holdingPnLPercent: Double?
        let dataTimestamp: Date; let updatedAt: Date; let deletedAt: Date?
        enum CodingKeys: String, CodingKey {
            case id, quantity; case userId = "user_id"; case sourceKey = "source_key"; case stockName = "stock_name"
            case stockCode = "stock_code"; case marketValue = "market_value"; case currentPrice = "current_price"
            case costPrice = "cost_price"; case todayPnL = "today_pnl"; case todayPnLPercent = "today_pnl_percent"
            case holdingPnL = "holding_pnl"; case holdingPnLPercent = "holding_pnl_percent"
            case dataTimestamp = "data_timestamp"; case updatedAt = "updated_at"; case deletedAt = "deleted_at"
        }
    }

    func fetch() async throws -> [Row] {
        let userID = try await supabase.auth.session.user.id
        return try await supabase.from("user_holdings").select().eq("user_id", value: userID.uuidString)
            .order("data_timestamp", ascending: false).execute().value
    }

    func upsert(_ records: [HoldingRecord]) async throws {
        guard !records.isEmpty else { return }
        let userID = try await supabase.auth.session.user.id
        let now = Date()
        let rows = records.map { record in
            WriteRow(id: record.id, userId: userID, sourceKey: sourceKey(record), stockName: record.stockName,
                     stockCode: record.stockCode, marketValue: record.marketValue, quantity: record.quantity,
                     currentPrice: record.currentPrice, costPrice: record.costPrice, todayPnL: record.todayPnL,
                     todayPnLPercent: record.todayPnLPercent, holdingPnL: record.holdingPnL,
                     holdingPnLPercent: record.holdingPnLPercent, dataTimestamp: record.timestamp,
                     updatedAt: now, deletedAt: nil)
        }
        try await supabase.from("user_holdings").upsert(rows, onConflict: "user_id,source_key", returning: .minimal).execute()
    }

    func softDelete(id: UUID) async throws {
        let userID = try await supabase.auth.session.user.id
        let now = Date()
        try await supabase.from("user_holdings").update(["deleted_at": now, "updated_at": now])
            .eq("id", value: id.uuidString).eq("user_id", value: userID.uuidString).execute()
    }

    func queueAndSoftDelete(id: UUID) async throws {
        let userID = try await supabase.auth.session.user.id
        var ids = pendingDeleteIDs(userID: userID)
        ids.insert(id)
        savePendingDeleteIDs(ids, userID: userID)
        do {
            try await softDelete(id: id)
            ids.remove(id)
            savePendingDeleteIDs(ids, userID: userID)
        } catch {
            throw error
        }
    }

    func flushPendingDeletes() async throws {
        let userID = try await supabase.auth.session.user.id
        var ids = pendingDeleteIDs(userID: userID)
        for id in ids {
            try await softDelete(id: id)
            ids.remove(id)
            savePendingDeleteIDs(ids, userID: userID)
        }
    }

    private func pendingDeleteIDs(userID: UUID) -> Set<UUID> {
        let values = UserDefaults.standard.stringArray(forKey: pendingDeletePrefix + userID.uuidString) ?? []
        return Set(values.compactMap(UUID.init(uuidString:)))
    }

    private func savePendingDeleteIDs(_ ids: Set<UUID>, userID: UUID) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: pendingDeletePrefix + userID.uuidString)
    }

    private func sourceKey(_ record: HoldingRecord) -> String {
        (record.stockCode?.isEmpty == false ? record.stockCode! : record.stockName)
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}
