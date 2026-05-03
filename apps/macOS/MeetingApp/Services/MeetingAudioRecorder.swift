import AVFoundation
import Foundation

protocol MeetingAudioRecording: AnyObject, Sendable {
    var activityStream: AsyncStream<AudioCaptureActivity> { get }

    func start() async throws -> RecordingArtifact
    func stop() async throws -> RecordingArtifact
}

enum MeetingAudioRecorderError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "A recording session is already active."
        case .notRecording:
            return "No recording session is active."
        case .applicationSupportUnavailable:
            return "Could not create the recording folder."
        }
    }
}

final class MeetingAudioRecorder: MeetingAudioRecording, @unchecked Sendable {
    private let systemAudioCapture: SystemAudioCapturing
    private let microphoneCapture: MicrophoneCapturing
    private let artifactStore: RecordingArtifactStore
    private let clock: () -> Date
    private var activityContinuation: AsyncStream<AudioCaptureActivity>.Continuation?
    private var artifact: RecordingArtifact?
    private let activityPublisher = AudioActivityPublisher()

    lazy var activityStream: AsyncStream<AudioCaptureActivity> = {
        AsyncStream { continuation in
            activityContinuation = continuation
        }
    }()

    init(
        systemAudioCapture: SystemAudioCapturing = SystemAudioCaptureEngine(),
        microphoneCapture: MicrophoneCapturing = MicrophoneCaptureEngine(),
        artifactStore: RecordingArtifactStore = RecordingArtifactStore(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.systemAudioCapture = systemAudioCapture
        self.microphoneCapture = microphoneCapture
        self.artifactStore = artifactStore
        self.clock = clock
    }

    func start() async throws -> RecordingArtifact {
        if artifact != nil {
            throw MeetingAudioRecorderError.alreadyRecording
        }

        var newArtifact = try artifactStore.createArtifact(startedAt: clock())
        try await systemAudioCapture.startRecording(to: newArtifact.systemAudioURL) { [weak self] level in
            self?.publish(systemLevel: level, microphoneLevel: nil)
        }

        do {
            try await microphoneCapture.startRecording(to: newArtifact.microphoneAudioURL) { [weak self] level in
                self?.publish(systemLevel: nil, microphoneLevel: level)
            }
        } catch {
            try? await systemAudioCapture.stopRecording()
            throw error
        }

        artifactStore.writeMetadata(for: newArtifact)
        newArtifact.metadataURL = artifactStore.metadataURL(for: newArtifact)
        artifact = newArtifact
        return newArtifact
    }

    func stop() async throws -> RecordingArtifact {
        guard var currentArtifact = artifact else {
            throw MeetingAudioRecorderError.notRecording
        }

        let microphoneStopError: Error?
        do {
            try await microphoneCapture.stopRecording()
            microphoneStopError = nil
        } catch {
            microphoneStopError = error
        }

        let systemStopError: Error?
        do {
            try await systemAudioCapture.stopRecording()
            systemStopError = nil
        } catch {
            systemStopError = error
        }

        currentArtifact.endedAt = clock()
        currentArtifact.mixedAudioURL = try? await AudioFileWriter.mixAudioTracks(
            systemAudioURL: currentArtifact.systemAudioURL,
            microphoneAudioURL: currentArtifact.microphoneAudioURL,
            outputDirectory: currentArtifact.directoryURL
        )
        artifactStore.writeMetadata(for: currentArtifact)
        currentArtifact.metadataURL = artifactStore.metadataURL(for: currentArtifact)
        artifact = nil
        activityPublisher.reset()
        activityContinuation?.yield(.idle)

        if let microphoneStopError {
            throw microphoneStopError
        }
        if let systemStopError {
            throw systemStopError
        }

        return currentArtifact
    }

    private func publish(systemLevel: Double?, microphoneLevel: Double?) {
        let activityContinuation = activityContinuation
        let updatedAt = clock()
        let activity = activityPublisher.update(
            systemLevel: systemLevel,
            microphoneLevel: microphoneLevel,
            updatedAt: updatedAt
        )
        activityContinuation?.yield(activity)
    }
}

private final class AudioActivityPublisher: @unchecked Sendable {
    private let lock = NSLock()
    private var latestActivity = AudioCaptureActivity.idle

    func update(systemLevel: Double?, microphoneLevel: Double?, updatedAt: Date) -> AudioCaptureActivity {
        lock.lock()
        defer {
            lock.unlock()
        }

        latestActivity = AudioCaptureActivity(
            systemAudioLevel: systemLevel ?? latestActivity.systemAudioLevel,
            microphoneLevel: microphoneLevel ?? latestActivity.microphoneLevel,
            updatedAt: updatedAt
        )
        return latestActivity
    }

    func reset() {
        lock.lock()
        defer {
            lock.unlock()
        }

        latestActivity = .idle
    }
}

struct RecordingArtifactStore {
    private let fileManager: FileManager
    private let baseDirectory: URL?

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    func createArtifact(startedAt: Date) throws -> RecordingArtifact {
        let sessionId = ISO8601DateFormatter().string(from: startedAt)
            .replacingOccurrences(of: ":", with: "-")
            .appending("-\(UUID().uuidString)")
        let directoryURL = try recordingsDirectory().appendingPathComponent(sessionId, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        return RecordingArtifact(
            sessionId: sessionId,
            directoryURL: directoryURL,
            startedAt: startedAt,
            systemAudioURL: directoryURL.appendingPathComponent("system.caf"),
            microphoneAudioURL: directoryURL.appendingPathComponent("microphone.caf"),
            metadataURL: directoryURL.appendingPathComponent("metadata.json")
        )
    }

    func metadataURL(for artifact: RecordingArtifact) -> URL {
        artifact.directoryURL.appendingPathComponent("metadata.json")
    }

    func writeMetadata(for artifact: RecordingArtifact) {
        let metadata = RecordingArtifactMetadata(artifact: artifact)
        guard let data = try? JSONEncoder.recordingMetadata.encode(metadata) else {
            return
        }
        try? data.write(to: metadataURL(for: artifact), options: .atomic)
    }

    private func recordingsDirectory() throws -> URL {
        if let baseDirectory {
            return baseDirectory
        }

        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw MeetingAudioRecorderError.applicationSupportUnavailable
        }

        let directory = applicationSupport
            .appendingPathComponent("MeetingSecondBrain", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct RecordingArtifactMetadata: Codable {
    let sessionId: String
    let startedAt: Date
    let endedAt: Date?
    let durationSeconds: TimeInterval?
    let systemAudioPath: String?
    let microphoneAudioPath: String?
    let mixedAudioPath: String?

    init(artifact: RecordingArtifact) {
        sessionId = artifact.sessionId
        startedAt = artifact.startedAt
        endedAt = artifact.endedAt
        durationSeconds = artifact.duration
        systemAudioPath = artifact.systemAudioURL?.path
        microphoneAudioPath = artifact.microphoneAudioURL?.path
        mixedAudioPath = artifact.mixedAudioURL?.path
    }
}

private extension JSONEncoder {
    static var recordingMetadata: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
