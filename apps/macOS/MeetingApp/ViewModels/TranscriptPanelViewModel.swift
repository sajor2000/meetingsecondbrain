import Core
import Foundation

struct TranscriptPanelViewModel: Equatable {
    let rows: [TranscriptPanelRow]

    init(transcript: Transcript?) {
        rows = transcript?.segments.enumerated().map { index, segment in
            TranscriptPanelRow(
                id: index,
                timestamp: Self.formatTimestamp(milliseconds: segment.startMs),
                speaker: segment.speaker,
                text: segment.text
            )
        } ?? []
    }

    var isEmpty: Bool {
        rows.isEmpty
    }

    static func formatTimestamp(milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds / 1_000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct TranscriptPanelRow: Equatable, Identifiable {
    let id: Int
    let timestamp: String
    let speaker: String?
    let text: String
}
