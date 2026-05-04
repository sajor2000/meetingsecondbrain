import Foundation

public enum SampleData {
    public static let me = Person(displayName: "Me", email: "me@example.com")
    public static let patrick = Person(displayName: "Patrick", email: "patrick@example.com")
    public static let kevin = Person(displayName: "Kevin", email: "kevin@example.com")
    public static let lily = Person(displayName: "Lily", email: "lily@example.com")

    public static let meetingID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    public static var meeting: Meeting {
        let start = Date(timeIntervalSince1970: 1_778_270_400)
        let end = start.addingTimeInterval(45 * 60)
        return Meeting(
            id: meetingID,
            title: "AI CoE weekly",
            startsAt: start,
            endsAt: end,
            attendees: [me, patrick, kevin, lily],
            folder: "Board",
            status: .recording,
            summary: "Patrick aligned on a JSL POC narrative that ties customer proof, manuscript milestones, and open executive asks into one next-step plan. The clearest decision is to make Kevin the source of truth for manuscript blockers before Friday.",
            userNotes: noteBlocks,
            transcriptSegments: transcriptSegments,
            tasks: tasks,
            screenshots: [
                MeetingScreenshot(meetingID: meetingID, capturedAt: 1338, storagePath: "screenshots/ai-coe-weekly-22-18.png", caption: "Screenshot inserted from keyboard capture.")
            ],
            decisions: [
                MeetingDecision(
                    title: "Customer proof before platform depth",
                    detail: "Use customer proof before platform depth as the ordering principle for the recap.",
                    sourceMeetingID: meetingID,
                    sourceTimestamp: 1089
                )
            ],
            topics: [
                Topic(name: "JSL POC", meetingIDs: [meetingID]),
                Topic(name: "CLIF Q1 manuscript", meetingIDs: [meetingID])
            ]
        )
    }

    public static let noteBlocks: [NoteBlock] = [
        NoteBlock(
            title: "JSL POC next step",
            body: "Patrick wants the POC recap to lead with operational readiness, not model novelty. Keep the note concise enough to paste into the partner update.",
            aiAdditions: [
                AIAddition(
                    text: "Patrick repeated \"risk is ownership, not quality\" twice, both times while discussing the JSL follow-up. Link this to the open Kevin task before sending the recap.",
                    sourceTimestamp: 764,
                    confidence: 0.88
                )
            ]
        ),
        NoteBlock(
            title: "Decisions",
            body: "Use \"customer proof before platform depth\" as the ordering principle for the recap.\nKeep the CLIF Q1 manuscript question in the same thread as the POC update.",
            aiAdditions: [
                AIAddition(
                    text: "This decision updates the earlier board-prep thread from Thursday, where Avery asked for fewer parallel narratives.",
                    sourceTimestamp: 1089,
                    confidence: 0.84
                )
            ]
        )
    ]

    public static let tasks: [MeetingTask] = [
        MeetingTask(
            title: "Send Patrick the JSL POC recap",
            notes: "Lead with customer proof before platform depth.",
            status: .today,
            priority: .high,
            owner: me,
            dueAt: Date(timeIntervalSince1970: 1_778_310_000),
            sourceMeetingID: meetingID,
            sourceMeetingTitle: "AI CoE weekly",
            sourceTimestamp: 764,
            extractionConfidence: 0.91
        ),
        MeetingTask(
            title: "Confirm Kevin owns manuscript blockers",
            notes: "Ownership is ambiguous; confirm before saving.",
            status: .open,
            priority: .high,
            owner: me,
            sourceMeetingID: meetingID,
            sourceMeetingTitle: "CLIF Q1 manuscript",
            sourceTimestamp: 1886,
            extractionConfidence: 0.72
        ),
        MeetingTask(
            title: "Lily checks manuscript date conflict",
            status: .waiting,
            priority: .medium,
            owner: lily,
            sourceMeetingID: meetingID,
            sourceMeetingTitle: "CLIF Q1 manuscript",
            sourceTimestamp: 1886,
            extractionConfidence: 0.91
        ),
        MeetingTask(
            title: "Save Patrick proof quote",
            status: .done,
            priority: .low,
            owner: me,
            completedAt: Date(timeIntervalSince1970: 1_778_290_000),
            sourceMeetingID: meetingID,
            sourceMeetingTitle: "Partner update prep",
            sourceTimestamp: 1089,
            extractionConfidence: 0.96
        )
    ]

    public static let transcriptSegments: [TranscriptSegment] = [
        TranscriptSegment(
            meetingID: meetingID,
            speaker: me,
            startTime: 764,
            endTime: 783,
            text: "I think the risk is ownership, not quality. We need Kevin tied to the manuscript blocker list.",
            confidence: 0.94
        ),
        TranscriptSegment(
            meetingID: meetingID,
            speaker: patrick,
            startTime: 1089,
            endTime: 1112,
            text: "Customer proof comes before platform depth, otherwise the POC note reads like a research update.",
            confidence: 0.93
        ),
        TranscriptSegment(
            meetingID: meetingID,
            speaker: lily,
            startTime: 1886,
            endTime: 1910,
            text: "I can check the CLIF date conflict, but Kevin should own the manuscript risk.",
            confidence: 0.91
        )
    ]

    public static var calendarEvents: [CalendarEvent] {
        let now = Date()
        return [
            CalendarEvent(
                externalID: "calendar-ai-coe-weekly",
                title: "AI CoE weekly",
                startsAt: now.addingTimeInterval(90),
                endsAt: now.addingTimeInterval(45 * 60),
                location: "Zoom",
                attendees: [me, patrick, kevin, lily]
            ),
            CalendarEvent(
                externalID: "calendar-patrick-sync",
                title: "Patrick sync",
                startsAt: now.addingTimeInterval(23 * 60),
                endsAt: now.addingTimeInterval(53 * 60),
                location: "Google Meet",
                attendees: [me, patrick]
            ),
            CalendarEvent(
                externalID: "calendar-manuscript-review",
                title: "Manuscript review",
                startsAt: now.addingTimeInterval(3.5 * 60 * 60),
                endsAt: now.addingTimeInterval(4 * 60 * 60),
                location: "Teams",
                attendees: [me, kevin, lily]
            )
        ]
    }

    public static let searchResults: [SearchResult] = [
        SearchResult(
            title: "Patrick said the JSL POC recap should lead with customer proof before platform depth.",
            source: "AI CoE weekly · Sunday, May 3",
            snippet: "Customer proof comes before platform depth, otherwise the POC note reads like a research update.",
            sourceMeetingID: meetingID
        ),
        SearchResult(
            title: "The same narrative appeared as fewer parallel narratives.",
            source: "Partner update prep · Friday, May 1",
            snippet: "Avery asked for fewer parallel narratives and a cleaner partner update.",
            sourceMeetingID: meetingID
        )
    ]
}
