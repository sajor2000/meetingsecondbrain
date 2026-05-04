import Foundation

public struct EnhancedMeetingContent: Codable, Hashable, Sendable {
    public var summary: String
    public var noteBlocks: [NoteBlock]

    public init(summary: String, noteBlocks: [NoteBlock]) {
        self.summary = summary
        self.noteBlocks = noteBlocks
    }
}

public protocol RecordingPermissionProvider: Sendable {
    func requestMicrophoneAccess() async throws -> Bool
}

public protocol AudioCaptureProvider: Sendable {
    func start(meeting: Meeting) async throws
    func pause() async throws
    func resume() async throws
    func stop() async throws -> AudioCaptureArtifact?
}

public protocol TranscriptionProvider: Sendable {
    func transcriptStream(for meeting: Meeting) async throws -> AsyncThrowingStream<TranscriptSegment, Error>
}

public protocol NoteEnhancementProvider: Sendable {
    func enhance(meeting: Meeting, transcriptSegments: [TranscriptSegment]) async throws -> EnhancedMeetingContent
}

public protocol TaskExtractionProvider: Sendable {
    func extractTasks(from meeting: Meeting, transcriptSegments: [TranscriptSegment]) async throws -> [MeetingTask]
}

public protocol CalendarEventProvider: Sendable {
    func upcomingEvents(limit: Int) async throws -> [CalendarEvent]
}

public protocol SecondBrainSearchProvider: Sendable {
    func search(query: String, meetings: [Meeting], tasks: [MeetingTask]) async throws -> [SearchResult]
}

public struct AllowAllRecordingPermissionProvider: RecordingPermissionProvider {
    public init() {}

    public func requestMicrophoneAccess() async throws -> Bool {
        true
    }
}

public actor MockAudioCaptureProvider: AudioCaptureProvider {
    private var isCapturing = false
    private var isPaused = false

    public init() {}

    public func start(meeting: Meeting) async throws {
        isCapturing = true
        isPaused = false
    }

    public func pause() async throws {
        guard isCapturing else { return }
        isPaused = true
    }

    public func resume() async throws {
        guard isCapturing else { return }
        isPaused = false
    }

    public func stop() async throws -> AudioCaptureArtifact? {
        isCapturing = false
        isPaused = false
        return nil
    }
}

public struct MockTranscriptionProvider: TranscriptionProvider {
    private let delayNanoseconds: UInt64

