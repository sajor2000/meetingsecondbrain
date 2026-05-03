import Foundation

protocol RecordingArtifactLoading: Sendable {
    func load(from directoryURL: URL) throws -> RecordingArtifactLoadResult
}

struct RecordingArtifactLoadResult: Equatable, Sendable {
    let artifact: RecordingArtifact
    let transcriptJSONURL: URL?
    let transcriptMarkdownURL: URL?
    let warnings: [RecordingArtifactLoadWarning]
}

enum RecordingArtifactLoadWarning: Equatable, LocalizedError, Sendable {
    case missingMetadata
    case missingSystemAudio
    case missingMicrophoneAudio
    case missingMixedAudio
    case missingTranscriptJSON
    case missingTranscriptMarkdown

    var errorDescription: String? {
        switch self {
        case .missingMetadata:
            return "Metadata file is missing."
        case .missingSystemAudio:
            return "System audio file is missing."
        case .missingMicrophoneAudio:
            return "Microphone audio file is missing."
        case .missingMixedAudio:
            return "Mixed audio file is missing."
        case .missingTranscriptJSON:
            return "Transcript JSON file is missing."
        case .missingTranscriptMarkdown:
            return "Transcript markdown file is missing."
        }
    }
}

enum RecordingArtifactLoaderError: Equatable, LocalizedError {
    case folderMissing(String)
    case notDirectory(String)
    case invalidMetadata(String)

    var errorDescription: String? {
        switch self {
        case let .folderMissing(path):
            return "Artifact folder does not exist at \(path)."
        case let .notDirectory(path):
            return "Artifact path is not a folder: \(path)."
        case let .invalidMetadata(message):
            return "Could not read artifact metadata: \(message)"
        }
    }
}

struct RecordingArtifactLoader: RecordingArtifactLoading, @unchecked Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load(from directoryURL: URL) throws -> RecordingArtifactLoadResult {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) else {
            throw RecordingArtifactLoaderError.folderMissing(directoryURL.path)
        }
        guard isDirectory.boolValue else {
            throw RecordingArtifactLoaderError.notDirectory(directoryURL.path)
        }

        var warnings: [RecordingArtifactLoadWarning] = []
        let metadataURL = directoryURL.appendingPathComponent("metadata.json")
        let metadata = try readMetadata(from: metadataURL, warnings: &warnings)
        let startedAt = metadata?.startedAt ?? directoryDate(directoryURL) ?? Date(timeIntervalSince1970: 0)
        let sessionId = metadata?.sessionId ?? directoryURL.lastPathComponent

        let artifact = RecordingArtifact(
            sessionId: sessionId,
            directoryURL: directoryURL,
            startedAt: startedAt,
            endedAt: metadata?.endedAt,
            systemAudioURL: existingURL(
                metadataPath: metadata?.systemAudioPath,
                fallbackName: "system.m4a",
                directoryURL: directoryURL,
                missingWarning: .missingSystemAudio,
                warnings: &warnings
            ),
            microphoneAudioURL: existingURL(
                metadataPath: metadata?.microphoneAudioPath,
                fallbackName: "microphone.caf",
                directoryURL: directoryURL,
                missingWarning: .missingMicrophoneAudio,
                warnings: &warnings
            ),
            mixedAudioURL: existingURL(
                metadataPath: metadata?.mixedAudioPath,
                fallbackName: "mixed.m4a",
                directoryURL: directoryURL,
                missingWarning: .missingMixedAudio,
                warnings: &warnings
            ),
            metadataURL: fileManager.fileExists(atPath: metadataURL.path) ? metadataURL : nil
        )

        return RecordingArtifactLoadResult(
            artifact: artifact,
            transcriptJSONURL: existingURL(
                metadataPath: nil,
                fallbackName: "transcript.json",
                directoryURL: directoryURL,
                missingWarning: .missingTranscriptJSON,
                warnings: &warnings
            ),
            transcriptMarkdownURL: existingURL(
                metadataPath: nil,
                fallbackName: "transcript.md",
                directoryURL: directoryURL,
                missingWarning: .missingTranscriptMarkdown,
                warnings: &warnings
            ),
            warnings: warnings
        )
    }

    private func readMetadata(
        from metadataURL: URL,
        warnings: inout [RecordingArtifactLoadWarning]
    ) throws -> LoadedRecordingArtifactMetadata? {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            warnings.append(.missingMetadata)
            return nil
        }

        do {
            let data = try Data(contentsOf: metadataURL)
            return try JSONDecoder.recordingMetadata.decode(LoadedRecordingArtifactMetadata.self, from: data)
        } catch {
            throw RecordingArtifactLoaderError.invalidMetadata(error.localizedDescription)
        }
    }

    private func existingURL(
        metadataPath: String?,
        fallbackName: String,
        directoryURL: URL,
        missingWarning: RecordingArtifactLoadWarning,
        warnings: inout [RecordingArtifactLoadWarning]
    ) -> URL? {
        let candidates = [
            metadataPath.map(URL.init(fileURLWithPath:)),
            Optional(directoryURL.appendingPathComponent(fallbackName))
        ].compactMap { $0 }

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        warnings.append(missingWarning)
        return nil
    }

    private func directoryDate(_ directoryURL: URL) -> Date? {
        let values = try? directoryURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
    }
}

private struct LoadedRecordingArtifactMetadata: Decodable {
    let sessionId: String
    let startedAt: Date
    let endedAt: Date?
    let systemAudioPath: String?
    let microphoneAudioPath: String?
    let mixedAudioPath: String?
}

private extension JSONDecoder {
    static var recordingMetadata: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
