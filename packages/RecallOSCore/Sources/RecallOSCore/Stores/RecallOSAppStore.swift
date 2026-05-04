import Combine
import Foundation

@MainActor
public final class RecallOSAppStore: ObservableObject {
    @Published public private(set) var meetings: [Meeting]
    @Published public private(set) var selectedMeeting: Meeting?
    @Published public var tasks: [MeetingTask]
    @Published public private(set) var searchResults: [SearchResult]
    @Published public private(set) var upcomingEvents: [CalendarEvent]
    @Published public private(set) var recordingSession: RecordingSession?
    @Published public private(set) var syncError: String?
    @Published public private(set) var isSyncing: Bool
    @Published public private(set) var workflowMessage: String?

    private let repository: any RecallOSRepository
    private let permissionProvider: any RecordingPermissionProvider
    private let audioProvider: any AudioCaptureProvider
    private let transcriptionProvider: any TranscriptionProvider
    private let enhancementProvider: any NoteEnhancementProvider
    private let taskExtractionProvider: any TaskExtractionProvider
    private let calendarProvider: any CalendarEventProvider
    private let secondBrainSearchProvider: any SecondBrainSearchProvider
    private let defaultSearchQuery: String
    private let preservesInitialSyncError: Bool
    private var transcriptTask: Swift.Task<Void, Never>?

    public init(
        repository: any RecallOSRepository,
        permissionProvider: any RecordingPermissionProvider = AllowAllRecordingPermissionProvider(),
        audioProvider: any AudioCaptureProvider = MockAudioCaptureProvider(),
        transcriptionProvider: any TranscriptionProvider = MockTranscriptionProvider(),
        enhancementProvider: any NoteEnhancementProvider = MockNoteEnhancementProvider(),
        taskExtractionProvider: any TaskExtractionProvider = MockTaskExtractionProvider(),
        calendarProvider: any CalendarEventProvider = MockCalendarEventProvider(),
        secondBrainSearchProvider: any SecondBrainSearchProvider = LocalSecondBrainSearchProvider(),
        meetings: [Meeting] = [],
        selectedMeeting: Meeting? = nil,
        tasks: [MeetingTask] = [],
        searchResults: [SearchResult] = [],
        upcomingEvents: [CalendarEvent] = [],
        defaultSearchQuery: String = "",
        syncError: String? = nil,
        workflowMessage: String? = nil,
        preservesInitialSyncError: Bool = false
    ) {
        self.repository = repository
        self.permissionProvider = permissionProvider
        self.audioProvider = audioProvider
        self.transcriptionProvider = transcriptionProvider
        self.enhancementProvider = enhancementProvider
        self.taskExtractionProvider = taskExtractionProvider
        self.calendarProvider = calendarProvider
        self.secondBrainSearchProvider = secondBrainSearchProvider
        self.meetings = meetings
        self.selectedMeeting = selectedMeeting
        self.tasks = tasks
        self.searchResults = searchResults
        self.upcomingEvents = upcomingEvents
        self.defaultSearchQuery = defaultSearchQuery
        self.preservesInitialSyncError = preservesInitialSyncError
        self.syncError = syncError
        self.isSyncing = false
        self.workflowMessage = workflowMessage
    }

    deinit {
        transcriptTask?.cancel()
    }

    public static func fixture(syncError: String? = nil, workflowMessage: String? = nil) -> RecallOSAppStore {
        RecallOSAppStore(
            repository: FixtureRecallOSRepository(),
            meetings: [SampleData.meeting],
            selectedMeeting: SampleData.meeting,
            tasks: SampleData.tasks,
            searchResults: SampleData.searchResults,
            upcomingEvents: SampleData.calendarEvents,
            syncError: syncError,
            workflowMessage: workflowMessage,
            preservesInitialSyncError: syncError != nil
        )
    }

    public var isRecordingActive: Bool {
        recordingSession?.isActive == true
    }

    public func load() async {
        isSyncing = true
        defer { isSyncing = false }
        let initialSyncError = syncError

        do {
            meetings = try await repository.listMeetings()
            selectedMeeting = selectedMeeting.flatMap { selected in
                meetings.first(where: { $0.id == selected.id })
            } ?? meetings.first
            tasks = try await repository.listTasks(forMeeting: selectedMeeting?.id)
            await refreshMeetingLifecycle()
            await refreshUpcomingEvents(limit: 5)
            searchResults = try await secondBrainSearchProvider.search(query: defaultSearchQuery, meetings: meetings, tasks: tasks)
            if preservesInitialSyncError {
                syncError = initialSyncError
            } else {
                syncError = nil
            }
        } catch {
            syncError = error.localizedDescription
        }
    }

