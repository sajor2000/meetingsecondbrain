import Foundation
import RecallOSCore

enum RecallOSPersistenceMapper {
    static func persistentMeeting(from meeting: Meeting) -> PersistentMeeting {
        PersistentMeeting(
            id: meeting.id,
            convexID: meeting.convexID,
            title: meeting.title,
            startsAt: meeting.startsAt,
            endsAt: meeting.endsAt,
            folder: meeting.folder,
            calendarEventID: meeting.calendarEventID,
            status: meeting.status.rawValue,
            summary: meeting.summary,
            attendees: meeting.attendees.enumerated().map { index, person in
                persistentPerson(from: person, position: index)
            },
            noteBlocks: meeting.userNotes.enumerated().map { index, noteBlock in
                persistentNoteBlock(from: noteBlock, position: index)
            },
            transcriptSegments: meeting.transcriptSegments.map(persistentTranscriptSegment(from:)),
            tasks: meeting.tasks.map(persistentTask(from:)),
            screenshots: meeting.screenshots.map(persistentScreenshot(from:)),
            decisions: meeting.decisions.map(persistentDecision(from:)),
            topics: meeting.topics.map(persistentTopic(from:)),
            audioArtifacts: meeting.audioArtifacts.map(persistentAudioArtifact(from:))
        )
    }

    static func meeting(from persistent: PersistentMeeting) -> Meeting {
        Meeting(
            id: persistent.id,
            convexID: persistent.convexID,
            title: persistent.title,
            startsAt: persistent.startsAt,
            endsAt: persistent.endsAt,
            attendees: persistent.attendees
                .sorted { $0.position < $1.position }
                .map(person(from:)),
            folder: persistent.folder,
            calendarEventID: persistent.calendarEventID,
            status: MeetingStatus(rawValue: persistent.status) ?? .scheduled,
            summary: persistent.summary,
            userNotes: persistent.noteBlocks
                .sorted { $0.position < $1.position }
                .map(noteBlock(from:)),
            transcriptSegments: persistent.transcriptSegments
                .map(transcriptSegment(from:))
                .sorted { $0.startTime < $1.startTime },
            tasks: persistent.tasks.map(task(from:)),
            screenshots: persistent.screenshots.map(screenshot(from:)),
            decisions: persistent.decisions.map(decision(from:)),
            topics: persistent.topics.map(topic(from:)),
            audioArtifacts: persistent.audioArtifacts
                .map(audioArtifact(from:))
                .sorted { $0.startedAt < $1.startedAt }
        )
    }

    static func persistentSetting(from setting: RecallOSSetting) -> PersistentRecallOSSetting {
        PersistentRecallOSSetting(
            id: setting.id,
            convexID: setting.convexID,
            key: setting.key,
            value: setting.value,
            updatedAt: setting.updatedAt
        )
    }

    static func setting(from persistent: PersistentRecallOSSetting) -> RecallOSSetting {
        RecallOSSetting(
            id: persistent.id,
            convexID: persistent.convexID,
            key: persistent.key,
            value: persistent.value,
            updatedAt: persistent.updatedAt
        )
    }

    static func persistentCalendarEvent(from event: CalendarEvent) -> PersistentCalendarEvent {
        PersistentCalendarEvent(
            id: event.id,
            convexID: event.convexID,
            externalID: event.externalID,
            title: event.title,
            startsAt: event.startsAt,
            endsAt: event.endsAt,
            location: event.location,
            attendees: event.attendees.enumerated().map { index, person in
                persistentPerson(from: person, position: index)
            }
        )
    }

    static func calendarEvent(from persistent: PersistentCalendarEvent) -> CalendarEvent {
        CalendarEvent(
            id: persistent.id,
            convexID: persistent.convexID,
            externalID: persistent.externalID,
            title: persistent.title,
            startsAt: persistent.startsAt,
            endsAt: persistent.endsAt,
            location: persistent.location,
            attendees: persistent.attendees
                .sorted { $0.position < $1.position }
                .map(person(from:))
        )
    }

