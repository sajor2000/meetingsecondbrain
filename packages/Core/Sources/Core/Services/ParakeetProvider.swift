import Foundation

#if canImport(FluidAudio)
import FluidAudio
#endif

public struct ParakeetProvider: TranscriptionProvider {
    public let name = "parakeet"
    public let supportsStreaming = false
    public let supportsDiarization = true
    public let requiresNetwork = false

    private let engineFactory: @Sendable (TranscriptionConfig) async throws -> ParakeetTranscribing
    private let fileExists: @Sendable (URL) -> Bool

    public init(
        engineFactory: @escaping @Sendable (TranscriptionConfig) async throws -> ParakeetTranscribing = ParakeetProvider.makeDefaultEngine(config:),
        fileExists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) {
        self.engineFactory = engineFactory
        self.fileExists = fileExists
    }

    public func startSession(config: TranscriptionConfig) async throws -> TranscriptionSession {
        throw TranscriptionError.streamingUnsupported(provider: name)
    }

    public func transcribeBatch(audioURL: URL, config: TranscriptionConfig = .english) async throws -> Transcript {
        guard fileExists(audioURL) else {
            throw TranscriptionError.audioFileMissing(audioURL.path)
        }

        let engine = try await engineFactory(config)
        return try await engine.transcribe(audioURL: audioURL, config: config)
    }

    public static func makeDefaultEngine(config: TranscriptionConfig) async throws -> ParakeetTranscribing {
        #if canImport(FluidAudio)
        return try await FluidAudioParakeetEngine(config: config)
        #else
        throw TranscriptionError.providerUnavailable("FluidAudio is not linked into this build.")
        #endif
    }
}

public protocol ParakeetTranscribing: Sendable {
    func transcribe(audioURL: URL, config: TranscriptionConfig) async throws -> Transcript
}

#if canImport(FluidAudio)
private actor FluidAudioParakeetEngine: ParakeetTranscribing {
    private let manager: AsrManager

    init(config: TranscriptionConfig) async throws {
        let version = ParakeetModelManager.modelVersion(forLanguage: config.language)
        let models = try await AsrModels.downloadAndLoad(version: version)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.manager = manager
    }

    func transcribe(audioURL: URL, config: TranscriptionConfig) async throws -> Transcript {
        var decoderState = try TdtDecoderState()
        let result = try await manager.transcribe(audioURL, decoderState: &decoderState)
        let durationMs = max(0, Int((result.duration * 1000).rounded()))
        let confidence = Double(result.confidence)
        let text = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        let segment = TranscriptSegment(
            startMs: 0,
            endMs: durationMs,
            text: text,
            confidence: confidence,
            isFinal: true
        )

        return Transcript(
            segments: text.isEmpty ? [] : [segment],
            language: config.language,
            engine: "parakeet",
            createdAt: Date()
        )
    }
}
#endif
