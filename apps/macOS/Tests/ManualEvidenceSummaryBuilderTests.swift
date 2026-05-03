import Core
import XCTest
@testable import MeetingApp

final class ManualEvidenceSummaryBuilderTests: XCTestCase {
    func testBuildsEvidenceSummaryWithAudioAndTranscriptPaths() {
        let artifact = RecordingArtifact.testArtifact(
            sessionId: "evidence-session",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 125)
        )
        let transcriptionArtifact = TranscriptionArtifact(
            transcript: Transcript(engine: "fake"),
            jsonURL: artifact.directoryURL.appendingPathComponent("transcript.json"),
            markdownURL: artifact.directoryURL.appendingPathComponent("transcript.md"),
            startedAt: Date(timeIntervalSince1970: 200),
            completedAt: Date(timeIntervalSince1970: 205)
        )
        let rows = [
            AudioInspectionRow.fixture(kind: .system, url: artifact.systemAudioURL, byteSize: 1_024, duration: 125),
            AudioInspectionRow.fixture(kind: .microphone, url: artifact.microphoneAudioURL, byteSize: 2_048, duration: 124),
            AudioInspectionRow.fixture(kind: .mixed, url: artifact.mixedAudioURL, byteSize: 4_096, duration: 125)
        ]

        let summary = ManualEvidenceSummaryBuilder().build(
            artifact: artifact,
            audioRows: rows,
            loadResult: nil,
            transcriptionArtifact: transcriptionArtifact
        )

        XCTAssertTrue(summary.contains("## Phase 2 Evidence"))
        XCTAssertTrue(summary.contains("- Session ID: evidence-session"))
        XCTAssertTrue(summary.contains("- Recording duration: 02:05"))
        XCTAssertTrue(summary.contains("- System audio: present, 02:05"))
        XCTAssertTrue(summary.contains(artifact.systemAudioURL?.path ?? "missing"))
        XCTAssertTrue(summary.contains("- Transcript JSON: \(transcriptionArtifact.jsonURL.path)"))
        XCTAssertTrue(summary.contains("- System audio audible:"))
    }

    func testBuildsEvidenceSummaryWithLoadWarningsAndMissingFiles() {
        var artifact = RecordingArtifact.testArtifact()
        artifact.mixedAudioURL = nil
        let loadResult = RecordingArtifactLoadResult(
            artifact: artifact,
            transcriptJSONURL: nil,
            transcriptMarkdownURL: nil,
            warnings: [.missingMixedAudio, .missingTranscriptJSON]
        )

        let summary = ManualEvidenceSummaryBuilder().build(
            artifact: artifact,
            audioRows: [
                .fixture(kind: .system, url: artifact.systemAudioURL),
                .fixture(kind: .microphone, url: artifact.microphoneAudioURL),
                .fixture(kind: .mixed, url: nil, exists: false)
            ],
            loadResult: loadResult,
            transcriptionArtifact: nil
        )

        XCTAssertTrue(summary.contains("- Mixed audio: missing"))
        XCTAssertTrue(summary.contains("- Transcript JSON: missing"))
        XCTAssertTrue(summary.contains("### Warnings"))
        XCTAssertTrue(summary.contains("- Mixed audio file is missing."))
        XCTAssertTrue(summary.contains("- Transcript JSON file is missing."))
    }
}

private extension AudioInspectionRow {
    static func fixture(
        kind: AudioArtifactKind,
        url: URL?,
        exists: Bool = true,
        byteSize: Int64 = 1_024,
        duration: TimeInterval = 60
    ) -> AudioInspectionRow {
        AudioInspectionRow(
            kind: kind,
            url: url,
            exists: exists,
            byteSize: exists ? byteSize : nil,
            duration: exists ? duration : nil,
            modifiedAt: exists ? Date(timeIntervalSince1970: 1_000) : nil,
            isPlaying: false
        )
    }
}
