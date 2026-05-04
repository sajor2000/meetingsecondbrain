import Foundation

public struct AudioCaptureArtifact: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var meetingID: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var microphoneAudioPath: String?
    public var duration: TimeInterval?
    public var byteSize: Int64?
    public var diagnostics: String
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        convexID: String? = nil,
        meetingID: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        microphoneAudioPath: String? = nil,
        duration: TimeInterval? = nil,
        byteSize: Int64? = nil,
        diagnostics: String = "",
        errorMessage: String? = nil
    ) {
        self.id = id
        self.convexID = convexID
        self.meetingID = meetingID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.microphoneAudioPath = microphoneAudioPath
        self.duration = duration
        self.byteSize = byteSize
        self.diagnostics = diagnostics
        self.errorMessage = errorMessage
    }
}
