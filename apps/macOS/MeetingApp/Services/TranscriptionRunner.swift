import Core
import Foundation

enum TranscriptionRunnerError: Error, Equatable, LocalizedError {
    case missingMixedAudio
    case missingAudioFile(String)

    var errorDescription: String? {
        switch self {
        case .missingMixedAudio:
            return "Recording artifact does not have a mixed audio file."
        case let .missingAudioFile(path):
            return "Audio file does not exist at \(path)."
        }
    }
}

struct TranscriptionArtifact: Equatable {
    let transcript: Transcript
    let jsonURL: URL
    let markdownURL: URL
    let startedAt: Date
    let completedAt: Date

    var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
}

struct TranscriptionRunner {
    private let provider: any TranscriptionProvider
    private let fileManager: FileManager
    private let clock: () -> Date

    init(
        provider: any TranscriptionProvider = ParakeetProvider(),
        fileManager: FileManager = .default,
        clock: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.fileManager = fileManager
        self.clock = clock
    }

    func transcribe(
        artifact: RecordingArtifact,
        config: TranscriptionConfig = .english
    ) async throws -> TranscriptionArtifact {
        guard let audioURL = artifact.mixedAudioURL else {
            throw TranscriptionRunnerError.missingMixedAudio
        }
        guard fileManager.fileExists(atPath: audioURL.path) else {
            throw TranscriptionRunnerError.missingAudioFile(audioURL.path)
        }

        let startedAt = clock()
        let transcript = try await provider.transcribeBatch(audioURL: audioURL, config: config)
        let completedAt = clock()

        let jsonURL = artifact.directoryURL.appendingPathComponent("transcript.json")
        let markdownURL = artifact.directoryURL.appendingPathComponent("transcript.md")
        try write(transcript: transcript, jsonURL: jsonURL, markdownURL: markdownURL)

        return TranscriptionArtifact(
            transcript: transcript,
            jsonURL: jsonURL,
            markdownURL: markdownURL,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }

    private func write(transcript: Transcript, jsonURL: URL, markdownURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(transcript)
        try data.write(to: jsonURL, options: .atomic)

        let markdown = TranscriptMarkdownRenderer().render(transcript)
        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
    }
}

struct TranscriptMarkdownRenderer {
    func render(_ transcript: Transcript) -> String {
        var lines = [
            "# Transcript",
            "",
            "Engine: \(transcript.engine)",
            "Language: \(transcript.language)",
            ""
        ]

        for segment in transcript.segments {
            let timestamp = Self.formatTimestamp(milliseconds: segment.startMs)
            let speakerPrefix = segment.speaker.map { "\($0): " } ?? ""
            lines.append("[\(timestamp)] \(speakerPrefix)\(segment.text)")
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func formatTimestamp(milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds / 1_000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
