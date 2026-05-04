import Foundation

public struct Topic: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var name: String
    public var meetingIDs: [UUID]

    public init(id: UUID = UUID(), convexID: String? = nil, name: String, meetingIDs: [UUID] = []) {
        self.id = id
        self.convexID = convexID
        self.name = name
        self.meetingIDs = meetingIDs
    }
}
