import Foundation

public struct MeetingTask: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var title: String
    public var notes: String
    public var status: TaskStatus
    public var priority: TaskPriority
    public var owner: Person?
    public var dueAt: Date?
    public var completedAt: Date?
    public var sourceMeetingID: UUID?
    public var sourceMeetingTitle: String?
    public var sourceTimestamp: TimeInterval?
    public var extractionConfidence: Double?

    public init(
        id: UUID = UUID(),
        convexID: String? = nil,
        title: String,
        notes: String = "",
        status: TaskStatus = .open,
        priority: TaskPriority = .medium,
        owner: Person? = nil,
        dueAt: Date? = nil,
        completedAt: Date? = nil,
        sourceMeetingID: UUID? = nil,
        sourceMeetingTitle: String? = nil,
        sourceTimestamp: TimeInterval? = nil,
        extractionConfidence: Double? = nil
    ) {
        self.id = id
        self.convexID = convexID
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.owner = owner
        self.dueAt = dueAt
        self.completedAt = completedAt
        self.sourceMeetingID = sourceMeetingID
        self.sourceMeetingTitle = sourceMeetingTitle
        self.sourceTimestamp = sourceTimestamp
        self.extractionConfidence = extractionConfidence
    }
}

public enum TaskStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case open
    case today
    case waiting
    case done
}

public enum TaskPriority: String, Codable, Hashable, Sendable, CaseIterable {
    case low
    case medium
    case high
}
