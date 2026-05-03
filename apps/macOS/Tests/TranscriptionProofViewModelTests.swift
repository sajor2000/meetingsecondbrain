import Core
import Foundation
import XCTest
@testable import MeetingApp

@MainActor
final class TranscriptionProofViewModelTests: XCTestCase {
    func testCompletedRecordingStartsTranscriptionAndReachesCompletedState() async {
        let artifact = RecordingArtifact.testArtifact()
        let transcriptionArtifact = TranscriptionArtifact.testArtifact()
        let runner = FakeTranscriptionRunner(result: .success(transcriptionArtifact))
        let viewModel = TranscriptionProofViewModel(runner: runner)

        await viewModel.transcribe(artifact: artifact)

        XCTAssertEqual(runner.callCount, 1)
        XCTAssertEqual(viewModel.state, .completed(artifact, transcriptionArtifact))
        XCTAssertEqual(viewModel.completedArtifact, transcriptionArtifact)
        XCTAssertTrue(viewModel.canTranscribe)
        XCTAssertEqual(viewModel.statusText, "Transcription complete")
    }

    func testMissingMixedAudioSurfacesFailureAndKeepsRecordingArtifact() async {
        var artifact = RecordingArtifact.testArtifact()
        artifact.mixedAudioURL = nil
        let runner = FakeTranscriptionRunner(result: .failure(TranscriptionRunnerError.missingMixedAudio))
        let viewModel = TranscriptionProofViewModel(runner: runner)

        await viewModel.transcribe(artifact: artifact)

        XCTAssertEqual(viewModel.state, .failed(artifact, .missingMixedAudio))
        XCTAssertEqual(viewModel.statusText, "Recording artifact does not have a mixed audio file.")
        XCTAssertTrue(viewModel.canTranscribe)
    }

    func testCanTranscribeRequiresMixedAudioURL() {
        let runner = FakeTranscriptionRunner(result: .success(.testArtifact()))
        let viewModel = TranscriptionProofViewModel(runner: runner)
        let artifact = RecordingArtifact.testArtifact()

        XCTAssertTrue(viewModel.canTranscribe(artifact: artifact))
        XCTAssertNil(viewModel.unavailableReason(for: artifact))
    }

    func testUnavailableReasonExplainsMissingMixedAudioURL() {
        let runner = FakeTranscriptionRunner(result: .success(.testArtifact()))
        let viewModel = TranscriptionProofViewModel(runner: runner)
        var artifact = RecordingArtifact.testArtifact()
        artifact.mixedAudioURL = nil

        XCTAssertFalse(viewModel.canTranscribe(artifact: artifact))
        XCTAssertEqual(viewModel.unavailableReason(for: artifact), "Mixed audio file is required.")
    }

    func testProviderFailureSurfacesFailureAndKeepsRecordingArtifact() async {
        let artifact = RecordingArtifact.testArtifact()
        let runner = FakeTranscriptionRunner(result: .failure(TestTranscriptionError.modelSetupFailed))
        let viewModel = TranscriptionProofViewModel(runner: runner)

        await viewModel.transcribe(artifact: artifact)

        XCTAssertEqual(viewModel.state, .failed(artifact, .transcriptionFailed("Model setup failed.")))
        XCTAssertEqual(viewModel.statusText, "Model setup failed.")
    }

    func testResetClearsCompletedState() async {
        let artifact = RecordingArtifact.testArtifact()
        let transcriptionArtifact = TranscriptionArtifact.testArtifact()
        let runner = FakeTranscriptionRunner(result: .success(transcriptionArtifact))
        let viewModel = TranscriptionProofViewModel(runner: runner)

        await viewModel.transcribe(artifact: artifact)
        viewModel.reset()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNil(viewModel.completedArtifact)
    }

    func testDuplicateTranscribeWhileRunningDoesNotStartSecondRun() async {
        let artifact = RecordingArtifact.testArtifact()
        let transcriptionArtifact = TranscriptionArtifact.testArtifact()
        let runner = BlockingTranscriptionRunner()
        let viewModel = TranscriptionProofViewModel(runner: runner)

        let task = Task {
            await viewModel.transcribe(artifact: artifact)
        }
        await Task.yield()

        await viewModel.transcribe(artifact: artifact)

        let callCount = await runner.calls()
        XCTAssertEqual(callCount, 1)

        await runner.complete(with: transcriptionArtifact)
        await task.value

        XCTAssertEqual(viewModel.state, .completed(artifact, transcriptionArtifact))
    }
}

private final class FakeTranscriptionRunner: TranscriptionRunning, @unchecked Sendable {
    private let result: Result<TranscriptionArtifact, Error>
    private(set) var callCount = 0

    init(result: Result<TranscriptionArtifact, Error>) {
        self.result = result
    }

    func transcribe(
        artifact: RecordingArtifact,
        config: TranscriptionConfig
    ) async throws -> TranscriptionArtifact {
        callCount += 1
        return try result.get()
    }
}

private actor BlockingTranscriptionRunner: TranscriptionRunning {
    private var callCount = 0
    private var continuation: CheckedContinuation<TranscriptionArtifact, Error>?

    func transcribe(
        artifact: RecordingArtifact,
        config: TranscriptionConfig
    ) async throws -> TranscriptionArtifact {
        callCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func calls() -> Int {
        callCount
    }

    func complete(with artifact: TranscriptionArtifact) {
        continuation?.resume(returning: artifact)
        continuation = nil
    }
}

private enum TestTranscriptionError: LocalizedError {
    case modelSetupFailed

    var errorDescription: String? {
        "Model setup failed."
    }
}

private extension TranscriptionArtifact {
    static func testArtifact(
        transcript: Transcript = Transcript(
            segments: [
                TranscriptSegment(startMs: 0, endMs: 1_000, text: "hello", speaker: "Me")
            ],
            engine: "fake"
        )
    ) -> TranscriptionArtifact {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return TranscriptionArtifact(
            transcript: transcript,
            jsonURL: directory.appendingPathComponent("transcript.json"),
            markdownURL: directory.appendingPathComponent("transcript.md"),
            startedAt: Date(timeIntervalSince1970: 0),
            completedAt: Date(timeIntervalSince1970: 2)
        )
    }
}
