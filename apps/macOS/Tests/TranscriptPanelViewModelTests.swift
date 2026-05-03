import Core
import XCTest
@testable import MeetingApp

final class TranscriptPanelViewModelTests: XCTestCase {
    func testNilTranscriptBuildsEmptyRows() {
        let viewModel = TranscriptPanelViewModel(transcript: nil)

        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertEqual(viewModel.rows, [])
    }

    func testFormatsTimestampsLikeMarkdownRenderer() {
        XCTAssertEqual(TranscriptPanelViewModel.formatTimestamp(milliseconds: 0), "00:00")
        XCTAssertEqual(TranscriptPanelViewModel.formatTimestamp(milliseconds: 61_000), "01:01")
        XCTAssertEqual(TranscriptPanelViewModel.formatTimestamp(milliseconds: 3_600_000), "60:00")
    }

    func testRowsPreserveSpeakerAndText() {
        let transcript = Transcript(
            segments: [
                TranscriptSegment(startMs: 0, endMs: 1_000, text: "Hello", speaker: "Me"),
                TranscriptSegment(startMs: 1_000, endMs: 2_000, text: "No speaker")
            ],
            engine: "fake"
        )

        let viewModel = TranscriptPanelViewModel(transcript: transcript)

        XCTAssertEqual(viewModel.rows[0].speaker, "Me")
        XCTAssertEqual(viewModel.rows[0].text, "Hello")
        XCTAssertNil(viewModel.rows[1].speaker)
        XCTAssertEqual(viewModel.rows[1].text, "No speaker")
    }

    func testRowsFollowTranscriptTimelineOrder() {
        let transcript = Transcript(
            segments: [
                TranscriptSegment(startMs: 2_000, endMs: 3_000, text: "Second"),
                TranscriptSegment(startMs: 0, endMs: 1_000, text: "First")
            ],
            engine: "fake"
        )

        let viewModel = TranscriptPanelViewModel(transcript: transcript)

        XCTAssertEqual(viewModel.rows.map(\.text), ["First", "Second"])
        XCTAssertEqual(viewModel.rows.map(\.timestamp), ["00:00", "00:02"])
    }

    func testDuplicateRowsStillReceiveUniqueIdentities() {
        let transcript = Transcript(
            segments: [
                TranscriptSegment(startMs: 0, endMs: 1_000, text: "Same", speaker: "Me"),
                TranscriptSegment(startMs: 0, endMs: 1_000, text: "Same", speaker: "Me")
            ],
            engine: "fake"
        )

        let viewModel = TranscriptPanelViewModel(transcript: transcript)

        XCTAssertEqual(Set(viewModel.rows.map(\.id)).count, 2)
    }
}
