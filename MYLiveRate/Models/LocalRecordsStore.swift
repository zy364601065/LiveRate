import Foundation
import SwiftData

@Model
final class UploadRecordEntity {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var usdAmount: Double

    init(id: UUID, timestamp: Date, usdAmount: Double) {
        self.id = id
        self.timestamp = timestamp
        self.usdAmount = usdAmount
    }
}

@Model
final class HoldingRecordEntity {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var stockName: String
    var stockCode: String?
    var marketValue: Double?
    var quantity: Double?
    var currentPrice: Double?
    var costPrice: Double?
    var todayPnL: Double?
    var todayPnLPercent: Double?
    var holdingPnL: Double?
    var holdingPnLPercent: Double?

    init(
        id: UUID,
        timestamp: Date,
        stockName: String,
        stockCode: String?,
        marketValue: Double?,
        quantity: Double?,
        currentPrice: Double?,
        costPrice: Double?,
        todayPnL: Double?,
        todayPnLPercent: Double?,
        holdingPnL: Double?,
        holdingPnLPercent: Double?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stockName = stockName
        self.stockCode = stockCode
        self.marketValue = marketValue
        self.quantity = quantity
        self.currentPrice = currentPrice
        self.costPrice = costPrice
        self.todayPnL = todayPnL
        self.todayPnLPercent = todayPnLPercent
        self.holdingPnL = holdingPnL
        self.holdingPnLPercent = holdingPnLPercent
    }
}

extension UploadRecordEntity {
    convenience init(record: UploadRecord) {
        self.init(id: record.id, timestamp: record.timestamp, usdAmount: record.usdAmount)
    }

    var dto: UploadRecord {
        UploadRecord(id: id, timestamp: timestamp, usdAmount: usdAmount)
    }

    func apply(_ record: UploadRecord) {
        timestamp = record.timestamp
        usdAmount = record.usdAmount
    }
}

extension HoldingRecordEntity {
    convenience init(record: HoldingRecord) {
        self.init(
            id: record.id,
            timestamp: record.timestamp,
            stockName: record.stockName,
            stockCode: record.stockCode,
            marketValue: record.marketValue,
            quantity: record.quantity,
            currentPrice: record.currentPrice,
            costPrice: record.costPrice,
            todayPnL: record.todayPnL,
            todayPnLPercent: record.todayPnLPercent,
            holdingPnL: record.holdingPnL,
            holdingPnLPercent: record.holdingPnLPercent
        )
    }

    var dto: HoldingRecord {
        HoldingRecord(
            id: id,
            timestamp: timestamp,
            stockName: stockName,
            stockCode: stockCode,
            marketValue: marketValue,
            quantity: quantity,
            currentPrice: currentPrice,
            costPrice: costPrice,
            todayPnL: todayPnL,
            todayPnLPercent: todayPnLPercent,
            holdingPnL: holdingPnL,
            holdingPnLPercent: holdingPnLPercent
        )
    }

    func apply(_ record: HoldingRecord) {
        timestamp = record.timestamp
        stockName = record.stockName
        stockCode = record.stockCode
        marketValue = record.marketValue
        quantity = record.quantity
        currentPrice = record.currentPrice
        costPrice = record.costPrice
        todayPnL = record.todayPnL
        todayPnLPercent = record.todayPnLPercent
        holdingPnL = record.holdingPnL
        holdingPnLPercent = record.holdingPnLPercent
    }
}

@MainActor
final class LocalRecordsStore {
    static let shared = LocalRecordsStore()

    let container: ModelContainer
    private let context: ModelContext

    private let uploadRecordsStorageKey = "myliverate.upload_records.v1"
    private let holdingRecordsStorageKey = "myliverate.holding_records.v1"
    private let migrationFlagStorageKey = "myliverate.swiftdata.local_records_migrated.v1"

