import Foundation
import Supabase

struct StatsRecordSyncService {
    private struct StatUploadRecordRow: Codable {
        let id: UUID
        let userId: UUID
        let timestamp: Date
        let usdAmount: Double

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case timestamp
            case usdAmount = "usd_amount"
        }
    }

    private let tableName = "stat_upload_records"

    func fetchUploadRecords() async throws -> [UploadRecord] {
        let userID = try await authenticatedUserID()

        let rows: [StatUploadRecordRow] = try await supabase
            .from(tableName)
            .select()
            .eq("user_id", value: userID.uuidString)
            .order("timestamp", ascending: true)
            .execute()
            .value

        return rows.map {
            UploadRecord(id: $0.id, timestamp: $0.timestamp, usdAmount: $0.usdAmount)
        }
    }

    func upsertUploadRecord(_ record: UploadRecord) async throws {
        try await upsertUploadRecords([record])
    }

    func upsertUploadRecords(_ records: [UploadRecord]) async throws {
        guard !records.isEmpty else { return }
        let userID = try await authenticatedUserID()
        let rows = records.map {
            StatUploadRecordRow(
                id: $0.id,
                userId: userID,
                timestamp: $0.timestamp,
                usdAmount: $0.usdAmount
            )
        }

        try await supabase
            .from(tableName)
            .upsert(rows, onConflict: "id", returning: .minimal)
            .execute()
    }

    private func authenticatedUserID() async throws -> UUID {
        try await supabase.auth.session.user.id
    }
}
