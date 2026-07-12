import Foundation
import Supabase

struct HoldingsSyncService {
    private let pendingDeletePrefix = "myliverate.holdings.pending_deletes.v1."
    private struct UpsertResultRow: Decodable {
        let id: UUID
        let userId: UUID
        let sourceKey: String
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case sourceKey = "source_key"
            case deletedAt = "deleted_at"
        }
    }

    private struct UpsertVerificationError: LocalizedError {
        let expected: Int
        let received: Int
        var errorDescription: String? {
            "持仓写入校验失败：应返回 \(expected) 条，实际返回 \(received) 条"
        }
    }

    private struct DeleteResultRow: Decodable {
        let id: UUID
    }

    private struct DeleteVerificationError: LocalizedError {
        var errorDescription: String? { "数据库中未找到需要删除的持仓" }
    }
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

    func refreshPortfolioQuotes() async throws -> PortfolioQuoteResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try await supabase.functions.invoke("portfolio-quotes", decoder: decoder)
    }

    func fetchDailySettlements() async throws -> [HoldingDailySettlement] {
        let userID = try await supabase.auth.session.user.id
        return try await supabase.from("holding_daily_settlements").select()
            .eq("user_id", value: userID.uuidString).order("trading_date", ascending: true).execute().value
    }

    func upsert(_ records: [HoldingRecord]) async throws {
        guard !records.isEmpty else { return }
        let userID = try await supabase.auth.session.user.id
        print("[持仓同步] 准备上传：用户=\(userID.uuidString.prefix(8))，数量=\(records.count)")
        let now = Date()
        let rows = records.map { record in
            WriteRow(id: record.id, userId: userID, sourceKey: sourceKey(record), stockName: record.stockName,
                     stockCode: record.stockCode, marketValue: record.marketValue, quantity: record.quantity,
                     currentPrice: record.currentPrice, costPrice: record.costPrice, todayPnL: record.todayPnL,
                     todayPnLPercent: record.todayPnLPercent, holdingPnL: record.holdingPnL,
                     holdingPnLPercent: record.holdingPnLPercent, dataTimestamp: record.timestamp,
                     updatedAt: now, deletedAt: nil)
        }
        do {
            var saved: [UpsertResultRow] = try await supabase.from("user_holdings")
                .upsert(rows, onConflict: "user_id,source_key", returning: .representation)
                .select("id,user_id,source_key,deleted_at")
                .execute().value
            let deletedRows = saved.filter { $0.userId == userID && $0.deletedAt != nil }
            if !deletedRows.isEmpty {
                print("[持仓同步] 检测到已软删除的同名持仓，正在恢复：数量=\(deletedRows.count)")
                let restoredAt = ISO8601DateFormatter().string(from: Date())
                for row in deletedRows {
                    let patch: [String: String?] = ["deleted_at": nil, "updated_at": restoredAt]
                    try await supabase.from("user_holdings").update(patch)
                        .eq("id", value: row.id.uuidString)
                        .eq("user_id", value: userID.uuidString)
                        .execute()
                }
                saved = try await supabase.from("user_holdings")
                    .select("id,user_id,source_key,deleted_at")
                    .eq("user_id", value: userID.uuidString)
                    .execute().value
                let uploadedKeys = Set(rows.map(\.sourceKey))
                saved = saved.filter { uploadedKeys.contains($0.sourceKey) }
            }
            let activeSaved = saved.filter { $0.userId == userID && $0.deletedAt == nil }
            guard activeSaved.count == rows.count else {
                print("[持仓同步] 上传校验失败：预期=\(rows.count)，数据库返回=\(saved.count)，有效记录=\(activeSaved.count)")
                throw UpsertVerificationError(expected: rows.count, received: activeSaved.count)
            }
            print("[持仓同步] 上传并校验成功：数量=\(activeSaved.count)，记录编号=\(activeSaved.map { $0.id.uuidString.prefix(8) }.joined(separator: ","))，持仓标识=\(activeSaved.map(\.sourceKey).joined(separator: ","))")
        } catch {
            print("[持仓同步] 上传失败：用户=\(userID.uuidString.prefix(8))，错误=\(String(reflecting: error))")
            throw error
        }
    }

    func softDelete(id: UUID, sourceKey: String? = nil) async throws {
        let userID = try await supabase.auth.session.user.id
        let now = Date()
        var deleted: [DeleteResultRow] = try await supabase.from("user_holdings")
            .update(["deleted_at": now, "updated_at": now])
            .eq("id", value: id.uuidString).eq("user_id", value: userID.uuidString)
            .is("deleted_at", value: nil).select("id").execute().value
        if deleted.isEmpty, let sourceKey {
            print("[持仓同步] 按本地记录编号未找到云端持仓，改用持仓标识删除：标识=\(sourceKey)")
            deleted = try await supabase.from("user_holdings")
                .update(["deleted_at": now, "updated_at": now])
                .eq("user_id", value: userID.uuidString).eq("source_key", value: sourceKey)
                .is("deleted_at", value: nil).select("id").execute().value
        }
        guard !deleted.isEmpty else {
            print("[持仓同步] 云端删除校验失败：本地记录编号=\(id.uuidString.prefix(8))")
            throw DeleteVerificationError()
        }
        print("[持仓同步] 云端删除成功：数量=\(deleted.count)，记录编号=\(deleted.map { $0.id.uuidString.prefix(8) }.joined(separator: ","))")
    }

    func queueAndSoftDelete(id: UUID, sourceKey: String) async throws {
        let userID = try await supabase.auth.session.user.id
        var ids = pendingDeleteIDs(userID: userID)
        ids.insert(id)
        savePendingDeleteIDs(ids, userID: userID)
        do {
            try await softDelete(id: id, sourceKey: sourceKey)
            ids.remove(id)
            savePendingDeleteIDs(ids, userID: userID)
        } catch {
            throw error
        }
    }

    func flushPendingDeletes() async throws {
        let userID = try await supabase.auth.session.user.id
        var ids = pendingDeleteIDs(userID: userID)
        if !ids.isEmpty { print("[持仓同步] 正在重试待删除记录：数量=\(ids.count)") }
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
