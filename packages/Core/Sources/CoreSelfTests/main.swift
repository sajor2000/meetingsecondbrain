import Core
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

expect(CoreModule().name == "Core", "CoreModule should provide the default module name")
expect(CoreModule().defaultTranscriptionEngine == "parakeet", "CoreModule should expose Parakeet as the default transcription engine")

let unsortedTranscript = Transcript(
    segments: [
        TranscriptSegment(startMs: 2_000, endMs: 3_000, text: "second", speaker: "Them"),
        TranscriptSegment(startMs: 0, endMs: 1_000, text: "first", speaker: "Me")
    ],
    engine: "test"
)
expect(unsortedTranscript.durationMs == 3_000, "Transcript duration should derive from the final segment end time")
expect(unsortedTranscript.segments.map(\.text) == ["first", "second"], "Transcript segments should sort by timeline")
expect(unsortedTranscript.text == "first\nsecond", "Transcript text should join segments in timeline order")
expect(unsortedTranscript.segments.first?.speaker == "Me", "Transcript should preserve speaker labels")

let partialSegment = TranscriptSegment(startMs: 0, endMs: 500, text: "partial", isFinal: false)
let mixedTranscript = Transcript(
    segments: [
        partialSegment,
        TranscriptSegment(startMs: 500, endMs: 1_000, text: "final")
    ],
    engine: "test"
)
expect(mixedTranscript.partialSegments == [partialSegment], "Transcript should expose partial segments")
expect(mixedTranscript.finalizedSegments.count == 1, "Transcript should expose finalized segments")

let defaultConfig = TranscriptionConfig.english
expect(defaultConfig.language == "en", "Default transcription config should use English")
expect(defaultConfig.enableDiarization, "Default transcription config should enable diarization")
expect(defaultConfig.vocabularyHints.isEmpty, "Default transcription config should start without vocabulary hints")

print("CoreSelfTests passed")
