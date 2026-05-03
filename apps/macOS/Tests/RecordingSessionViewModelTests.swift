import XCTest
@testable import MeetingApp

@MainActor
final class RecordingSessionViewModelTests: XCTestCase {
    func testStartWithPermissionsBeginsRecordingAndCapturesLatency() async {
        let artifact = RecordingArtifact.testArtifact()
        let recorder = FakeMeetingAudioRecorder(startArtifact: artifact)
        let viewModel = RecordingSessionViewModel(
            permissionService: FakeCapturePermissionService(.authorized),
            recorderFactory: { recorder },
            clock: IncrementingClock().now
        )

        await viewModel.start()

        guard case let .recording(snapshot) = viewModel.state else {
            return XCTFail("Expected recording state")
        }

        XCTAssertEqual(snapshot.sessionId, artifact.sessionId)
        XCTAssertEqual(recorder.startCallCount, 1)
        XCTAssertNotNil(viewModel.lastStartLatency)
        XCTAssertFalse(viewModel.canStart)
        XCTAssertTrue(viewModel.canStop)
    }

    func testDeniedMicrophoneFailsWithMicrophoneReason() async {
        let viewModel = RecordingSessionViewModel(
            permissionService: FakeCapturePermissionService(
                CapturePermissionSnapshot(
                    microphone: .denied,
                    screenRecording: .authorized
                )
            ),
            recorderFactory: { FakeMeetingAudioRecorder() }
        )

        await viewModel.start()

        XCTAssertEqual(viewModel.state, .failed(.microphonePermissionDenied))
    }

    func testDeniedScreenRecordingFailsWithScreenRecordingReason() async {
        let viewModel = RecordingSessionViewModel(
            permissionService: FakeCapturePermissionService(
                CapturePermissionSnapshot(
                    microphone: .authorized,
                    screenRecording: .denied
                )
            ),
            recorderFactory: { FakeMeetingAudioRecorder() }
        )

        await viewModel.start()

        XCTAssertEqual(viewModel.state, .failed(.screenRecordingPermissionDenied))
    }

    func testStopFromIdleIsNoOp() async {
        let viewModel = RecordingSessionViewModel(
            permissionService: FakeCapturePermissionService(.authorized),
            recorderFactory: { FakeMeetingAudioRecorder() }
        )

        await viewModel.stop()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testDoubleStartWhileRecordingDoesNotCreateSecondSession() async {
        var factoryCallCount = 0
        let recorder = FakeMeetingAudioRecorder()
        let viewModel = RecordingSessionViewModel(
            permissionService: FakeCapturePermissionService(.authorized),
            recorderFactory: {
                factoryCallCount += 1
                return recorder
            }
        )

        await viewModel.start()
        await viewModel.start()

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertEqual(recorder.startCallCount, 1)
    }

    func testCompletedRecordingExposesArtifactAfterStop() async {
        let artifact = RecordingArtifact.testArtifact()
        let completedArtifact = RecordingArtifact.testArtifact(endedAt: Date(timeIntervalSince1970: 10))
        let recorder = FakeMeetingAudioRecorder(
            startArtifact: artifact,
            stopArtifact: completedArtifact
        )
        let viewModel = RecordingSessionViewModel(
            permissionService: FakeCapturePermissionService(.authorized),
            recorderFactory: { recorder }
        )

        await viewModel.start()
        await viewModel.stop()

        XCTAssertEqual(viewModel.state, .completed(completedArtifact))
        XCTAssertEqual(viewModel.completedArtifact, completedArtifact)
        XCTAssertTrue(viewModel.canStart)
        XCTAssertFalse(viewModel.canStop)
    }

    func testCompletedArtifactIsNilBeforeRecordingCompletes() async {
        let viewModel = RecordingSessionViewModel(
            permissionService: FakeCapturePermissionService(.authorized),
            recorderFactory: { FakeMeetingAudioRecorder() }
        )

        XCTAssertNil(viewModel.completedArtifact)

        await viewModel.start()

        XCTAssertNil(viewModel.completedArtifact)
    }
}

struct FakeCapturePermissionService: CapturePermissionChecking, Sendable {
    let snapshot: CapturePermissionSnapshot

    init(_ status: CapturePermissionStatus) {
        snapshot = CapturePermissionSnapshot(
            microphone: status,
            screenRecording: status
        )
    }

    init(_ snapshot: CapturePermissionSnapshot) {
        self.snapshot = snapshot
    }

    func checkPermissions() async -> CapturePermissionSnapshot {
        snapshot
    }
}

final class FakeMeetingAudioRecorder: MeetingAudioRecording, @unchecked Sendable {
    private let startArtifact: RecordingArtifact
    private let stopArtifact: RecordingArtifact
    private var continuation: AsyncStream<AudioCaptureActivity>.Continuation?
    private(set) var startCallCount = 0

    lazy var activityStream: AsyncStream<AudioCaptureActivity> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    init(
        startArtifact: RecordingArtifact = .testArtifact(),
        stopArtifact: RecordingArtifact = .testArtifact(endedAt: Date(timeIntervalSince1970: 5))
    ) {
        self.startArtifact = startArtifact
        self.stopArtifact = stopArtifact
    }

    func start() async throws -> RecordingArtifact {
        startCallCount += 1
        continuation?.yield(AudioCaptureActivity(
            systemAudioLevel: 0.5,
            microphoneLevel: 0.4,
            updatedAt: Date(timeIntervalSince1970: 1)
        ))
        return startArtifact
    }

    func stop() async throws -> RecordingArtifact {
        stopArtifact
    }
}

final class IncrementingClock {
    private var value: TimeInterval = 0

    func now() -> Date {
        defer {
            value += 0.25
        }
        return Date(timeIntervalSince1970: value)
    }
}

extension RecordingArtifact {
    static func testArtifact(
        sessionId: String = "test-session",
        startedAt: Date = Date(timeIntervalSince1970: 0),
        endedAt: Date? = nil
    ) -> RecordingArtifact {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(sessionId, isDirectory: true)
        return RecordingArtifact(
            sessionId: sessionId,
            directoryURL: directoryURL,
            startedAt: startedAt,
            endedAt: endedAt,
            systemAudioURL: directoryURL.appendingPathComponent("system.m4a"),
            microphoneAudioURL: directoryURL.appendingPathComponent("microphone.caf"),
            mixedAudioURL: directoryURL.appendingPathComponent("mixed.m4a"),
            metadataURL: directoryURL.appendingPathComponent("metadata.json")
        )
    }
}
