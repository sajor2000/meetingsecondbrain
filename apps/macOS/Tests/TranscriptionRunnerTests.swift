import Core
import Foundation
import XCTest
@testable import MeetingApp

final class TranscriptionRunnerTests: XCTestCase {
    func testTranscribesMixedAudioAndWritesTranscriptArtifacts() async throws {
        let directory = try makeTemporaryDirectory()
        let audioURL = directory.appendingPathComponent("mixed.m4a")
        try Data("audio".utf8).write(to: audioURL)
        let artifact = RecordingArtifact.testArtifact(
            sessionId: "transcription-test",
            mixedAudioURL: audioURL
        )
        let runner = TranscriptionRunner(
            provider: FakeTranscriptionProvider(),
            clock: FixedTranscriptionClock([
                Date(timeIntervalSince1970: 10),
                Date(timeIntervalSince1970: 12)
            ]).now
        )

        let result = try await runner.transcribe(artifact: artifact)

        XCTAssertEqual(result.transcript.text, "hello from the meeting")
        XCTAssertEqual(result.duration, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.jsonURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.markdownURL.path))

        let markdown = try String(contentsOf: result.markdownURL, encoding: .utf8)
        XCTAssertTrue(markdown.contains("[00:00] Me: hello from the meeting"))
    }

    func testMissingMixedAudioThrows() async {
        let artifact = RecordingArtifact.testArtifact(mixedAudioURL: nil)
        let runner = TranscriptionRunner(provider: FakeTranscriptionProvider())

        do {
            _ = try await runner.transcribe(artifact: artifact)
            XCTFail("Expected missing mixed audio to throw")
        } catch TranscriptionRunnerError.missingMixedAudio {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testMissingAudioFileThrowsWithoutCallingProvider() async throws {
        let directory = try makeTemporaryDirectory()
        let missingURL = directory.appendingPathComponent("missing.m4a")
        let artifact = RecordingArtifact.testArtifact(mixedAudioURL: missingURL)
        let provider = FakeTranscriptionProvider()
        let runner = TranscriptionRunner(provider: provider)

        do {
            _ = try await runner.transcribe(artifact: artifact)
            XCTFail("Expected missing audio file to throw")
        } catch TranscriptionRunnerError.missingAudioFile {
            XCTAssertEqual(provider.callCount, 0)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

final class FakeTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "fake"
    let supportsStreaming = false
    let supportsDiarization = false
    let requiresNetwork = false
    private(set) var callCount = 0

    func startSession(config: TranscriptionConfig) async throws -> TranscriptionSession {
        throw TranscriptionError.streamingUnsupported(provider: name)
    }

    func transcribeBatch(audioURL: URL, config: TranscriptionConfig) async throws -> Transcript {
        callCount += 1
        return Transcript(
            segments: [
                TranscriptSegment(
                    startMs: 0,
                    endMs: 1_500,
                    text: "hello from the meeting",
                    speaker: "Me",
                    confidence: 0.98
                )
            ],
            language: config.language,
            engine: name
        )
    }
}

final class FixedTranscriptionClock {
    private var dates: [Date]

    init(_ dates: [Date]) {
        self.dates = dates
    }

    func now() -> Date {
        if dates.isEmpty {
            return Date(timeIntervalSince1970: 0)
        }
        return dates.removeFirst()
    }
}

private extension RecordingArtifact {
    static func testArtifact(
        sessionId: String = "test-session",
        mixedAudioURL: URL?
    ) -> RecordingArtifact {
        let directoryURL = mixedAudioURL?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(sessionId, isDirectory: true)
        return RecordingArtifact(
            sessionId: sessionId,
            directoryURL: directoryURL,
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 5),
            systemAudioURL: directoryURL.appendingPathComponent("system.m4a"),
            microphoneAudioURL: directoryURL.appendingPathComponent("microphone.caf"),
            mixedAudioURL: mixedAudioURL,
            metadataURL: directoryURL.appendingPathComponent("metadata.json")
        )
    }
}