    static func transcriptSegment(fromPersistent persistent: PersistentTranscriptSegment) -> TranscriptSegment {
        transcriptSegment(from: persistent)
    }

    static func screenshot(fromPersistent persistent: PersistentMeetingScreenshot) -> MeetingScreenshot {
        screenshot(from: persistent)
    }

    private static func persistentPerson(from person: Person, position: Int) -> PersistentPersonRecord {
        PersistentPersonRecord(
            id: person.id,
            convexID: person.convexID,
            displayName: person.displayName,
            email: person.email,
            role: person.role,
            position: position
        )
    }

    private static func person(from persistent: PersistentPersonRecord) -> Person {
        Person(
            id: persistent.id,
            convexID: persistent.convexID,
            displayName: persistent.displayName,
            email: persistent.email,
            role: persistent.role
        )
    }

    private static func persistentNoteBlock(from noteBlock: NoteBlock, position: Int) -> PersistentNoteBlock {
        PersistentNoteBlock(
            id: noteBlock.id,
            title: noteBlock.title,
            body: noteBlock.body,
            position: position,
            aiAdditions: noteBlock.aiAdditions.enumerated().map { index, addition in
                PersistentAIAddition(
                    id: addition.id,
                    text: addition.text,
                    sourceTimestamp: addition.sourceTimestamp,
                    confidence: addition.confidence,
                    position: index
                )
            }
        )
    }

    private static func noteBlock(from persistent: PersistentNoteBlock) -> NoteBlock {
        NoteBlock(
            id: persistent.id,
            title: persistent.title,
            body: persistent.body,
            aiAdditions: persistent.aiAdditions
                .sorted { $0.position < $1.position }
                .map { addition in
                    AIAddition(
                        id: addition.id,
                        text: addition.text,
                        sourceTimestamp: addition.sourceTimestamp,
                        confidence: addition.confidence
                    )
                }
        )
    }

    private static func persistentTranscriptSegment(from segment: TranscriptSegment) -> PersistentTranscriptSegment {
        PersistentTranscriptSegment(
            id: segment.id,
            convexID: segment.convexID,
            meetingID: segment.meetingID,
            speakerID: segment.speaker.id,
            speakerConvexID: segment.speaker.convexID,
            speakerDisplayName: segment.speaker.displayName,
            speakerEmail: segment.speaker.email,
            speakerRole: segment.speaker.role,
            startTime: segment.startTime,
            endTime: segment.endTime,
            text: segment.text,
            confidence: segment.confidence
        )
    }

    private static func transcriptSegment(from persistent: PersistentTranscriptSegment) -> TranscriptSegment {
        TranscriptSegment(
            id: persistent.id,
            convexID: persistent.convexID,
            meetingID: persistent.meetingID,
            speaker: Person(
                id: persistent.speakerID,
                convexID: persistent.speakerConvexID,
                displayName: persistent.speakerDisplayName,
                email: persistent.speakerEmail,
                role: persistent.speakerRole
            ),
            startTime: persistent.startTime,
            endTime: persistent.endTime,
            text: persistent.text,
            confidence: persistent.confidence
        )
    }

    private static func persistentTask(from task: MeetingTask) -> PersistentMeetingTask {
        PersistentMeetingTask(
            id: task.id,
            convexID: task.convexID,
            title: task.title,
            notes: task.notes,
            status: task.status.rawValue,
            priority: task.priority.rawValue,
            ownerID: task.owner?.id,
            ownerConvexID: task.owner?.convexID,
            ownerDisplayName: task.owner?.displayName,
            ownerEmail: task.owner?.email,
            ownerRole: task.owner?.role,
            dueAt: task.dueAt,
            completedAt: task.completedAt,
            sourceMeetingID: task.sourceMeetingID,
            sourceMeetingTitle: task.sourceMeetingTitle,
            sourceTimestamp: task.sourceTimestamp,
            extractionConfidence: task.extractionConfidence
        )
    }

