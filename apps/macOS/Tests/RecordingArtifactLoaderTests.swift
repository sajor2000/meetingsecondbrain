import XCTest
@testable import MeetingApp

final class RecordingArtifactLoaderTests: XCTestCase {
    func testLoadsArtifactFromMetadataAndDetectsTranscriptFiles() throws {
        let directory = try makeArtifactDirectory()
        let startedAt = Date(timeIntervalSince1970: 10)
        let endedAt = Date(timeIntervalSince1970: 20)
        let systemURL = try writeFile("system.caf", in: directory)
        let microphoneURL = try writeFile("microphone.caf", in: directory)
        let mixedURL = try writeFile("mixed.m4a", in: directory)
        let transcriptJSONURL = try writeFile("transcript.json", in: directory)
        let transcriptMarkdownURL = try writeFile("transcript.md", in: directory)
        try writeMetadata(
            in: directory,
            sessionId: "loaded-session",
            startedAt: startedAt,
            endedAt: endedAt,
            systemAudioPath: systemURL.path,
            microphoneAudioPath: microphoneURL.path,
            mixedAudioPath: mixedURL.path
        )
        let loader = RecordingArtifactLoader()

        let result = try loader.load(from: directory)

        XCTAssertEqual(result.artifact.sessionId, "loaded-session")
        XCTAssertEqual(result.artifact.startedAt, startedAt)
        XCTAssertEqual(result.artifact.endedAt, endedAt)
        XCTAssertEqual(result.artifact.systemAudioURL, systemURL)
        XCTAssertEqual(result.artifact.microphoneAudioURL, microphoneURL)
        XCTAssertEqual(result.artifact.mixedAudioURL, mixedURL)
        XCTAssertEqual(result.artifact.metadataURL, directory.appendingPathComponent("metadata.json"))
        XCTAssertEqual(result.transcriptJSONURL, transcriptJSONURL)
        XCTAssertEqual(result.transcriptMarkdownURL, transcriptMarkdownURL)
        XCTAssertEqual(result.warnings, [])
    }

    func testInfersStandardFileNamesWhenMetadataIsMissing() throws {
        let directory = try makeArtifactDirectory(sessionId: "folder-session")
        let systemURL = try writeFile("system.caf", in: directory)
        let microphoneURL = try writeFile("microphone.caf", in: directory)
        let mixedURL = try writeFile("mixed.m4a", in: directory)
        let loader = RecordingArtifactLoader()

        let result = try loader.load(from: directory)

        XCTAssertEqual(result.artifact.sessionId, "folder-session")
        XCTAssertEqual(result.artifact.systemAudioURL, systemURL)
        XCTAssertEqual(result.artifact.microphoneAudioURL, microphoneURL)
        XCTAssertEqual(result.artifact.mixedAudioURL, mixedURL)
        XCTAssertNil(result.artifact.metadataURL)
        XCTAssertTrue(result.warnings.contains(.missingMetadata))
        XCTAssertTrue(result.warnings.contains(.missingTranscriptJSON))
        XCTAssertTrue(result.warnings.contains(.missingTranscriptMarkdown))
    }

    func testMissingAudioFilesBecomeRecoverableWarnings() throws {
        let directory = try makeArtifactDirectory()
        try writeMetadata(
            in: directory,
            sessionId: "loaded-session",
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: nil,
            systemAudioPath: directory.appendingPathComponent("missing-system.m4a").path,
            microphoneAudioPath: directory.appendingPathComponent("missing-mic.caf").path,
            mixedAudioPath: directory.appendingPathComponent("missing-mixed.m4a").path
        )
        let loader = RecordingArtifactLoader()

        let result = try loader.load(from: directory)

        XCTAssertNil(result.artifact.systemAudioURL)
        XCTAssertNil(result.artifact.microphoneAudioURL)
        XCTAssertNil(result.artifact.mixedAudioURL)
        XCTAssertTrue(result.warnings.contains(.missingSystemAudio))
        XCTAssertTrue(result.warnings.contains(.missingMicrophoneAudio))
        XCTAssertTrue(result.warnings.contains(.missingMixedAudio))
    }

    func testInfersLegacySystemAudioFileName() throws {
        let directory = try makeArtifactDirectory(sessionId: "legacy-session")
        let systemURL = try writeFile("system.m4a", in: directory)
        let loader = RecordingArtifactLoader()

        let result = try loader.load(from: directory)

        XCTAssertEqual(result.artifact.systemAudioURL, systemURL)
        XCTAssertFalse(result.warnings.contains(.missingSystemAudio))
    }

    func testInvalidMetadataThrowsReadableError() throws {
        let directory = try makeArtifactDirectory()
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("metadata.json"))
        let loader = RecordingArtifactLoader()

        XCTAssertThrowsError(try loader.load(from: directory)) { error in
            guard case RecordingArtifactLoaderError.invalidMetadata = error else {
                return XCTFail("Expected invalid metadata error")
            }
        }
    }

    private func makeArtifactDirectory(sessionId: String = UUID().uuidString) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(sessionId, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    private func writeFile(_ fileName: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(fileName)
        try Data(fileName.utf8).write(to: url)
        return url
    }

    private func writeMetadata(
        in directory: URL,
        sessionId: String,
        startedAt: Date,
        endedAt: Date?,
        systemAudioPath: String?,
        microphoneAudioPath: String?,
        mixedAudioPath: String?
    ) throws {
        let metadata = TestRecordingArtifactMetadata(
            sessionId: sessionId,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: endedAt?.timeIntervalSince(startedAt),
            systemAudioPath: systemAudioPath,
            microphoneAudioPath: microphoneAudioPath,
            mixedAudioPath: mixedAudioPath
        )
        let data = try JSONEncoder.recordingMetadata.encode(metadata)
        try data.write(to: directory.appendingPathComponent("metadata.json"))
    }
}

private struct TestRecordingArtifactMetadata: Encodable {
    let sessionId: String
    let startedAt: Date
    let endedAt: Date?
    let durationSeconds: TimeInterval?
    let systemAudioPath: String?
    let microphoneAudioPath: String?
    let mixedAudioPath: String?
}

private extension JSONEncoder {
    static var recordingMetadata: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
