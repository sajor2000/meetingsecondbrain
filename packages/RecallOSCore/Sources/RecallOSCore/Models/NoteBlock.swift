import Foundation

public struct NoteBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var aiAdditions: [AIAddition]

    public init(id: UUID = UUID(), title: String, body: String, aiAdditions: [AIAddition] = []) {
        self.id = id
        self.title = title
        self.body = body
        self.aiAdditions = aiAdditions
    }
}

public struct AIAddition: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var sourceTimestamp: TimeInterval
    public var confidence: Double

    public init(id: UUID = UUID(), text: String, sourceTimestamp: TimeInterval, confidence: Double) {
        self.id = id
        self.text = text
        self.sourceTimestamp = sourceTimestamp
        self.confidence = confidence
    }

    public var timestampLabel: String {
        "↗ \(Self.timestampFormatter.string(from: sourceTimestamp) ?? "00:00")"
    }

    private static let timestampFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}
