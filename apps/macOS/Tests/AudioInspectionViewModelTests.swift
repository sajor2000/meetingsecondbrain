import XCTest
@testable import MeetingApp

@MainActor
final class AudioInspectionViewModelTests: XCTestCase {
    func testLoadBuildsRowsForRecordingArtifact() {
        let artifact = RecordingArtifact.testArtifact()
        let inspector = FakeAudioFileInspector(rows: [
            .system: AudioInspectionRow.fixture(kind: .system, url: artifact.systemAudioURL),
            .microphone: AudioInspectionRow.fixture(kind: .microphone, url: artifact.microphoneAudioURL),
            .mixed: AudioInspectionRow.fixture(kind: .mixed, url: artifact.mixedAudioURL)
        ])
        let viewModel = AudioInspectionViewModel(
            inspector: inspector,
            player: FakeAudioFilePlayer()
        )

        viewModel.load(artifact: artifact)

        XCTAssertEqual(viewModel.rows.map(\.kind), [.system, .microphone, .mixed])
        XCTAssertEqual(viewModel.rows.map(\.exists), [true, true, true])
    }

    func testTogglePlaybackStartsSelectedRowAndStopsOthers() {
        let artifact = RecordingArtifact.testArtifact()
        let player = FakeAudioFilePlayer()
        let viewModel = AudioInspectionViewModel(
            inspector: FakeAudioFileInspector(rows: [
                .system: AudioInspectionRow.fixture(kind: .system, url: artifact.systemAudioURL),
                .microphone: AudioInspectionRow.fixture(kind: .microphone, url: artifact.microphoneAudioURL),
                .mixed: AudioInspectionRow.fixture(kind: .mixed, url: artifact.mixedAudioURL)
            ]),
            player: player
        )
        viewModel.load(artifact: artifact)

        viewModel.togglePlayback(for: viewModel.rows[1])

        XCTAssertEqual(player.playedURLs, [artifact.microphoneAudioURL])
        XCTAssertEqual(viewModel.rows.map(\.isPlaying), [false, true, false])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testTogglePlaybackForMissingRowSurfacesError() {
        let artifact = RecordingArtifact.testArtifact()
        let viewModel = AudioInspectionViewModel(
            inspector: FakeAudioFileInspector(rows: [
                .system: AudioInspectionRow.fixture(kind: .system, url: artifact.systemAudioURL),
                .microphone: AudioInspectionRow.fixture(kind: .microphone, url: nil, exists: false),
                .mixed: AudioInspectionRow.fixture(kind: .mixed, url: artifact.mixedAudioURL)
            ]),
            player: FakeAudioFilePlayer()
        )
        viewModel.load(artifact: artifact)

        viewModel.togglePlayback(for: viewModel.rows[1])

        XCTAssertEqual(viewModel.errorMessage, "Mic audio file is missing.")
        XCTAssertEqual(viewModel.rows.map(\.isPlaying), [false, false, false])
    }

    func testStopClearsPlayingState() {
        let artifact = RecordingArtifact.testArtifact()
        let player = FakeAudioFilePlayer()
        let viewModel = AudioInspectionViewModel(
            inspector: FakeAudioFileInspector(rows: [
                .system: AudioInspectionRow.fixture(kind: .system, url: artifact.systemAudioURL),
                .microphone: AudioInspectionRow.fixture(kind: .microphone, url: artifact.microphoneAudioURL),
                .mixed: AudioInspectionRow.fixture(kind: .mixed, url: artifact.mixedAudioURL)
            ]),
            player: player
        )
        viewModel.load(artifact: artifact)
        viewModel.togglePlayback(for: viewModel.rows[0])

        viewModel.stop()

        XCTAssertEqual(player.stopCallCount, 2)
        XCTAssertEqual(viewModel.rows.map(\.isPlaying), [false, false, false])
    }

    func testPlaybackFinishClearsPlayingState() async {
        let artifact = RecordingArtifact.testArtifact()
        let player = FakeAudioFilePlayer()
        let viewModel = AudioInspectionViewModel(
            inspector: FakeAudioFileInspector(rows: [
                .system: AudioInspectionRow.fixture(kind: .system, url: artifact.systemAudioURL),
                .microphone: AudioInspectionRow.fixture(kind: .microphone, url: artifact.microphoneAudioURL),
                .mixed: AudioInspectionRow.fixture(kind: .mixed, url: artifact.mixedAudioURL)
            ]),
            player: player
        )
        viewModel.load(artifact: artifact)
        viewModel.togglePlayback(for: viewModel.rows[2])

        player.finish()
        await Task.yield()

        XCTAssertEqual(viewModel.rows.map(\.isPlaying), [false, false, false])
    }
}

private struct FakeAudioFileInspector: AudioFileInspecting {
    let rows: [AudioArtifactKind: AudioInspectionRow]

    func inspect(kind: AudioArtifactKind, url: URL?) -> AudioInspectionRow {
        rows[kind] ?? .fixture(kind: kind, url: url, exists: false)
    }
}

private final class FakeAudioFilePlayer: AudioFilePlaying, @unchecked Sendable {
    private(set) var playedURLs: [URL] = []
    private(set) var stopCallCount = 0
    private(set) var currentURL: URL?
    var onFinish: (@Sendable () -> Void)?

    func play(url: URL) throws {
        playedURLs.append(url)
        currentURL = url
    }

    func stop() {
        stopCallCount += 1
        currentURL = nil
    }

    func finish() {
        currentURL = nil
        onFinish?()
    }
}

private extension AudioInspectionRow {
    static func fixture(
        kind: AudioArtifactKind,
        url: URL?,
        exists: Bool = true
    ) -> AudioInspectionRow {
        AudioInspectionRow(
            kind: kind,
            url: url,
            exists: exists,
            byteSize: exists ? 1_024 : nil,
            duration: exists ? 62 : nil,
            modifiedAt: exists ? Date(timeIntervalSince1970: 1_000) : nil,
            isPlaying: false
        )
    }
}
