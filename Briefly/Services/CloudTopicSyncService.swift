import Foundation
import CloudKit

protocol CloudTopicSyncing: Sendable {
    func fetchState() async throws -> CloudTopicState?
    func saveState(_ state: CloudTopicState) async throws
    func ensureChangeSubscription() async
}

struct CloudTopicState: Equatable, Sendable {
    let userPacks: [TopicPackDTO]
    let orderedTopicIDs: [String]
}

actor CloudTopicSyncService: CloudTopicSyncing {
    static let shared = CloudTopicSyncService()
    nonisolated static let changeSubscriptionID = "briefly.user-topic-state.db-subscription"

    private let database: CKDatabase
    private let recordType = "BrieflyUserTopicState"
    private let recordID = CKRecord.ID(recordName: "primary")
    private let payloadKey = "payload"
    private let orderKey = "orderedTopicIDs"
    private let updatedAtKey = "updatedAt"

    enum SyncError: LocalizedError {
        case missingPayload

        var errorDescription: String? {
            switch self {
            case .missingPayload:
                return "iCloud payload was missing."
            }
        }
    }

    init(container: CKContainer = CKContainer(identifier: "iCloud.dn.Briefly")) {
        self.database = container.privateCloudDatabase
    }

    func fetchState() async throws -> CloudTopicState? {
        do {
            let record = try await database.record(for: recordID)
            guard let asset = record[payloadKey] as? CKAsset else { return nil }
            let data = try dataFromAsset(asset)
            let decodedPacks = try JSONDecoder().decode([TopicPackDTO].self, from: data)
            let orderedTopicIDs = record[orderKey] as? [String] ?? []
            return CloudTopicState(userPacks: decodedPacks, orderedTopicIDs: orderedTopicIDs)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func saveState(_ state: CloudTopicState) async throws {
        let data = try JSONEncoder().encode(state.userPacks)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("briefly_user_content_\(UUID().uuidString).json")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        record[payloadKey] = CKAsset(fileURL: temporaryURL)
        record[orderKey] = state.orderedTopicIDs as CKRecordValue
        record[updatedAtKey] = Date() as CKRecordValue
        _ = try await database.save(record)
    }

    func ensureChangeSubscription() async {
        let subscription = CKDatabaseSubscription(subscriptionID: Self.changeSubscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await database.save(subscription)
        } catch {
            return
        }
    }

    private func dataFromAsset(_ asset: CKAsset) throws -> Data {
        guard let fileURL = asset.fileURL else { throw SyncError.missingPayload }
        return try Data(contentsOf: fileURL)
    }
}
