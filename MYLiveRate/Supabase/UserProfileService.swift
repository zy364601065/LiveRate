import Foundation
import Supabase

struct UserProfile: Equatable {
    let id: UUID
    let nickname: String
    let birthday: String?
}

struct UserProfileService {
    private struct UserProfileRow: Codable {
        let id: UUID
        let nickname: String
        let birthday: String?
    }

    private struct NicknameUpsertRow: Codable {
        let id: UUID
        let nickname: String
    }

    private struct ProfileUpsertRow: Codable {
        let id: UUID
        let nickname: String
        let birthday: String?
    }

    private let tableName = "user_profiles"

    func fetchProfile() async throws -> UserProfile? {
        let userID = try await authenticatedUserID()
        return try await fetchProfile(userID: userID)
    }

    func fetchProfile(userID: UUID) async throws -> UserProfile? {
        let rows: [UserProfileRow] = try await supabase
            .from(tableName)
            .select("id,nickname,birthday")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            return nil
        }

        return UserProfile(id: row.id, nickname: row.nickname, birthday: row.birthday)
    }

    func upsertProfile(nickname: String) async throws -> UserProfile {
        let userID = try await authenticatedUserID()
        return try await upsertProfile(nickname: nickname, userID: userID)
    }

    func upsertProfile(nickname: String, userID: UUID) async throws -> UserProfile {
        let row = NicknameUpsertRow(id: userID, nickname: nickname)

        try await supabase
            .from(tableName)
            .upsert(row, onConflict: "id", returning: .minimal)
            .execute()

        let currentProfile = try? await fetchProfile(userID: userID)
        return UserProfile(id: userID, nickname: nickname, birthday: currentProfile?.birthday)
    }

    func upsertProfile(nickname: String, birthday: String?, userID: UUID) async throws -> UserProfile {
        let row = ProfileUpsertRow(id: userID, nickname: nickname, birthday: birthday)

        try await supabase
            .from(tableName)
            .upsert(row, onConflict: "id", returning: .minimal)
            .execute()

        return UserProfile(id: userID, nickname: nickname, birthday: birthday)
    }

    func authenticatedUserID() async throws -> UUID {
        try await supabase.auth.session.user.id
    }
}
