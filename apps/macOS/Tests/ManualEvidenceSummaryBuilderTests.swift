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
        var diagnosticArtifact = artifact
        diagnosticArtifact.captureDiagnostics = RecordingCaptureDiagnostics(
            systemSampleCount: 12,
            systemWrittenSampleCount: 11,
            systemAppendFailureCount: 1,
            lastSystemAppendError: "copy failed",
            mix: RecordingMixDiagnostics(
                attempted: true,
                inputFileCount: 2,
                insertedTrackCount: 1,
                skippedInputCount: 1,
                lastInputError: "system.caf: unreadable",
                outputPath: artifact.mixedAudioURL?.path,
                exportStatus: "failed",
                exportError: "track rejected"
            )
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
            artifact: diagnosticArtifact,
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
        XCTAssertTrue(summary.contains("### Evidence Checklist"))
        XCTAssertTrue(summary.contains("- [PASS] System audio: present, 02:05"))
        XCTAssertTrue(summary.contains("- [PASS] Microphone audio: present, 02:04"))
        XCTAssertTrue(summary.contains("- [PASS] Mixed audio: present, 02:05"))
        XCTAssertTrue(summary.contains("- [PASS] Metadata: \(artifact.metadataURL?.path ?? "missing")"))
        XCTAssertTrue(summary.contains("- [PASS] Transcript JSON: \(transcriptionArtifact.jsonURL.path)"))
        XCTAssertTrue(summary.contains("- [PASS] Transcript markdown: \(transcriptionArtifact.markdownURL.path)"))
        XCTAssertTrue(summary.contains("- System samples seen: 12"))
        XCTAssertTrue(summary.contains("- Last mix input error: system.caf: unreadable"))
        XCTAssertTrue(summary.contains("- Mix export status: failed"))
        XCTAssertTrue(summary.contains("- Mix export error: track rejected"))
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
        XCTAssertTrue(summary.contains("- [FAIL] Mixed audio: missing URL"))
        XCTAssertTrue(summary.contains("- [FAIL] Transcript JSON: missing URL"))
        XCTAssertTrue(summary.contains("- [FAIL] Transcript markdown: missing URL"))
        XCTAssertTrue(summary.contains("### Warnings"))
        XCTAssertTrue(summary.contains("- Mixed audio file is missing."))
        XCTAssertTrue(summary.contains("- Transcript JSON file is missing."))
    }

    func testBuildChecksRequireAudioInspectionRows() {
        let artifact = RecordingArtifact.testArtifact()

        let checks = ManualEvidenceSummaryBuilder().buildChecks(
            artifact: artifact,
            audioRows: [],
            loadResult: nil,
            transcriptionArtifact: nil
        )

        XCTAssertEqual(checks.first { $0.label == "System audio" }?.passed, false)
        XCTAssertEqual(checks.first { $0.label == "Microphone audio" }?.passed, false)
        XCTAssertEqual(checks.first { $0.label == "Mixed audio" }?.passed, false)
        XCTAssertEqual(checks.first { $0.label == "Metadata" }?.passed, true)
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
