import Foundation
import SwiftData

@Model
final class PersistentMeeting {
    @Attribute(.unique) var id: UUID
    var convexID: String?
    var title: String
    var startsAt: Date
    var endsAt: Date
    var folder: String?
    var calendarEventID: UUID?
    var status: String
    var summary: String

    @Relationship(deleteRule: .cascade) var attendees: [PersistentPersonRecord]
    @Relationship(deleteRule: .cascade) var noteBlocks: [PersistentNoteBlock]
    @Relationship(deleteRule: .cascade) var transcriptSegments: [PersistentTranscriptSegment]
    @Relationship(deleteRule: .cascade) var tasks: [PersistentMeetingTask]
    @Relationship(deleteRule: .cascade) var screenshots: [PersistentMeetingScreenshot]
    @Relationship(deleteRule: .cascade) var decisions: [PersistentMeetingDecision]
    @Relationship(deleteRule: .cascade) var topics: [PersistentTopic]

    init(
        id: UUID,
        convexID: String?,
        title: String,
        startsAt: Date,
        endsAt: Date,
        folder: String?,
        calendarEventID: UUID?,
        status: String,
        summary: String,
        attendees: [PersistentPersonRecord] = [],
        noteBlocks: [PersistentNoteBlock] = [],
        transcriptSegments: [PersistentTranscriptSegment] = [],
        tasks: [PersistentMeetingTask] = [],
        screenshots: [PersistentMeetingScreenshot] = [],
        decisions: [PersistentMeetingDecision] = [],
        topics: [PersistentTopic] = []
    ) {
        self.id = id
        self.convexID = convexID
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.folder = folder
        self.calendarEventID = calendarEventID
        self.status = status
        self.summary = summary
        self.attendees = attendees
        self.noteBlocks = noteBlocks
        self.transcriptSegments = transcriptSegments
        self.tasks = tasks
        self.screenshots = screenshots
        self.decisions = decisions
        self.topics = topics
    }
}

@Model
final class PersistentPersonRecord {
    var id: UUID
    var convexID: String?
    var displayName: String
    var email: String?
    var role: String?
    var position: Int

    init(id: UUID, convexID: String?, displayName: String, email: String?, role: String?, position: Int = 0) {
        self.id = id
        self.convexID = convexID
        self.displayName = displayName
        self.email = email
        self.role = role
        self.position = position
    }
}

@Model
final class PersistentNoteBlock {
    var id: UUID
    var title: String
    var body: String
    var position: Int

    @Relationship(deleteRule: .cascade) var aiAdditions: [PersistentAIAddition]

    init(id: UUID, title: String, body: String, position: Int, aiAdditions: [PersistentAIAddition] = []) {
        self.id = id
        self.title = title
        self.body = body
        self.position = position
        self.aiAdditions = aiAdditions
    }
}

@Model
final class PersistentAIAddition {
    var id: UUID
    var text: String
    var sourceTimestamp: TimeInterval
    var confidence: Double
    var position: Int

    init(id: UUID, text: String, sourceTimestamp: TimeInterval, confidence: Double, position: Int) {
        self.id = id
        self.text = text
        self.sourceTimestamp = sourceTimestamp
        self.confidence = confidence
        self.position = position
    }
}

@Model
final class PersistentTranscriptSegment {
    var id: UUID
    var convexID: String?
    var meetingID: UUID
    var speakerID: UUID
    var speakerConvexID: String?
    var speakerDisplayName: String
    var speakerEmail: String?
    var speakerRole: String?
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var confidence: Double

    init(
        id: UUID,
        convexID: String?,
        meetingID: UUID,
        speakerID: UUID,
        speakerConvexID: String?,
        speakerDisplayName: String,
        speakerEmail: String?,
        speakerRole: String?,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        confidence: Double
    ) {
        self.id = id
        self.convexID = convexID
        self.meetingID = meetingID
        self.speakerID = speakerID
        self.speakerConvexID = speakerConvexID
        self.speakerDisplayName = speakerDisplayName
        self.speakerEmail = speakerEmail
        self.speakerRole = speakerRole
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
    }
}

