import Foundation

public struct MeetingDecision: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var title: String
    public var detail: String
    public var sourceMeetingID: UUID
    public var sourceTimestamp: TimeInterval?

    public init(id: UUID = UUID(), convexID: String? = nil, title: String, detail: String, sourceMeetingID: UUID, sourceTimestamp: TimeInterval? = nil) {
        self.id = id
        self.convexID = convexID
        self.title = title
        self.detail = detail
        self.sourceMeetingID = sourceMeetingID
        self.sourceTimestamp = sourceTimestamp
    }
}
