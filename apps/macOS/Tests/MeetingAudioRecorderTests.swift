import Foundation
import XCTest
@testable import MeetingApp

final class MeetingAudioRecorderTests: XCTestCase {
    func testRecorderStartsBothCaptureEnginesAndWritesMetadata() async throws {
        let directory = try makeTemporaryDirectory()
        let systemCapture = FakeSystemAudioCapture()
        let microphoneCapture = FakeMicrophoneCapture()
        let recorder = MeetingAudioRecorder(
            systemAudioCapture: systemCapture,
            microphoneCapture: microphoneCapture,
            artifactStore: RecordingArtifactStore(baseDirectory: directory),
            clock: FixedClock([
                Date(timeIntervalSince1970: 1),
                Date(timeIntervalSince1970: 1.5),
                Date(timeIntervalSince1970: 1.75),
                Date(timeIntervalSince1970: 3)
            ]).now
        )

        let artifact = try await recorder.start()

        XCTAssertTrue(systemCapture.didStart)
        XCTAssertTrue(microphoneCapture.didStart)
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact.metadataURL?.path ?? ""))

        let completedArtifact = try await recorder.stop()

        XCTAssertTrue(systemCapture.didStop)
        XCTAssertTrue(microphoneCapture.didStop)
        XCTAssertEqual(completedArtifact.duration, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: completedArtifact.metadataURL?.path ?? ""))
    }

    func testStopAttemptsBothEnginesWhenMicrophoneStopFails() async throws {
        let directory = try makeTemporaryDirectory()
        let systemCapture = FakeSystemAudioCapture()
        let microphoneCapture = FakeMicrophoneCapture(errorOnStop: TestCaptureError.expected)
        let recorder = MeetingAudioRecorder(
            systemAudioCapture: systemCapture,
            microphoneCapture: microphoneCapture,
            artifactStore: RecordingArtifactStore(baseDirectory: directory)
        )

        _ = try await recorder.start()

        do {
            _ = try await recorder.stop()
            XCTFail("Expected stop to throw")
        } catch TestCaptureError.expected {
            XCTAssertTrue(microphoneCapture.didStop)
            XCTAssertTrue(systemCapture.didStop)
        }
    }

    func testStopAttemptsBothEnginesWhenSystemStopFails() async throws {
        let directory = try makeTemporaryDirectory()
        let systemCapture = FakeSystemAudioCapture(errorOnStop: TestCaptureError.expected)
        let microphoneCapture = FakeMicrophoneCapture()
        let recorder = MeetingAudioRecorder(
            systemAudioCapture: systemCapture,
            microphoneCapture: microphoneCapture,
            artifactStore: RecordingArtifactStore(baseDirectory: directory)
        )

        _ = try await recorder.start()

        do {
            _ = try await recorder.stop()
            XCTFail("Expected stop to throw")
        } catch TestCaptureError.expected {
            XCTAssertTrue(microphoneCapture.didStop)
            XCTAssertTrue(systemCapture.didStop)
        }
    }

    func testArtifactsCreatedInSameSecondUseDifferentSessionDirectories() throws {
        let directory = try makeTemporaryDirectory()
        let store = RecordingArtifactStore(baseDirectory: directory)
        let startedAt = Date(timeIntervalSince1970: 1)

        let first = try store.createArtifact(startedAt: startedAt)
        let second = try store.createArtifact(startedAt: startedAt)

        XCTAssertNotEqual(first.sessionId, second.sessionId)
        XCTAssertNotEqual(first.directoryURL, second.directoryURL)
    }

    func testActivityUpdatesPreserveOtherChannelLevel() async throws {
        let directory = try makeTemporaryDirectory()
        let systemCapture = FakeSystemAudioCapture()
        let microphoneCapture = FakeMicrophoneCapture()
        let recorder = MeetingAudioRecorder(
            systemAudioCapture: systemCapture,
            microphoneCapture: microphoneCapture,
            artifactStore: RecordingArtifactStore(baseDirectory: directory),
            clock: FixedClock([
                Date(timeIntervalSince1970: 1),
                Date(timeIntervalSince1970: 1.25),
                Date(timeIntervalSince1970: 1.5)
            ]).now
        )
        var iterator = recorder.activityStream.makeAsyncIterator()

        _ = try await recorder.start()

        var activities: [AudioCaptureActivity] = []
        while activities.count < 2 {
            if let activity = await iterator.next() {
                activities.append(activity)
            }
        }

        XCTAssertTrue(activities.contains(AudioCaptureActivity(
            systemAudioLevel: 0.5,
            microphoneLevel: 0,
            updatedAt: Date(timeIntervalSince1970: 1.25)
        )))
        XCTAssertTrue(activities.contains(AudioCaptureActivity(
            systemAudioLevel: 0.5,
            microphoneLevel: 0.4,
            updatedAt: Date(timeIntervalSince1970: 1.5)
        )))
    }

    func testSystemCaptureFailurePreventsMicrophoneStart() async throws {
        let directory = try makeTemporaryDirectory()
        let systemCapture = FakeSystemAudioCapture(errorOnStart: TestCaptureError.expected)
        let microphoneCapture = FakeMicrophoneCapture()
        let recorder = MeetingAudioRecorder(
            systemAudioCapture: systemCapture,
            microphoneCapture: microphoneCapture,
            artifactStore: RecordingArtifactStore(baseDirectory: directory)
        )

        do {
            _ = try await recorder.start()
            XCTFail("Expected start to throw")
        } catch TestCaptureError.expected {
            XCTAssertFalse(microphoneCapture.didStart)
        }
    }

    func testMicrophoneCaptureFailureStopsSystemCapture() async throws {
        let directory = try makeTemporaryDirectory()
        let systemCapture = FakeSystemAudioCapture()
        let microphoneCapture = FakeMicrophoneCapture(errorOnStart: TestCaptureError.expected)
        let recorder = MeetingAudioRecorder(
            systemAudioCapture: systemCapture,
            microphoneCapture: microphoneCapture,
            artifactStore: RecordingArtifactStore(baseDirectory: directory)
        )

        do {
            _ = try await recorder.start()
            XCTFail("Expected start to throw")
        } catch TestCaptureError.expected {
            XCTAssertTrue(systemCapture.didStart)
            XCTAssertTrue(systemCapture.didStop)
        }
    }

    func testStopWithoutRecordingThrows() async {
        let recorder = MeetingAudioRecorder(
            systemAudioCapture: FakeSystemAudioCapture(),
            microphoneCapture: FakeMicrophoneCapture()
        )

        do {
            _ = try await recorder.stop()
            XCTFail("Expected stop to throw")
        } catch MeetingAudioRecorderError.notRecording {
            XCTAssertTrue(true)
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

final class FakeSystemAudioCapture: SystemAudioCapturing {
    private let errorOnStart: Error?
    private let errorOnStop: Error?
    private(set) var didStart = false
    private(set) var didStop = false

    init(errorOnStart: Error? = nil, errorOnStop: Error? = nil) {
        self.errorOnStart = errorOnStart
        self.errorOnStop = errorOnStop
    }

    func startRecording(to fileURL: URL?, activityHandler: @escaping (Double) -> Void) async throws {
        if let errorOnStart {
            throw errorOnStart
        }
        didStart = true
        activityHandler(0.5)
    }

    func stopRecording() async throws {
        didStop = true
        if let errorOnStop {
            throw errorOnStop
        }
    }
}

final class FakeMicrophoneCapture: MicrophoneCapturing {
    private let errorOnStart: Error?
    private let errorOnStop: Error?
    private(set) var didStart = false
    private(set) var didStop = false

    init(errorOnStart: Error? = nil, errorOnStop: Error? = nil) {
        self.errorOnStart = errorOnStart
        self.errorOnStop = errorOnStop
    }

    func startRecording(to fileURL: URL?, activityHandler: @escaping (Double) -> Void) async throws {
        if let errorOnStart {
            throw errorOnStart
        }
        didStart = true
        activityHandler(0.4)
    }

    func stopRecording() async throws {
        didStop = true
        if let errorOnStop {
            throw errorOnStop
        }
    }
}

enum TestCaptureError: Error {
    case expected
}

final class FixedClock {
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
