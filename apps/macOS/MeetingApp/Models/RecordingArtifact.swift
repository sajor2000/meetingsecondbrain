import Foundation

struct RecordingArtifact: Identifiable, Equatable, Sendable {
    let id: UUID
    let sessionId: String
    let directoryURL: URL
    let startedAt: Date
    var endedAt: Date?
    var systemAudioURL: URL?
    var microphoneAudioURL: URL?
    var mixedAudioURL: URL?
    var metadataURL: URL?

    init(
        id: UUID = UUID(),
        sessionId: String,
        directoryURL: URL,
        startedAt: Date,
        endedAt: Date? = nil,
        systemAudioURL: URL? = nil,
        microphoneAudioURL: URL? = nil,
        mixedAudioURL: URL? = nil,
        metadataURL: URL? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.directoryURL = directoryURL
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.systemAudioURL = systemAudioURL
        self.microphoneAudioURL = microphoneAudioURL
        self.mixedAudioURL = mixedAudioURL
        self.metadataURL = metadataURL
    }

    var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }
}

struct AudioCaptureActivity: Equatable, Sendable {
    var systemAudioLevel: Double
    var microphoneLevel: Double
    var updatedAt: Date

    static let idle = AudioCaptureActivity(
        systemAudioLevel: 0,
        microphoneLevel: 0,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}
