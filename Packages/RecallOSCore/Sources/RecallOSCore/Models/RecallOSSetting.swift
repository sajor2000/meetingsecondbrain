import Foundation

public struct RecallOSSetting: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var key: String
    public var value: String
    public var updatedAt: Date

    public init(id: UUID = UUID(), convexID: String? = nil, key: String, value: String, updatedAt: Date = Date()) {
        self.id = id
        self.convexID = convexID
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}
