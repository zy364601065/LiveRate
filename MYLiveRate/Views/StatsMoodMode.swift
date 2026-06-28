import Foundation
import Combine
import Supabase

let statsMoodModeStorageKey = "myliverate.stats.mood_mode"
let luluMoodBehaviorStorageKey = "myliverate.stats.lulu_behavior"
let luluHappyAssetStorageKey = "myliverate.stats.lulu_happy_asset"
let luluBadAssetStorageKey = "myliverate.stats.lulu_bad_asset"
let customStatsMoodModeIDStorageKey = "myliverate.stats.custom_mood_mode_id"
let luluDefaultGIFName = "lulu_default.GIF"
let statsMoodGIFBucketName = "stats-mood-gifs"

enum StatsMoodMode: String, CaseIterable, Identifiable {
    case standard
    case lulu
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return "默认"
        case .lulu:
            return "噜噜"
        case .custom:
            return "自定义"
        }
    }

    var detailText: String {
        switch self {
        case .standard:
            return "延续当前原生绘制表情。"
        case .lulu:
            return "日历底图改用 GIF 表情池。"
        case .custom:
            return "使用你上传的 GIF 表情模式。"
        }
    }
}

enum LuluMoodBehavior: String, CaseIterable, Identifiable {
    case random
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .random:
            return "随机"
        case .manual:
            return "手动"
        }
    }

    var detailText: String {
        switch self {
        case .random:
            return "每次切换到不同日期时，按情绪随机抽一张。"
        case .manual:
            return "盈利和亏损各固定使用你选中的一张。"
        }
    }
}

enum LuluHappyAsset: String, CaseIterable, Identifiable {
    case happy1 = "lulu_happy1.GIF"
    case happy2 = "lulu_happy2.GIF"
    case happy3 = "lulu_happy3.GIF"
    case happy4 = "lulu_happy4.GIF"
    case happy5 = "lulu_happy5.GIF"

    var id: String { rawValue }
    var fileName: String { rawValue }

    var displayName: String {
        switch self {
        case .happy1: return "开心 1"
        case .happy2: return "开心 2"
        case .happy3: return "开心 3"
        case .happy4: return "开心 4"
        case .happy5: return "开心 5"
        }
    }
}

enum LuluBadAsset: String, CaseIterable, Identifiable {
    case bad1 = "lulu_bad1.GIF"
    case bad2 = "lulu_bad2.GIF"
    case bad3 = "lulu_bad3.GIF"
    case bad4 = "lulu_bad4.GIF"
    case bad5 = "lulu_bad5.GIF"

    var id: String { rawValue }
    var fileName: String { rawValue }

    var displayName: String {
        switch self {
        case .bad1: return "沮丧 1"
        case .bad2: return "沮丧 2"
        case .bad3: return "沮丧 3"
        case .bad4: return "沮丧 4"
        case .bad5: return "沮丧 5"
        }
    }
}

enum StatsMoodAssetKind: String, Codable, CaseIterable, Identifiable {
    case defaultAsset = "default"
    case profit
    case loss

    var id: String { rawValue }
}

struct CustomStatsMoodAsset: Identifiable, Equatable {
    let id: UUID
    let modeID: UUID
    let kind: StatsMoodAssetKind
    let sortOrder: Int
    let storagePath: String
    var signedURL: URL?
}

struct CustomStatsMoodMode: Identifiable, Equatable {
    let id: UUID
    var name: String
    var scope: String
    var userID: UUID?
    var behavior: LuluMoodBehavior
    var selectedProfitAssetID: UUID?
    var selectedLossAssetID: UUID?
    var assets: [CustomStatsMoodAsset]

    var defaultAsset: CustomStatsMoodAsset? {
        assets.first { $0.kind == .defaultAsset }
    }

    var profitAssets: [CustomStatsMoodAsset] {
        assets
            .filter { $0.kind == .profit }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var lossAssets: [CustomStatsMoodAsset] {
        assets
            .filter { $0.kind == .loss }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func assets(for kind: StatsMoodAssetKind) -> [CustomStatsMoodAsset] {
        switch kind {
        case .defaultAsset:
            return defaultAsset.map { [$0] } ?? []
        case .profit:
            return profitAssets
        case .loss:
            return lossAssets
        }
    }
}

struct StatsMoodService {
    private struct ModeRow: Codable {
        let id: UUID
        let userId: UUID?
        let scope: String
        let name: String
        let behavior: String
        let selectedProfitAssetId: UUID?
        let selectedLossAssetId: UUID?

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case scope
            case name
            case behavior
            case selectedProfitAssetId = "selected_profit_asset_id"
            case selectedLossAssetId = "selected_loss_asset_id"
        }
    }

    private struct AssetRow: Codable {
        let id: UUID
        let modeId: UUID
        let userId: UUID?
        let kind: String
        let sortOrder: Int
        let storagePath: String

        enum CodingKeys: String, CodingKey {
            case id
            case modeId = "mode_id"
            case userId = "user_id"
            case kind
            case sortOrder = "sort_order"
            case storagePath = "storage_path"
        }
    }

    private let modesTable = "stats_mood_modes"
    private let assetsTable = "stats_mood_assets"

    func fetchModes() async throws -> [CustomStatsMoodMode] {
        let modes: [ModeRow] = try await supabase
            .from(modesTable)
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        let assets: [AssetRow] = try await supabase
            .from(assetsTable)
            .select()
            .order("sort_order", ascending: true)
            .execute()
            .value

        var signedURLByPath: [String: URL] = [:]
        for path in Set(assets.map(\.storagePath)) {
            signedURLByPath[path] = try? await supabase.storage
                .from(statsMoodGIFBucketName)
                .createSignedURL(path: path, expiresIn: 60 * 60 * 24 * 7)
        }

        let assetsByMode = Dictionary(grouping: assets) { $0.modeId }
        return modes.map { mode in
            let modeAssets = (assetsByMode[mode.id] ?? []).compactMap { row -> CustomStatsMoodAsset? in
                guard let kind = StatsMoodAssetKind(rawValue: row.kind) else { return nil }
                return CustomStatsMoodAsset(
                    id: row.id,
                    modeID: row.modeId,
                    kind: kind,
                    sortOrder: row.sortOrder,
                    storagePath: row.storagePath,
                    signedURL: signedURLByPath[row.storagePath]
                )
            }

            return CustomStatsMoodMode(
                id: mode.id,
                name: mode.name,
                scope: mode.scope,
                userID: mode.userId,
                behavior: LuluMoodBehavior(rawValue: mode.behavior) ?? .random,
                selectedProfitAssetID: mode.selectedProfitAssetId,
                selectedLossAssetID: mode.selectedLossAssetId,
                assets: modeAssets
            )
        }
    }
}

@MainActor
final class StatsMoodViewModel: ObservableObject {
    @Published private(set) var customModes: [CustomStatsMoodMode] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service = StatsMoodService()

    func loadModes() async {
        isLoading = true
        errorMessage = nil
        do {
            customModes = try await service.fetchModes()
            log("loadModes: loaded \(customModes.count) custom modes")
        } catch {
            errorMessage = friendlyError(error)
            log("loadModes failed: \(error)")
        }
        isLoading = false
    }

    func mode(id: String) -> CustomStatsMoodMode? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return customModes.first { $0.id == uuid }
    }

    private func friendlyError(_ error: Error) -> String {
        "同步失败：\(error.localizedDescription)"
    }

    private func log(_ message: String) {
        print("[StatsMood] \(message)")
    }
}