    public init(delayNanoseconds: UInt64 = 180_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    public func transcriptStream(for meeting: Meeting) async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        let segments = Self.mockSegments(for: meeting)
        let delayNanoseconds = delayNanoseconds

        return AsyncThrowingStream { continuation in
            let task = Swift.Task {
                for segment in segments {
                    if Swift.Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    try? await Swift.Task.sleep(nanoseconds: delayNanoseconds)
                    continuation.yield(segment)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public static func mockSegments(for meeting: Meeting) -> [TranscriptSegment] {
        let speakers = meeting.attendees.isEmpty ? [SampleData.me, SampleData.patrick, SampleData.lily] : meeting.attendees
        let me = speakers.first ?? SampleData.me
        let collaborator = speakers.dropFirst().first ?? SampleData.patrick
        let reviewer = speakers.dropFirst(2).first ?? SampleData.lily

        return [
            TranscriptSegment(
                meetingID: meeting.id,
                speaker: me,
                startTime: 12,
                endTime: 28,
                text: "Let's keep the recap focused on customer proof and make the next owner clear.",
                confidence: 0.95
            ),
            TranscriptSegment(
                meetingID: meeting.id,
                speaker: collaborator,
                startTime: 45,
                endTime: 68,
                text: "The strongest point is that the action item belongs with Kevin before Friday.",
                confidence: 0.92
            ),
            TranscriptSegment(
                meetingID: meeting.id,
                speaker: reviewer,
                startTime: 94,
                endTime: 116,
                text: "I can verify the date conflict and send the blocker list back to the group.",
                confidence: 0.9
            )
        ]
    }
}

public struct MockNoteEnhancementProvider: NoteEnhancementProvider {
    public init() {}

    public func enhance(meeting: Meeting, transcriptSegments: [TranscriptSegment]) async throws -> EnhancedMeetingContent {
        let sourceSegments = transcriptSegments.isEmpty ? meeting.transcriptSegments : transcriptSegments
        let summary = sourceSegments.isEmpty
            ? "Recording finished. RecallOS did not receive transcript text yet, so these notes are ready for manual review."
            : "The meeting centered on customer proof, ownership clarity, and a near-term blocker check. The clearest next step is to confirm the owner and send a concise recap."

        let firstTimestamp = sourceSegments.first?.startTime ?? 0
        let secondTimestamp = sourceSegments.dropFirst().first?.startTime ?? firstTimestamp

        let notes = [
            NoteBlock(
                title: "Meeting focus",
                body: "Capture the core decision and the owner before sending the follow-up.",
                aiAdditions: [
                    AIAddition(
                        text: "The transcript points to customer proof as the framing principle for the recap.",
                        sourceTimestamp: firstTimestamp,
                        confidence: 0.86
                    )
                ]
            ),
            NoteBlock(
                title: "Open follow-up",
                body: "Confirm the blocker owner and timing.",
                aiAdditions: [
                    AIAddition(
                        text: "The task is time-sensitive because the blocker list is needed before Friday.",
                        sourceTimestamp: secondTimestamp,
                        confidence: 0.82
                    )
                ]
            )
        ]

        return EnhancedMeetingContent(summary: summary, noteBlocks: notes)
    }
}

public struct MockTaskExtractionProvider: TaskExtractionProvider {
    public init() {}

    public func extractTasks(from meeting: Meeting, transcriptSegments: [TranscriptSegment]) async throws -> [MeetingTask] {
        let sourceSegments = transcriptSegments.isEmpty ? meeting.transcriptSegments : transcriptSegments
        let owner = meeting.attendees.first ?? SampleData.me
        let collaborator = meeting.attendees.dropFirst().first
        let title = meeting.title

        return [
            MeetingTask(
                title: "Send concise meeting recap",
                notes: "Lead with customer proof and ownership clarity.",
                status: .today,
                priority: .high,
                owner: owner,
                sourceMeetingID: meeting.id,
                sourceMeetingTitle: title,
                sourceTimestamp: sourceSegments.first?.startTime,
                extractionConfidence: 0.9
            ),
            MeetingTask(
                title: "Confirm blocker owner before Friday",
                notes: "Verify who owns the blocker list and when it is due.",
                status: .open,
                priority: .medium,
                owner: collaborator,
                sourceMeetingID: meeting.id,
                sourceMeetingTitle: title,
                sourceTimestamp: sourceSegments.dropFirst().first?.startTime,
                extractionConfidence: 0.84
            )
        ]
    }
}

public struct MockCalendarEventProvider: CalendarEventProvider {
    public init() {}

    public func upcomingEvents(limit: Int) async throws -> [CalendarEvent] {
        Array(SampleData.calendarEvents.prefix(limit))
    }
}

public struct LocalSecondBrainSearchProvider: SecondBrainSearchProvider {
    public init() {}

    public func search(query: String, meetings: [Meeting], tasks: [MeetingTask]) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return meetings.prefix(4).map { meeting in
                SearchResult(
                    title: meeting.title,
                    source: "Meeting",
                    snippet: meeting.summary.isEmpty ? "No summary yet." : meeting.summary,
                    sourceMeetingID: meeting.id
                )
            }
        }

        let meetingResults = meetings.flatMap { meeting -> [SearchResult] in
            var results: [SearchResult] = []

            if meeting.title.localizedCaseInsensitiveContains(trimmed)
                || meeting.summary.localizedCaseInsensitiveContains(trimmed) {
                results.append(
                    SearchResult(
                        title: meeting.title,
                        source: "Meeting",
                        snippet: meeting.summary,
                        sourceMeetingID: meeting.id
                    )
                )
            }

            results += meeting.transcriptSegments
                .filter { $0.text.localizedCaseInsensitiveContains(trimmed) || $0.speaker.displayName.localizedCaseInsensitiveContains(trimmed) }
                .map { segment in
                    SearchResult(
                        title: "\(segment.speaker.displayName) mentioned \(trimmed)",
                        source: meeting.title,
                        snippet: segment.text,
                        sourceMeetingID: meeting.id
                    )
                }

            results += meeting.decisions
                .filter { $0.title.localizedCaseInsensitiveContains(trimmed) || $0.detail.localizedCaseInsensitiveContains(trimmed) }
                .map { decision in
                    SearchResult(
                        title: decision.title,
                        source: "\(meeting.title) · decision",
                        snippet: decision.detail,
                        sourceMeetingID: meeting.id
                    )
                }

            return results
        }

        let taskResults = tasks
            .filter { $0.title.localizedCaseInsensitiveContains(trimmed) || $0.notes.localizedCaseInsensitiveContains(trimmed) }
            .map { task in
                SearchResult(
                    title: task.title,
                    source: task.sourceMeetingTitle ?? "Task",
                    snippet: task.notes.isEmpty ? "Meeting task" : task.notes,
                    sourceMeetingID: task.sourceMeetingID
                )
            }

        return Array((meetingResults + taskResults).prefix(12))
    }
}
