import Foundation
import Core

#if canImport(FluidAudio)
import FluidAudio
#endif

public struct ParakeetProvider: TranscriptionProvider {
    public let name = "parakeet"
    public let supportsStreaming = false
    public let supportsDiarization = false
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

        let timedTokens = result.tokenTimings?.map {
            ParakeetTimedToken(
                token: $0.token,
                startMs: max(0, Int(($0.startTime * 1000).rounded())),
                endMs: max(0, Int(($0.endTime * 1000).rounded())),
                confidence: Double($0.confidence)
            )
        }

        return ParakeetTranscriptMapper.transcript(
            text: text,
            durationMs: durationMs,
            confidence: confidence,
            tokenTimings: timedTokens,
            language: config.language,
            engine: "parakeet",
            createdAt: Date()
        )
    }
}
#endif

public struct ParakeetTimedToken: Equatable, Sendable {
    public var token: String
    public var startMs: Int
    public var endMs: Int
    public var confidence: Double

    public init(token: String, startMs: Int, endMs: Int, confidence: Double) {
        self.token = token
        self.startMs = max(0, startMs)
        self.endMs = max(max(0, startMs), endMs)
        self.confidence = confidence
    }
}

public enum ParakeetTranscriptMapper {
    public static func transcript(
        text: String,
        durationMs: Int,
        confidence: Double,
        tokenTimings: [ParakeetTimedToken]?,
        language: String,
        engine: String,
        createdAt: Date = Date()
    ) -> Transcript {
        let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let tokenTimings, !tokenTimings.isEmpty else {
            return Transcript(
                segments: trimmedText.isEmpty ? [] : [
                    TranscriptSegment(
                        startMs: 0,
                        endMs: durationMs,
                        text: trimmedText,
                        confidence: confidence,
                        isFinal: true
                    )
                ],
                language: language,
                engine: engine,
                createdAt: createdAt
            )
        }

        var segments: [TranscriptSegment] = []
        var currentText = ""
        var currentStartMs: Int?
        var currentEndMs = 0
        var confidenceTotal = 0.0
        var confidenceCount = 0

        func finishSegment() {
            let segmentText = currentText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !segmentText.isEmpty, let startMs = currentStartMs else {
                currentText = ""
                currentStartMs = nil
                currentEndMs = 0
                confidenceTotal = 0
                confidenceCount = 0
                return
            }

            segments.append(
                TranscriptSegment(
                    startMs: startMs,
                    endMs: max(startMs, currentEndMs),
                    text: segmentText,
                    confidence: confidenceCount > 0 ? confidenceTotal / Double(confidenceCount) : nil,
                    isFinal: true
                )
            )
            currentText = ""
            currentStartMs = nil
            currentEndMs = 0
            confidenceTotal = 0
            confidenceCount = 0
        }

        for token in tokenTimings {
            let normalizedToken = normalizeToken(token.token)
            guard !normalizedToken.isEmpty else {
                continue
            }

            if currentStartMs != nil, token.startMs - currentEndMs > 1_500 {
                finishSegment()
                currentStartMs = token.startMs
            } else if currentStartMs == nil {
                currentStartMs = token.startMs
            }

            currentText += normalizedToken
            currentEndMs = max(currentEndMs, token.endMs)
            confidenceTotal += token.confidence
            confidenceCount += 1

            let duration = currentEndMs - (currentStartMs ?? token.startMs)
            if shouldEndSegment(after: normalizedToken) || duration >= 15_000 {
                finishSegment()
            }
        }

        finishSegment()

        let fallbackSegments = trimmedText.isEmpty ? [] : [
            TranscriptSegment(
                startMs: 0,
                endMs: durationMs,
                text: trimmedText,
                confidence: confidence,
                isFinal: true
            )
        ]

        return Transcript(
            segments: segments.isEmpty ? fallbackSegments : segments,
            language: language,
            engine: engine,
            createdAt: createdAt
        )
    }

    private static func normalizeToken(_ token: String) -> String {
        token
            .replacingOccurrences(of: "▁", with: " ")
            .replacingOccurrences(of: "<unk>", with: "")
    }

    private static func shouldEndSegment(after token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")
    }
}
