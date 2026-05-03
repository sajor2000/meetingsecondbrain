import Foundation

public struct Transcript: Codable, Equatable, Sendable {
    public var segments: [TranscriptSegment]
    public var language: String
    public var engine: String
    public var createdAt: Date

    public init(
        segments: [TranscriptSegment] = [],
        language: String = "en",
        engine: String,
        createdAt: Date = Date()
    ) {
        self.segments = segments.sortedByTimeline()
        self.language = language
        self.engine = engine
        self.createdAt = createdAt
    }

    public var text: String {
        segments
            .map(\.text)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    public var durationMs: Int {
        segments.map(\.endMs).max() ?? 0
    }

    public var finalizedSegments: [TranscriptSegment] {
        segments.filter { $0.isFinal }
    }

    public var partialSegments: [TranscriptSegment] {
        segments.filter { !$0.isFinal }
    }

    public mutating func append(_ segment: TranscriptSegment) {
        segments.append(segment)
        segments = segments.sortedByTimeline()
    }
}

public struct TranscriptSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startMs: Int
    public var endMs: Int
    public var text: String
    public var speaker: String?
    public var confidence: Double?
    public var isFinal: Bool

    public init(
        id: UUID = UUID(),
        startMs: Int,
        endMs: Int,
        text: String,
        speaker: String? = nil,
        confidence: Double? = nil,
        isFinal: Bool = true
    ) {
        self.id = id
        self.startMs = max(0, startMs)
        self.endMs = max(max(0, startMs), endMs)
        self.text = text
        self.speaker = speaker
        self.confidence = confidence
        self.isFinal = isFinal
    }

    public var durationMs: Int {
        endMs - startMs
    }
}

private extension Array where Element == TranscriptSegment {
    func sortedByTimeline() -> [TranscriptSegment] {
        sorted {
            if $0.startMs == $1.startMs {
                return $0.endMs < $1.endMs
            }
            return $0.startMs < $1.startMs
        }
    }
}
