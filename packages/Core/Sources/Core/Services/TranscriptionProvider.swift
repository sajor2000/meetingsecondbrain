import AVFoundation
import Foundation

public protocol TranscriptionProvider: Sendable {
    var name: String { get }
    var supportsStreaming: Bool { get }
    var supportsDiarization: Bool { get }
    var requiresNetwork: Bool { get }

    func startSession(config: TranscriptionConfig) async throws -> TranscriptionSession
    func transcribeBatch(audioURL: URL, config: TranscriptionConfig) async throws -> Transcript
}

public struct TranscriptionConfig: Equatable, Sendable {
    public var language: String
    public var vocabularyHints: [String]
    public var enableDiarization: Bool

    public init(
        language: String = "en",
        vocabularyHints: [String] = [],
        enableDiarization: Bool = true
    ) {
        self.language = language
        self.vocabularyHints = vocabularyHints
        self.enableDiarization = enableDiarization
    }

    public static let english = TranscriptionConfig()
}

public protocol TranscriptionSession: Sendable {
    func append(audioBuffer: AVAudioPCMBuffer) async
    func partialTranscript() async -> Transcript
    func finish() async throws -> Transcript
}

public enum TranscriptionError: Error, Equatable, LocalizedError, Sendable {
    case streamingUnsupported(provider: String)
    case audioFileMissing(String)
    case providerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case let .streamingUnsupported(provider):
            return "\(provider) does not support streaming transcription yet."
        case let .audioFileMissing(path):
            return "Audio file does not exist at \(path)."
        case let .providerUnavailable(reason):
            return reason
        }
    }
}
