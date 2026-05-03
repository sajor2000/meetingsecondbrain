import Core
import Foundation
import ParakeetTranscription

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

expect(ParakeetModelManager.modelChoice(forLanguage: "en") == .englishV2, "English should select Parakeet v2")
expect(ParakeetModelManager.modelChoice(forLanguage: "en-US") == .englishV2, "English locale should select Parakeet v2")
expect(ParakeetModelManager.modelChoice(forLanguage: "fr") == .multilingualV3, "Non-English should select Parakeet v3")

let mappedTranscript = ParakeetTranscriptMapper.transcript(
    text: "Hello world. Next topic.",
    durationMs: 4_000,
    confidence: 0.9,
    tokenTimings: [
        ParakeetTimedToken(token: "▁Hello", startMs: 120, endMs: 300, confidence: 0.95),
        ParakeetTimedToken(token: "▁world", startMs: 300, endMs: 700, confidence: 0.93),
        ParakeetTimedToken(token: ".", startMs: 700, endMs: 740, confidence: 0.98),
        ParakeetTimedToken(token: "▁Next", startMs: 2_100, endMs: 2_350, confidence: 0.91),
        ParakeetTimedToken(token: "▁topic", startMs: 2_350, endMs: 2_900, confidence: 0.9),
        ParakeetTimedToken(token: ".", startMs: 2_900, endMs: 2_950, confidence: 0.96),
    ],
    language: "en",
    engine: "parakeet"
)
expect(mappedTranscript.segments.count == 2, "Token timings should map to timestamped transcript segments")
expect(mappedTranscript.segments[0].startMs == 120, "First segment should preserve token start timing")
expect(mappedTranscript.segments[0].endMs == 740, "First segment should preserve token end timing")
expect(mappedTranscript.segments[0].text == "Hello world.", "First segment should reconstruct token text")
expect(mappedTranscript.segments[1].startMs == 2_100, "Second segment should preserve later token start timing")

let fallbackTranscript = ParakeetTranscriptMapper.transcript(
    text: "No token timing available",
    durationMs: 3_000,
    confidence: 0.7,
    tokenTimings: nil,
    language: "en",
    engine: "parakeet"
)
expect(fallbackTranscript.segments.count == 1, "Missing token timings should retain a fallback segment")
expect(fallbackTranscript.segments[0].startMs == 0, "Fallback segment should start at zero")
expect(fallbackTranscript.segments[0].endMs == 3_000, "Fallback segment should keep total duration")

struct FakeParakeetEngine: ParakeetTranscribing {
    func transcribe(audioURL: URL, config: TranscriptionConfig) async throws -> Transcript {
        Transcript(
            segments: [
                TranscriptSegment(startMs: 0, endMs: 1_250, text: "hello world", confidence: 0.97)
            ],
            language: config.language,
            engine: "fake-parakeet"
        )
    }
}

let provider = ParakeetProvider(
    engineFactory: { _ in FakeParakeetEngine() },
    fileExists: { _ in true }
)
let transcript = try await provider.transcribeBatch(
    audioURL: URL(fileURLWithPath: "/tmp/fake.m4a"),
    config: .english
)
expect(provider.name == "parakeet", "Parakeet provider should report its engine name")
expect(!provider.requiresNetwork, "Parakeet provider should report local inference")
expect(!provider.supportsDiarization, "Parakeet provider should not advertise diarization until speaker assignment is wired")
expect(transcript.text == "hello world", "Parakeet provider should return engine transcript")

do {
    _ = try await ParakeetProvider(
        engineFactory: { _ in FakeParakeetEngine() },
        fileExists: { _ in false }
    ).transcribeBatch(audioURL: URL(fileURLWithPath: "/tmp/missing.m4a"))
    fatalError("Missing audio should throw")
} catch TranscriptionError.audioFileMissing {
} catch {
    fatalError("Missing audio threw unexpected error \(error)")
}

print("ParakeetTranscriptionSelfTests passed")
