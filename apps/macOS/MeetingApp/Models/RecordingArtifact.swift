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
    var captureDiagnostics: RecordingCaptureDiagnostics

    init(
        id: UUID = UUID(),
        sessionId: String,
        directoryURL: URL,
        startedAt: Date,
        endedAt: Date? = nil,
        systemAudioURL: URL? = nil,
        microphoneAudioURL: URL? = nil,
        mixedAudioURL: URL? = nil,
        metadataURL: URL? = nil,
        captureDiagnostics: RecordingCaptureDiagnostics = .empty
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
        self.captureDiagnostics = captureDiagnostics
    }

    var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }
}

struct RecordingCaptureDiagnostics: Codable, Equatable, Sendable {
    var systemSampleCount: Int
    var systemWrittenSampleCount: Int
    var systemAppendFailureCount: Int
    var lastSystemAppendError: String?
    var mix: RecordingMixDiagnostics?

    static let empty = RecordingCaptureDiagnostics(
        systemSampleCount: 0,
        systemWrittenSampleCount: 0,
        systemAppendFailureCount: 0,
        lastSystemAppendError: nil,
        mix: nil
    )
}

struct RecordingMixDiagnostics: Codable, Equatable, Sendable {
    var attempted: Bool
    var inputFileCount: Int
    var insertedTrackCount: Int
    var skippedInputCount: Int
    var lastInputError: String?
    var outputPath: String?
    var exportStatus: String?
    var exportError: String?

    static let notAttempted = RecordingMixDiagnostics(
        attempted: false,
        inputFileCount: 0,
        insertedTrackCount: 0,
        skippedInputCount: 0,
        lastInputError: nil,
        outputPath: nil,
        exportStatus: nil,
        exportError: nil
    )
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
