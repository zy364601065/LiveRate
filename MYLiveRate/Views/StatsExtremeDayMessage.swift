import Combine
import Foundation
import Supabase

enum StatsTrendTrigger: String, CaseIterable {
    case consecutiveLoss = "consecutive_loss"
    case consecutiveProfit = "consecutive_profit"
    case lossToProfit = "loss_to_profit"
    case profitToLoss = "profit_to_loss"
}

struct StatsTrendMessage: Identifiable, Equatable {
    let id: UUID
    let scope: String
    let userID: UUID?
    let trigger: StatsTrendTrigger
    let message: String
    let isEnabled: Bool
    let sortOrder: Int
    let createdAt: Date
}

struct StatsTrendMessageService {
    private struct MessageRow: Codable {
        let id: UUID
        let scope: String
        let userId: UUID?
        let triggerType: String
        let message: String
        let isEnabled: Bool
        let sortOrder: Int
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case scope
            case userId = "user_id"
            case triggerType = "trigger_type"
            case message
            case isEnabled = "is_enabled"
            case sortOrder = "sort_order"
            case createdAt = "created_at"
        }
    }

    private let tableName = "stats_trend_messages"

    func fetchMessages() async throws -> [StatsTrendMessage] {
        let currentUserID = try await supabase.auth.session.user.id

        let rows: [MessageRow] = try await supabase
            .from(tableName)
            .select()
            .eq("is_enabled", value: true)
            .order("sort_order", ascending: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.compactMap { row in
            guard let trigger = StatsTrendTrigger(rawValue: row.triggerType) else { return nil }
            return StatsTrendMessage(
                id: row.id,
                scope: row.scope,
                userID: row.userId,
                trigger: trigger,
                message: row.message,
                isEnabled: row.isEnabled,
                sortOrder: row.sortOrder,
                createdAt: row.createdAt
            )
        }
        .sorted { lhs, rhs in
            let lhsPriority = lhs.userID == currentUserID ? 0 : 1
            let rhsPriority = rhs.userID == currentUserID ? 0 : 1
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

@MainActor
final class StatsTrendMessageViewModel: ObservableObject {
    @Published private(set) var messages: [StatsTrendMessage] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service = StatsTrendMessageService()

    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        do {
            messages = try await service.fetchMessages()
            log("loadMessages: loaded \(messages.count) trend messages")
        } catch {
            errorMessage = error.localizedDescription
            messages = []
            log("loadMessages failed: \(error)")
        }
        isLoading = false
    }

    func randomMessage(for trigger: StatsTrendTrigger, excluding excludedID: UUID? = nil) -> StatsTrendMessage? {
        let candidates = messages.filter { $0.trigger == trigger && $0.isEnabled }
        let userCandidates = candidates.filter { $0.userID != nil }
        let preferredCandidates = userCandidates.isEmpty ? candidates : userCandidates
        if let excludedID {
            let alternatives = preferredCandidates.filter { $0.id != excludedID }
            if let alternative = alternatives.randomElement() {
                return alternative
            }
        }
        if let remote = preferredCandidates.randomElement() { return remote }
        return Self.fallbackMessages[trigger]?.randomElement()
    }

    private func log(_ message: String) {
        print("[StatsTrendMessage] \(message)")
    }

    private static let fallbackMessages: [StatsTrendTrigger: [StatsTrendMessage]] = {
        let copy: [StatsTrendTrigger: [String]] = [
            .consecutiveLoss: ["绿绿更健康，只要我不卖，这就只是数字的艺术。", "行情总在绝望中诞生，再坚持一下。"],
            .consecutiveProfit: ["你最近的手感热得发烫！", "顺风局请保持冷静，别忘了分批止盈。"],
            .lossToProfit: ["阳线改变信仰，属于你的主场回来了！", "触底反弹，守得云开见月明。"],
            .profitToLoss: ["今天只是利润的小小回撤，稳住心态。", "昨天的盈利是底气，今天的调整是伏笔。"]
        ]
        return copy.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value.enumerated().map { index, value in
                StatsTrendMessage(id: UUID(), scope: "fallback", userID: nil, trigger: entry.key, message: value, isEnabled: true, sortOrder: index, createdAt: .distantPast)
            }
        }
    }()
}
