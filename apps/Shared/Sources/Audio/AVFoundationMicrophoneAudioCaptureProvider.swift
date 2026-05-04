#if os(macOS)
@preconcurrency import AVFoundation
import Foundation
import RecallOSCore

enum AVFoundationMicrophoneAudioCaptureError: LocalizedError {
    case alreadyRecording
    case notRecording
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "A microphone recording is already active."
        case .notRecording:
            "No microphone recording is active."
        case .applicationSupportUnavailable:
            "Could not create the local recording folder."
        }
    }
}

actor AVFoundationMicrophoneAudioCaptureProvider: AudioCaptureProvider {
    private let fileManager: FileManager
    private let baseDirectory: URL?
    private let clock: @Sendable () -> Date
    private var engine: AVAudioEngine?
    private var currentArtifact: AudioCaptureArtifact?
    private var writer: MicrophoneAudioBufferWriter?
    private var isPaused = false

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        self.clock = clock
    }

    func start(meeting: Meeting) async throws {
        guard engine == nil else {
            throw AVFoundationMicrophoneAudioCaptureError.alreadyRecording
        }

        let startedAt = clock()
        var artifact = try createArtifact(for: meeting, startedAt: startedAt)
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let microphoneURL = try unwrapMicrophoneURL(from: artifact)
        let writer = try MicrophoneAudioBufferWriter(url: microphoneURL, settings: format.settings)

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            writer.write(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            engine.stop()
            writer.finish()
            artifact.errorMessage = error.localizedDescription
            throw error
        }

        self.engine = engine
        self.currentArtifact = artifact
        self.writer = writer
        isPaused = false
    }

    func pause() async throws {
        guard let engine else { return }
        engine.pause()
        isPaused = true
    }

    func resume() async throws {
        guard let engine, isPaused else { return }
        try engine.start()
        isPaused = false
    }

    func stop() async throws -> AudioCaptureArtifact? {
        guard let engine, var artifact = currentArtifact else {
            throw AVFoundationMicrophoneAudioCaptureError.notRecording
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let writeError = writer?.finish()
        self.engine = nil
        currentArtifact = nil
        writer = nil
        isPaused = false

        let endedAt = clock()
        artifact.endedAt = endedAt
        artifact.duration = endedAt.timeIntervalSince(artifact.startedAt)
        artifact.byteSize = byteSize(atPath: artifact.microphoneAudioPath)
        artifact.errorMessage = writeError
        let sizeDiagnostic = artifact.byteSize.map { "microphone.caf \($0) bytes" } ?? "microphone.caf size unavailable"
        artifact.diagnostics = writeError.map { "\(sizeDiagnostic); write error: \($0)" } ?? sizeDiagnostic
        return artifact
    }

    private func createArtifact(for meeting: Meeting, startedAt: Date) throws -> AudioCaptureArtifact {
        let directoryURL = try recordingsDirectory(for: meeting.id, startedAt: startedAt)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let microphoneURL = directoryURL.appendingPathComponent("microphone.caf")

        return AudioCaptureArtifact(
            meetingID: meeting.id,
            startedAt: startedAt,
            microphoneAudioPath: microphoneURL.path,
            diagnostics: "AVFoundation microphone capture"
        )
    }

    private func recordingsDirectory(for meetingID: UUID, startedAt: Date) throws -> URL {
        let sessionID = ISO8601DateFormatter().string(from: startedAt)
            .replacingOccurrences(of: ":", with: "-")
            .appending("-\(UUID().uuidString)")

        return try recordingsRoot()
            .appendingPathComponent(meetingID.uuidString, isDirectory: true)
            .appendingPathComponent(sessionID, isDirectory: true)
    }

    private func recordingsRoot() throws -> URL {
        if let baseDirectory {
            return baseDirectory
        }

        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AVFoundationMicrophoneAudioCaptureError.applicationSupportUnavailable
        }

        return applicationSupport
            .appendingPathComponent("RecallOS", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
    }

    private func unwrapMicrophoneURL(from artifact: AudioCaptureArtifact) throws -> URL {
        guard let path = artifact.microphoneAudioPath else {
            throw AVFoundationMicrophoneAudioCaptureError.applicationSupportUnavailable
        }

        return URL(fileURLWithPath: path)
    }

    private func byteSize(atPath path: String?) -> Int64? {
        guard let path,
              let size = try? fileManager.attributesOfItem(atPath: path)[.size] as? NSNumber else {
            return nil
        }

        return size.int64Value
    }
}

private final class MicrophoneAudioBufferWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var audioFile: AVAudioFile?
    private var writeError: Error?

    init(url: URL, settings: [String: Any]) throws {
        audioFile = try AVAudioFile(forWriting: url, settings: settings)
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        guard writeError == nil else { return }

        do {
            try audioFile?.write(from: buffer)
        } catch {
            writeError = error
        }
    }

    @discardableResult
    func finish() -> String? {
        lock.lock()
        defer { lock.unlock() }

        audioFile = nil
        return writeError?.localizedDescription
    }
}
#endif
