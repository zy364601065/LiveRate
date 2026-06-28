import Foundation
import Supabase

struct UserProfile: Equatable {
    let id: UUID
    let nickname: String
}

struct UserProfileService {
    private struct UserProfileRow: Codable {
        let id: UUID
        let nickname: String
    }

    private let tableName = "user_profiles"

    func fetchProfile() async throws -> UserProfile? {
        let userID = try await authenticatedUserID()
        return try await fetchProfile(userID: userID)
    }

    func fetchProfile(userID: UUID) async throws -> UserProfile? {
        let rows: [UserProfileRow] = try await supabase
            .from(tableName)
            .select("id,nickname")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            return nil
        }

        return UserProfile(id: row.id, nickname: row.nickname)
    }

    func upsertProfile(nickname: String) async throws -> UserProfile {
        let userID = try await authenticatedUserID()
        return try await upsertProfile(nickname: nickname, userID: userID)
    }

    func upsertProfile(nickname: String, userID: UUID) async throws -> UserProfile {
        let row = UserProfileRow(id: userID, nickname: nickname)

        try await supabase
            .from(tableName)
            .upsert(row, onConflict: "id", returning: .minimal)
            .execute()

        return UserProfile(id: userID, nickname: nickname)
    }

    func authenticatedUserID() async throws -> UUID {
        try await supabase.auth.session.user.id
    }
}
