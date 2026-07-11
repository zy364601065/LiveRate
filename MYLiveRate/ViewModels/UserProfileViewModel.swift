import Combine
import Foundation

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let service = UserProfileService()
    private let nicknameCacheKey = "myliverate.user_profile.nickname.v1"
    private let userIDCacheKey = "myliverate.user_profile.user_id.v1"

    var nickname: String? {
        profile?.nickname ?? cachedNickname
    }

    var userIDText: String {
        profile?.id.uuidString ?? cachedUserID ?? "同步后显示"
    }

    var displayNickname: String {
        nickname ?? "同步中"
    }

    var birthday: String? {
        profile?.birthday
    }

    var birthdayDisplayText: String {
        guard let birthday else { return "未填写" }
        return Self.displayBirthday(from: birthday)
    }

    var canRetry: Bool {
        !isLoading && profile == nil
    }

    func loadOrCreateProfile() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let userID = try await service.authenticatedUserID()
            prepareCacheForCurrentUser(userID)

            if let remoteProfile = try await service.fetchProfile(userID: userID) {
                applyProfile(remoteProfile)
                return
            }

            let profile = try await service.upsertProfile(nickname: Self.makeDefaultNickname(), userID: userID)
            applyProfile(profile)
        } catch {
            logError("loadOrCreateProfile failed", error: error)
            errorMessage = "个人信息同步失败，请稍后重试。"
        }
    }

    func updateNickname(_ nickname: String) async {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidNickname(trimmed) else {
            errorMessage = "昵称需要 1-24 个字符。"
            return
        }

        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let userID = try await service.authenticatedUserID()
            prepareCacheForCurrentUser(userID)
            let updatedProfile = try await service.upsertProfile(nickname: trimmed, birthday: profile?.birthday, userID: userID)
            applyProfile(updatedProfile)
        } catch {
            logError("updateNickname failed", error: error)
            errorMessage = "昵称保存失败，请检查网络后重试。"
        }
    }

    func updateBirthday(_ birthday: String?) async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let userID = try await service.authenticatedUserID()
            prepareCacheForCurrentUser(userID)
            let nickname = profile?.nickname ?? cachedNickname ?? Self.makeDefaultNickname()
            let updatedProfile = try await service.upsertProfile(nickname: nickname, birthday: birthday, userID: userID)
            applyProfile(updatedProfile)
        } catch {
            logError("updateBirthday failed", error: error)
            errorMessage = "生日保存失败，请检查网络后重试。"
        }
    }

    static func isValidNickname(_ nickname: String) -> Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...24).contains(trimmed.count)
    }

    private static func makeDefaultNickname() -> String {
        let digits = (0..<7).map { _ in String(Int.random(in: 0...9)) }.joined()
        return "众安_\(digits)"
    }

    private static func displayBirthday(from birthday: String) -> String {
        guard birthday.count >= 10 else { return birthday }
        let monthDay = birthday.suffix(5).split(separator: "-")
        guard monthDay.count == 2 else { return birthday }
        return "\(Int(monthDay[0]) ?? 0)月\(Int(monthDay[1]) ?? 0)日"
    }

    private func applyProfile(_ profile: UserProfile) {
        self.profile = profile
        cachedNickname = profile.nickname
        cachedUserID = profile.id.uuidString
    }

    private func prepareCacheForCurrentUser(_ userID: UUID) {
        let currentUserID = userID.uuidString
        guard cachedUserID != currentUserID else { return }
        profile = nil
        cachedNickname = nil
        cachedUserID = currentUserID
    }

    private var cachedNickname: String? {
        get {
            UserDefaults.standard.string(forKey: nicknameCacheKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: nicknameCacheKey)
        }
    }

    private var cachedUserID: String? {
        get {
            UserDefaults.standard.string(forKey: userIDCacheKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userIDCacheKey)
        }
    }

    private func logError(_ message: String, error: Error) {
        let nsError = error as NSError
        print("[UserProfile][Error] \(message): domain=\(nsError.domain), code=\(nsError.code), localized=\(nsError.localizedDescription), debug=\(String(describing: error))")
    }
}
