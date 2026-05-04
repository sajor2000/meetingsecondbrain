import Foundation

public struct MeetingScreenshot: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var meetingID: UUID
    public var capturedAt: TimeInterval
    public var storagePath: String
    public var caption: String

    public init(id: UUID = UUID(), convexID: String? = nil, meetingID: UUID, capturedAt: TimeInterval, storagePath: String, caption: String) {
        self.id = id
        self.convexID = convexID
        self.meetingID = meetingID
        self.capturedAt = capturedAt
        self.storagePath = storagePath
        self.caption = caption
    }
}
