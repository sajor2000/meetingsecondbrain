import Foundation

public struct Meeting: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var title: String
    public var startsAt: Date
    public var endsAt: Date
    public var attendees: [Person]
    public var folder: String?
    public var calendarEventID: UUID?
    public var status: MeetingStatus
    public var summary: String
    public var userNotes: [NoteBlock]
    public var transcriptSegments: [TranscriptSegment]
    public var tasks: [MeetingTask]
    public var screenshots: [MeetingScreenshot]
    public var decisions: [MeetingDecision]
    public var topics: [Topic]

    public init(
        id: UUID = UUID(),
        convexID: String? = nil,
        title: String,
        startsAt: Date,
        endsAt: Date,
        attendees: [Person] = [],
        folder: String? = nil,
        calendarEventID: UUID? = nil,
        status: MeetingStatus = .scheduled,
        summary: String = "",
        userNotes: [NoteBlock] = [],
        transcriptSegments: [TranscriptSegment] = [],
        tasks: [MeetingTask] = [],
        screenshots: [MeetingScreenshot] = [],
        decisions: [MeetingDecision] = [],
        topics: [Topic] = []
    ) {
        self.id = id
        self.convexID = convexID
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.attendees = attendees
        self.folder = folder
        self.calendarEventID = calendarEventID
        self.status = status
        self.summary = summary
        self.userNotes = userNotes
        self.transcriptSegments = transcriptSegments
        self.tasks = tasks
        self.screenshots = screenshots
        self.decisions = decisions
        self.topics = topics
    }
}

public enum MeetingStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case scheduled
    case inProgress
    case recording
    case enhancing
    case completed
    case failed
}

public enum MeetingLifecycle {
    public static func status(for meeting: Meeting, at now: Date = Date()) -> MeetingStatus {
        switch meeting.status {
        case .scheduled:
            if meeting.startsAt <= now && now <= meeting.endsAt {
                return .inProgress
            }
            return .scheduled
        case .inProgress:
            return meeting.endsAt < now ? .scheduled : .inProgress
        case .recording, .enhancing, .completed, .failed:
            return meeting.status
        }
    }

    public static func initialStatus(startsAt: Date, endsAt: Date, at now: Date = Date()) -> MeetingStatus {
        if startsAt <= now && now <= endsAt {
            return .inProgress
        }
        return .scheduled
    }
}

public extension Meeting {
    func advancedLifecycle(at now: Date = Date()) -> Meeting {
        var meeting = self
        meeting.status = MeetingLifecycle.status(for: self, at: now)
        return meeting
    }
}
