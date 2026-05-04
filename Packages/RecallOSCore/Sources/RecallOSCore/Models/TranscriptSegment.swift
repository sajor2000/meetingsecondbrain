import Foundation

public struct TranscriptSegment: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var meetingID: UUID
    public var speaker: Person
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var text: String
    public var confidence: Double

    public init(
        id: UUID = UUID(),
        convexID: String? = nil,
        meetingID: UUID,
        speaker: Person,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        confidence: Double
    ) {
        self.id = id
        self.convexID = convexID
        self.meetingID = meetingID
        self.speaker = speaker
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
    }
}