    init(inMemory: Bool = false) {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            container = try ModelContainer(
                for: UploadRecordEntity.self,
                HoldingRecordEntity.self,
                configurations: configuration
            )
            context = ModelContext(container)
            context.autosaveEnabled = false
            if !inMemory {
                migrateLegacyDataIfNeeded()
            }
        } catch {
            fatalError("Failed to create LocalRecordsStore container: \(error)")
        }
    }

    func fetchUploadRecords() -> [UploadRecord] {
        let descriptor = FetchDescriptor<UploadRecordEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map(\.dto)
    }

    func upsertUploadRecords(_ records: [UploadRecord]) {
        guard !records.isEmpty else { return }

        let existing = fetchUploadEntitiesByID(Set(records.map(\.id)))
        for record in records {
            if let entity = existing[record.id] {
                entity.apply(record)
            } else {
                context.insert(UploadRecordEntity(record: record))
            }
        }
        saveContext()
    }

    func addUploadRecord(_ record: UploadRecord) {
        upsertUploadRecords([record])
    }

    func fetchHoldingRecords() -> [HoldingRecord] {
        let descriptor = FetchDescriptor<HoldingRecordEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return sortHoldingRecords(entities.map(\.dto))
    }

    func mergeHoldingRecords(_ records: [HoldingRecord]) {
        guard !records.isEmpty else { return }

        var mergedByKey = Dictionary(uniqueKeysWithValues: fetchHoldingRecords().map { (holdingKey(for: $0), $0) })
        for record in records {
            mergedByKey[holdingKey(for: record)] = record
        }

        let merged = sortHoldingRecords(Array(mergedByKey.values))
        replaceAllHoldingRecords(with: merged)
    }

    func removeHoldingRecord(id: UUID) {
        guard let entity = fetchHoldingEntity(id: id) else { return }
        context.delete(entity)
        saveContext()
    }

    func updateHoldingIdentity(id: UUID, newName: String, newCode: String?) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let entity = fetchHoldingEntity(id: id) else { return }

        let trimmedCode = newCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.stockName = trimmedName
        entity.stockCode = (trimmedCode?.isEmpty == true) ? nil : trimmedCode
        saveContext()
    }

    private func migrateLegacyDataIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: migrationFlagStorageKey) == false else { return }

        let legacyUploadRecords = loadLegacyUploadRecords(from: defaults)
        let legacyHoldingRecords = loadLegacyHoldingRecords(from: defaults)

        if !legacyUploadRecords.isEmpty {
            upsertUploadRecords(legacyUploadRecords)
        }

        if !legacyHoldingRecords.isEmpty {
            replaceAllHoldingRecords(with: legacyHoldingRecords)
        }

        defaults.set(true, forKey: migrationFlagStorageKey)
    }

    private func loadLegacyUploadRecords(from defaults: UserDefaults) -> [UploadRecord] {
        guard let data = defaults.data(forKey: uploadRecordsStorageKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = (try? decoder.decode([UploadRecord].self, from: data)) ?? []
        return deduplicated(records).sorted { $0.timestamp < $1.timestamp }
    }

    private func loadLegacyHoldingRecords(from defaults: UserDefaults) -> [HoldingRecord] {
        guard let data = defaults.data(forKey: holdingRecordsStorageKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = (try? decoder.decode([HoldingRecord].self, from: data)) ?? []
        return sortHoldingRecords(deduplicated(records))
    }

    private func deduplicated<T: Identifiable>(_ records: [T]) -> [T] where T.ID: Hashable {
        var seen = Set<T.ID>()
        return records.filter { seen.insert($0.id).inserted }
    }

    private func replaceAllHoldingRecords(with records: [HoldingRecord]) {
        let existingDescriptor = FetchDescriptor<HoldingRecordEntity>()
        let existingEntities = (try? context.fetch(existingDescriptor)) ?? []
        for entity in existingEntities {
            context.delete(entity)
        }

        for record in sortHoldingRecords(records) {
            context.insert(HoldingRecordEntity(record: record))
        }
        saveContext()
    }

    private func fetchUploadEntitiesByID(_ ids: Set<UUID>) -> [UUID: UploadRecordEntity] {
        guard !ids.isEmpty else { return [:] }
        let descriptor = FetchDescriptor<UploadRecordEntity>()
        let entities = ((try? context.fetch(descriptor)) ?? []).filter { ids.contains($0.id) }
        return Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
    }

    private func fetchHoldingEntity(id: UUID) -> HoldingRecordEntity? {
        let descriptor = FetchDescriptor<HoldingRecordEntity>()
        return ((try? context.fetch(descriptor)) ?? []).first { $0.id == id }
    }

    private func holdingKey(for record: HoldingRecord) -> String {
        let source: String
        if let code = record.stockCode, !code.isEmpty {
            source = code
        } else {
            source = record.stockName
        }

        return source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("[LocalRecordsStore] save failed: \(error)")
            context.rollback()
        }
    }
}