    private static func task(from persistent: PersistentMeetingTask) -> MeetingTask {
        let owner = persistent.ownerDisplayName.map { displayName in
            Person(
                id: persistent.ownerID ?? UUID(),
                convexID: persistent.ownerConvexID,
                displayName: displayName,
                email: persistent.ownerEmail,
                role: persistent.ownerRole
            )
        }

        return MeetingTask(
            id: persistent.id,
            convexID: persistent.convexID,
            title: persistent.title,
            notes: persistent.notes,
            status: TaskStatus(rawValue: persistent.status) ?? .open,
            priority: TaskPriority(rawValue: persistent.priority) ?? .medium,
            owner: owner,
            dueAt: persistent.dueAt,
            completedAt: persistent.completedAt,
            sourceMeetingID: persistent.sourceMeetingID,
            sourceMeetingTitle: persistent.sourceMeetingTitle,
            sourceTimestamp: persistent.sourceTimestamp,
            extractionConfidence: persistent.extractionConfidence
        )
    }

    private static func persistentScreenshot(from screenshot: MeetingScreenshot) -> PersistentMeetingScreenshot {
        PersistentMeetingScreenshot(
            id: screenshot.id,
            convexID: screenshot.convexID,
            meetingID: screenshot.meetingID,
            capturedAt: screenshot.capturedAt,
            storagePath: screenshot.storagePath,
            caption: screenshot.caption
        )
    }

    private static func persistentAudioArtifact(from artifact: AudioCaptureArtifact) -> PersistentAudioCaptureArtifact {
        PersistentAudioCaptureArtifact(
            id: artifact.id,
            convexID: artifact.convexID,
            meetingID: artifact.meetingID,
            startedAt: artifact.startedAt,
            endedAt: artifact.endedAt,
            microphoneAudioPath: artifact.microphoneAudioPath,
            duration: artifact.duration,
            byteSize: artifact.byteSize,
            diagnostics: artifact.diagnostics,
            errorMessage: artifact.errorMessage
        )
    }

    private static func audioArtifact(from persistent: PersistentAudioCaptureArtifact) -> AudioCaptureArtifact {
        AudioCaptureArtifact(
            id: persistent.id,
            convexID: persistent.convexID,
            meetingID: persistent.meetingID,
            startedAt: persistent.startedAt,
            endedAt: persistent.endedAt,
            microphoneAudioPath: persistent.microphoneAudioPath,
            duration: persistent.duration,
            byteSize: persistent.byteSize,
            diagnostics: persistent.diagnostics,
            errorMessage: persistent.errorMessage
        )
    }

    private static func screenshot(from persistent: PersistentMeetingScreenshot) -> MeetingScreenshot {
        MeetingScreenshot(
            id: persistent.id,
            convexID: persistent.convexID,
            meetingID: persistent.meetingID,
            capturedAt: persistent.capturedAt,
            storagePath: persistent.storagePath,
            caption: persistent.caption
        )
    }

    private static func persistentDecision(from decision: MeetingDecision) -> PersistentMeetingDecision {
        PersistentMeetingDecision(
            id: decision.id,
            convexID: decision.convexID,
            title: decision.title,
            detail: decision.detail,
            sourceMeetingID: decision.sourceMeetingID,
            sourceTimestamp: decision.sourceTimestamp
        )
    }

    private static func decision(from persistent: PersistentMeetingDecision) -> MeetingDecision {
        MeetingDecision(
            id: persistent.id,
            convexID: persistent.convexID,
            title: persistent.title,
            detail: persistent.detail,
            sourceMeetingID: persistent.sourceMeetingID,
            sourceTimestamp: persistent.sourceTimestamp
        )
    }

    private static func persistentTopic(from topic: Topic) -> PersistentTopic {
        PersistentTopic(
            id: topic.id,
            convexID: topic.convexID,
            name: topic.name,
            meetingIDString: topic.meetingIDs.map(\.uuidString).joined(separator: ",")
        )
    }

    private static func topic(from persistent: PersistentTopic) -> Topic {
        Topic(
            id: persistent.id,
            convexID: persistent.convexID,
            name: persistent.name,
            meetingIDs: persistent.meetingIDString
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
        )
    }
}
