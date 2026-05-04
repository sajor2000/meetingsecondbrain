import Foundation
import RecallOSCore

enum RecallOSConvexMappingError: LocalizedError, Equatable {
    case invalidLocalID(String, field: String)
    case invalidStatus(String)
    case invalidPriority(String)

    var errorDescription: String? {
        switch self {
        case let .invalidLocalID(value, field):
            "Convex document field \(field) is not a UUID: \(value)"
        case let .invalidStatus(value):
            "Convex document status is not supported: \(value)"
        case let .invalidPriority(value):
            "Convex document priority is not supported: \(value)"
        }
    }
}

enum RecallOSConvexMapper {
    static func localID(_ value: String, field: String = "localId") throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw RecallOSConvexMappingError.invalidLocalID(value, field: field)
        }
        return uuid
    }

    static func date(fromMilliseconds milliseconds: Double) -> Date {
        Date(timeIntervalSince1970: milliseconds / 1_000)
    }

    static func milliseconds(from date: Date) -> Double {
        date.timeIntervalSince1970 * 1_000
    }
}

struct ConvexPersonDocument: Equatable, Sendable {
    let convexID: String
    let localId: String
    let displayName: String
    let email: String?
    let role: String?

    func domainModel() throws -> Person {
        Person(
            id: try RecallOSConvexMapper.localID(localId),
            convexID: convexID,
            displayName: displayName,
            email: email,
            role: role
        )
    }
}

struct ConvexTopicDocument: Equatable, Sendable {
    let convexID: String
    let localId: String
    let name: String
    let meetingLocalIds: [String]

    func domainModel() throws -> Topic {
        Topic(
            id: try RecallOSConvexMapper.localID(localId),
            convexID: convexID,
            name: name,
            meetingIDs: try meetingLocalIds.map { try RecallOSConvexMapper.localID($0, field: "meetingLocalIds") }
        )
    }
}

struct ConvexMeetingDocument: Equatable, Sendable {
    let convexID: String
    let localId: String
    let title: String
    let startsAt: Double
    let endsAt: Double
    let status: String
    let folderId: String?
    let calendarEventId: String?
    let calendarEventLocalId: String?
    let summary: String?
    let rawNotes: String?
    let enhancedNotes: String?

    func domainModel(attendees: [Person] = [], topics: [Topic] = []) throws -> Meeting {
        guard let status = MeetingStatus(rawValue: status) else {
            throw RecallOSConvexMappingError.invalidStatus(self.status)
        }

        return Meeting(
            id: try RecallOSConvexMapper.localID(localId),
            convexID: convexID,
            title: title,
            startsAt: RecallOSConvexMapper.date(fromMilliseconds: startsAt),
            endsAt: RecallOSConvexMapper.date(fromMilliseconds: endsAt),
            attendees: attendees,
            folder: folderId,
            calendarEventID: try calendarEventLocalId.map { try RecallOSConvexMapper.localID($0, field: "calendarEventLocalId") },
            status: status,
            summary: summary ?? "",
            userNotes: noteBlocks(),
            topics: topics
        )
    }

    private func noteBlocks() -> [NoteBlock] {
        var blocks: [NoteBlock] = []
        if let rawNotes, !rawNotes.isEmpty {
            blocks.append(NoteBlock(title: "Notes", body: rawNotes))
        }
        if let enhancedNotes, !enhancedNotes.isEmpty {
            blocks.append(NoteBlock(title: "Enhanced notes", body: enhancedNotes))
        }
        return blocks
    }
}

struct ConvexTranscriptSegmentDocument: Equatable, Sendable {
    let convexID: String
    let localId: String
    let meetingLocalId: String
    let speaker: ConvexPersonDocument?
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let confidence: Double

    func domainModel() throws -> TranscriptSegment {
        TranscriptSegment(
            id: try RecallOSConvexMapper.localID(localId),
            convexID: convexID,
            meetingID: try RecallOSConvexMapper.localID(meetingLocalId, field: "meetingLocalId"),
            speaker: try speaker?.domainModel() ?? Person(displayName: "Unknown speaker"),
            startTime: startTime,
            endTime: endTime,
            text: text,
            confidence: confidence
        )
    }
}

struct ConvexTaskDocument: Equatable, Sendable {
    let convexID: String
    let localId: String
    let title: String
    let notes: String?
    let status: String
    let priority: String
    let owner: ConvexPersonDocument?
    let dueAt: Double?
    let completedAt: Double?
    let sourceMeetingLocalId: String?
    let sourceTimestamp: TimeInterval?
    let extractionConfidence: Double?

    func domainModel() throws -> MeetingTask {
        guard let status = TaskStatus(rawValue: status) else {
            throw RecallOSConvexMappingError.invalidStatus(self.status)
        }
        guard let priority = TaskPriority(rawValue: priority) else {
            throw RecallOSConvexMappingError.invalidPriority(self.priority)
        }

        return MeetingTask(
            id: try RecallOSConvexMapper.localID(localId),
            convexID: convexID,
            title: title,
            notes: notes ?? "",
            status: status,
            priority: priority,
            owner: try owner?.domainModel(),
            dueAt: dueAt.map(RecallOSConvexMapper.date(fromMilliseconds:)),
            completedAt: completedAt.map(RecallOSConvexMapper.date(fromMilliseconds:)),
            sourceMeetingID: try sourceMeetingLocalId.map { try RecallOSConvexMapper.localID($0, field: "sourceMeetingLocalId") },
            sourceTimestamp: sourceTimestamp,
            extractionConfidence: extractionConfidence
        )
    }
}

struct ConvexScreenshotDocument: Equatable, Sendable {
    let convexID: String
    let localId: String
    let meetingLocalId: String
    let capturedAt: TimeInterval
    let storageId: String
    let caption: String?

    func domainModel() throws -> MeetingScreenshot {
        MeetingScreenshot(
            id: try RecallOSConvexMapper.localID(localId),
            convexID: convexID,
            meetingID: try RecallOSConvexMapper.localID(meetingLocalId, field: "meetingLocalId"),
            capturedAt: capturedAt,
            storagePath: storageId,
            caption: caption ?? ""
        )
    }
}

struct ConvexDecisionDocument: Equatable, Sendable {
    let convexID: String
    let localId: String
    let meetingLocalId: String
    let title: String
    let detail: String
    let sourceTimestamp: TimeInterval?

    func domainModel() throws -> MeetingDecision {
        MeetingDecision(
            id: try RecallOSConvexMapper.localID(localId),
            convexID: convexID,
            title: title,
            detail: detail,
            sourceMeetingID: try RecallOSConvexMapper.localID(meetingLocalId, field: "meetingLocalId"),
            sourceTimestamp: sourceTimestamp
        )
    }
}

struct ConvexSettingDocument: Equatable, Sendable {
    let convexID: String
    let localId: String
    let key: String
    let value: String
    let updatedAt: Double

    func domainModel() throws -> RecallOSSetting {
        RecallOSSetting(
            id: try RecallOSConvexMapper.localID(localId),
            convexID: convexID,
            key: key,
            value: value,
            updatedAt: RecallOSConvexMapper.date(fromMilliseconds: updatedAt)
        )
    }
}