    public func selectMeeting(_ meetingID: UUID) async {
        selectedMeeting = meetings.first { $0.id == meetingID }
        do {
            tasks = try await repository.listTasks(forMeeting: meetingID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @discardableResult
    public func createMeeting(title: String = "Untitled meeting", startsAt: Date = Date()) async -> Meeting? {
        let meeting = Meeting(
            title: title,
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(45 * 60),
            attendees: [SampleData.me],
            status: .scheduled
        )

        do {
            let saved = try await repository.createMeeting(meeting)
            meetings.insert(saved, at: 0)
            selectedMeeting = saved
            tasks = []
            syncError = nil
            return saved
        } catch {
            syncError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    public func createOrSelectMeeting(for event: CalendarEvent, now: Date = Date()) async -> Meeting? {
        if var existing = meetings.first(where: { $0.calendarEventID == event.id || $0.title == event.title && $0.startsAt == event.startsAt }) {
            if existing.status == .scheduled || existing.status == .inProgress {
                existing.title = event.title
                existing.startsAt = event.startsAt
                existing.endsAt = event.endsAt
                existing.attendees = event.attendees
                existing.calendarEventID = event.id
                existing.status = MeetingLifecycle.initialStatus(startsAt: event.startsAt, endsAt: event.endsAt, at: now)

                do {
                    let saved = try await repository.updateMeeting(existing)
                    upsertMeeting(saved, select: true)
                    tasks = try await repository.listTasks(forMeeting: saved.id)
                    syncError = nil
                    return saved
                } catch {
                    syncError = error.localizedDescription
                    return nil
                }
            } else {
                await selectMeeting(existing.id)
                return selectedMeeting
            }
        }

        let meeting = Meeting(
            title: event.title,
            startsAt: event.startsAt,
            endsAt: event.endsAt,
            attendees: event.attendees,
            calendarEventID: event.id,
            status: MeetingLifecycle.initialStatus(startsAt: event.startsAt, endsAt: event.endsAt, at: now)
        )

        do {
            let saved = try await repository.createMeeting(meeting)
            meetings.insert(saved, at: 0)
            selectedMeeting = saved
            tasks = []
            syncError = nil
            return saved
        } catch {
            syncError = error.localizedDescription
            return nil
        }
    }

    public func refreshUpcomingEvents(limit: Int = 5) async {
        do {
            upcomingEvents = try await calendarProvider.upcomingEvents(limit: limit)
            syncError = nil
        } catch {
            upcomingEvents = (try? await MockCalendarEventProvider().upcomingEvents(limit: limit)) ?? []
            workflowMessage = "Calendar access is unavailable. Showing sample upcoming events."
        }
    }

    public func refreshMeetingLifecycle(now: Date = Date()) async {
        for meeting in meetings {
            let advanced = meeting.advancedLifecycle(at: now)
            guard advanced.status != meeting.status else { continue }

            upsertMeeting(advanced)
            _ = try? await repository.updateMeeting(advanced)
        }
    }

    public func startRecording() async {
        guard var meeting = selectedMeeting else {
            syncError = RecordingWorkflowError.noSelectedMeeting.localizedDescription
            return
        }

        let previousMeeting = meeting
        var didStartAudioCapture = false

        do {
            guard try await permissionProvider.requestMicrophoneAccess() else {
                throw RecordingWorkflowError.microphonePermissionDenied
            }

            try await audioProvider.start(meeting: meeting)
            didStartAudioCapture = true
            meeting.status = .recording
            meeting.transcriptSegments = []
            meeting.summary = meeting.summary.isEmpty ? "Recording in progress. Notes will enhance after stop." : meeting.summary
            upsertMeeting(meeting, select: true)
            _ = try await repository.updateMeeting(meeting)

            recordingSession = RecordingSession(
                meetingID: meeting.id,
                state: .recording,
                startedAt: Date()
            )
            workflowMessage = "Recording started"
            syncError = nil
            streamTranscript(for: meeting)
        } catch {
            if didStartAudioCapture {
                try? await audioProvider.stop()
            }
            upsertMeeting(previousMeeting, select: true)
            markWorkflowFailed(error)
        }
    }

    public func pauseRecording() async {
        guard var session = recordingSession, session.state == .recording else { return }

        do {
            try await audioProvider.pause()
            session.state = .paused
            session.pausedAt = Date()
            recordingSession = session
            workflowMessage = "Recording paused"
            syncError = nil
        } catch {
            markWorkflowFailed(error)
        }
    }

    public func resumeRecording() async {
        guard var session = recordingSession, session.state == .paused else { return }

        do {
            try await audioProvider.resume()
            session.state = .recording
            session.pausedAt = nil
            recordingSession = session
            workflowMessage = "Recording resumed"
            syncError = nil
        } catch {
            markWorkflowFailed(error)
        }
    }

    public func stopAndEnhanceRecording() async {
        guard var session = recordingSession, var meeting = meeting(withID: session.meetingID) else { return }

        do {
            transcriptTask?.cancel()
            transcriptTask = nil
            session.state = .finalizing
            recordingSession = session
            workflowMessage = "Finalizing audio"

            try await audioProvider.stop()
            session.state = .enhancing
            session.stoppedAt = Date()
            recordingSession = session

            meeting.status = .enhancing
            upsertMeeting(meeting)

            let transcriptSegments = meeting.transcriptSegments
            let enhanced = try await enhancementProvider.enhance(meeting: meeting, transcriptSegments: transcriptSegments)
            let extractedTasks = try await taskExtractionProvider.extractTasks(from: meeting, transcriptSegments: transcriptSegments)

            meeting.summary = enhanced.summary
            meeting.userNotes = enhanced.noteBlocks
            meeting.tasks = extractedTasks
            meeting.status = .completed

            let saved = try await repository.updateMeeting(meeting)
            upsertMeeting(saved)
            tasks = try await repository.listTasks(forMeeting: selectedMeeting?.id)
            searchResults = try await secondBrainSearchProvider.search(query: "", meetings: meetings, tasks: tasks)

            session.state = .completed
            recordingSession = session
            workflowMessage = "Notes enhanced and tasks extracted"
            syncError = nil
        } catch {
            markWorkflowFailed(error)
        }
    }

    public func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async {
        let previousTasks = tasks
        tasks = TaskStore.moved(tasks: tasks, taskIDs: taskIDs, to: status)

        do {
            try await repository.moveTasks(taskIDs, to: status)
            tasks = try await repository.listTasks(forMeeting: selectedMeeting?.id)
            if var meeting = selectedMeeting {
                meeting.tasks = tasks.filter { $0.sourceMeetingID == meeting.id }
                upsertMeeting(meeting, select: true)
            }
            syncError = nil
        } catch {
            tasks = previousTasks
            syncError = error.localizedDescription
        }
    }

    public func search(_ query: String) async {
        do {
            searchResults = try await secondBrainSearchProvider.search(query: query, meetings: meetings, tasks: tasks)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func streamTranscript(for meeting: Meeting) {
        transcriptTask?.cancel()
        transcriptTask = Swift.Task { [weak self] in
            guard let self else { return }

            do {
                let stream = try await self.transcriptionProvider.transcriptStream(for: meeting)
                for try await segment in stream {
                    self.appendTranscriptSegment(segment)
                }
            } catch {
                self.markWorkflowFailed(RecordingWorkflowError.transcriptionUnavailable(error.localizedDescription))
            }
        }
    }

    private func appendTranscriptSegment(_ segment: TranscriptSegment) {
        guard var meeting = meeting(withID: segment.meetingID) else { return }
        guard !meeting.transcriptSegments.contains(where: { $0.id == segment.id }) else { return }

        meeting.transcriptSegments.append(segment)
        meeting.transcriptSegments.sort { $0.startTime < $1.startTime }
        upsertMeeting(meeting)
    }

    private func meeting(withID meetingID: UUID) -> Meeting? {
        meetings.first { $0.id == meetingID }
    }

    private func upsertMeeting(_ meeting: Meeting, select: Bool = false) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
        } else {
            meetings.insert(meeting, at: 0)
        }

        if select || selectedMeeting?.id == meeting.id {
            selectedMeeting = meeting
        }
    }

    private func markWorkflowFailed(_ error: Error) {
        var session = recordingSession
        if session == nil, let meetingID = selectedMeeting?.id {
            session = RecordingSession(meetingID: meetingID)
        }
        session?.state = .failed
        session?.errorMessage = error.localizedDescription
        recordingSession = session
        if let meetingID = session?.meetingID, var meeting = meeting(withID: meetingID) {
            meeting.status = .failed
            upsertMeeting(meeting)
        }
        workflowMessage = nil
        syncError = error.localizedDescription
    }
}