@Model
final class PersistentMeetingTask {
    var id: UUID
    var convexID: String?
    var title: String
    var notes: String
    var status: String
    var priority: String
    var ownerID: UUID?
    var ownerConvexID: String?
    var ownerDisplayName: String?
    var ownerEmail: String?
    var ownerRole: String?
    var dueAt: Date?
    var completedAt: Date?
    var sourceMeetingID: UUID?
    var sourceMeetingTitle: String?
    var sourceTimestamp: TimeInterval?
    var extractionConfidence: Double?

    init(
        id: UUID,
        convexID: String?,
        title: String,
        notes: String,
        status: String,
        priority: String,
        ownerID: UUID?,
        ownerConvexID: String?,
        ownerDisplayName: String?,
        ownerEmail: String?,
        ownerRole: String?,
        dueAt: Date?,
        completedAt: Date?,
        sourceMeetingID: UUID?,
        sourceMeetingTitle: String?,
        sourceTimestamp: TimeInterval?,
        extractionConfidence: Double?
    ) {
        self.id = id
        self.convexID = convexID
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.ownerID = ownerID
        self.ownerConvexID = ownerConvexID
        self.ownerDisplayName = ownerDisplayName
        self.ownerEmail = ownerEmail
        self.ownerRole = ownerRole
        self.dueAt = dueAt
        self.completedAt = completedAt
        self.sourceMeetingID = sourceMeetingID
        self.sourceMeetingTitle = sourceMeetingTitle
        self.sourceTimestamp = sourceTimestamp
        self.extractionConfidence = extractionConfidence
    }
}

@Model
final class PersistentMeetingScreenshot {
    var id: UUID
    var convexID: String?
    var meetingID: UUID
    var capturedAt: TimeInterval
    var storagePath: String
    var caption: String

    init(id: UUID, convexID: String?, meetingID: UUID, capturedAt: TimeInterval, storagePath: String, caption: String) {
        self.id = id
        self.convexID = convexID
        self.meetingID = meetingID
        self.capturedAt = capturedAt
        self.storagePath = storagePath
        self.caption = caption
    }
}

@Model
final class PersistentMeetingDecision {
    var id: UUID
    var convexID: String?
    var title: String
    var detail: String
    var sourceMeetingID: UUID
    var sourceTimestamp: TimeInterval?

    init(id: UUID, convexID: String?, title: String, detail: String, sourceMeetingID: UUID, sourceTimestamp: TimeInterval?) {
        self.id = id
        self.convexID = convexID
        self.title = title
        self.detail = detail
        self.sourceMeetingID = sourceMeetingID
        self.sourceTimestamp = sourceTimestamp
    }
}

@Model
final class PersistentTopic {
    var id: UUID
    var convexID: String?
    var name: String
    var meetingIDString: String

    init(id: UUID, convexID: String?, name: String, meetingIDString: String) {
        self.id = id
        self.convexID = convexID
        self.name = name
        self.meetingIDString = meetingIDString
    }
}

@Model
final class PersistentCalendarEvent {
    @Attribute(.unique) var id: UUID
    var convexID: String?
    var externalID: String
    var title: String
    var startsAt: Date
    var endsAt: Date
    var location: String?

    @Relationship(deleteRule: .cascade) var attendees: [PersistentPersonRecord]

    init(
        id: UUID,
        convexID: String?,
        externalID: String,
        title: String,
        startsAt: Date,
        endsAt: Date,
        location: String?,
        attendees: [PersistentPersonRecord] = []
    ) {
        self.id = id
        self.convexID = convexID
        self.externalID = externalID
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.location = location
        self.attendees = attendees
    }
}

@Model
final class PersistentRecallOSSetting {
    @Attribute(.unique) var key: String
    var id: UUID
    var convexID: String?
    var value: String
    var updatedAt: Date

    init(id: UUID, convexID: String?, key: String, value: String, updatedAt: Date) {
        self.id = id
        self.convexID = convexID
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

