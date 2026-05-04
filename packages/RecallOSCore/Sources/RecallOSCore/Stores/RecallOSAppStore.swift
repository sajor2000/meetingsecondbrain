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
    private var transcriptTask: Swift.Task<Void, Never>?
    private var isStartingRecording = false
    private var taskMoveGeneration = 0
    private var searchGeneration = 0

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
        defaultSearchQuery: String = ""
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
        self.syncError = nil
        self.isSyncing = false
        self.workflowMessage = nil
    }

    deinit {
        transcriptTask?.cancel()
    }

    public static func fixture() -> RecallOSAppStore {
        RecallOSAppStore(
            repository: FixtureRecallOSRepository(),
            meetings: [SampleData.meeting],
            selectedMeeting: SampleData.meeting,
            tasks: SampleData.tasks,
            searchResults: SampleData.searchResults,
            upcomingEvents: SampleData.calendarEvents
        )
    }

    public var isRecordingActive: Bool {
        recordingSession?.isActive == true
    }

    public func load() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            meetings = try await repository.listMeetings()
            selectedMeeting = selectedMeeting.flatMap { selected in
                meetings.first(where: { $0.id == selected.id })
            } ?? meetings.first
            tasks = try await repository.listTasks(forMeeting: nil)
            if var selectedMeeting {
                selectedMeeting.tasks = tasks.filter { $0.sourceMeetingID == selectedMeeting.id }
                replaceSelectedMeeting(selectedMeeting)
            }
            upcomingEvents = try await calendarProvider.upcomingEvents(limit: 5)
            searchResults = try await secondBrainSearchProvider.search(query: defaultSearchQuery, meetings: meetings, tasks: tasks)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    public func selectMeeting(_ meetingID: UUID) async {
        guard var meeting = meetings.first(where: { $0.id == meetingID }) else { return }
        selectedMeeting = meeting

        do {
            let meetingTasks = try await repository.listTasks(forMeeting: meetingID)
            replaceTasks(forMeeting: meetingID, with: meetingTasks)
            meeting.tasks = meetingTasks
            replaceSelectedMeeting(meeting)
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
            syncError = nil
            return saved
        } catch {
            syncError = error.localizedDescription
            return nil
        }
    }

    public func startRecording() async {
        guard var meeting = selectedMeeting else {
            syncError = RecordingWorkflowError.noSelectedMeeting.localizedDescription
            return
        }
        guard recordingSession?.isActive != true, !isStartingRecording else {
            workflowMessage = "Recording already in progress"
            return
        }

        isStartingRecording = true
        let previousMeeting = meeting
        var didStartAudioCapture = false
        defer { isStartingRecording = false }

        do {
            guard try await permissionProvider.requestMicrophoneAccess() else {
                throw RecordingWorkflowError.microphonePermissionDenied
            }

            try await audioProvider.start(meeting: meeting)
            didStartAudioCapture = true
            meeting.status = .recording
            meeting.transcriptSegments = []
            meeting.summary = meeting.summary.isEmpty ? "Recording in progress. Notes will enhance after stop." : meeting.summary
            replaceSelectedMeeting(meeting)
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
            replaceSelectedMeeting(previousMeeting)
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
        guard var session = recordingSession, var meeting = meeting(for: session.meetingID) else { return }

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

            guard let currentMeeting = self.meeting(for: session.meetingID) else { return }
            meeting = currentMeeting
            meeting.status = .enhancing
            replaceSelectedMeeting(meeting)

            let transcriptSegments = currentMeeting.transcriptSegments
            let enhanced = try await enhancementProvider.enhance(meeting: meeting, transcriptSegments: transcriptSegments)
            let extractedTasks = try await taskExtractionProvider.extractTasks(from: meeting, transcriptSegments: transcriptSegments)

            meeting.summary = enhanced.summary
            meeting.userNotes = enhanced.noteBlocks
            meeting.tasks = extractedTasks
            meeting.status = .completed

            let saved = try await repository.updateMeeting(meeting)
            replaceSelectedMeeting(saved)
            let meetingTasks = try await repository.listTasks(forMeeting: saved.id)
            replaceTasks(forMeeting: saved.id, with: meetingTasks)
            searchResults = try await secondBrainSearchProvider.search(query: "", meetings: meetings, tasks: tasks)

            session.state = .completed
            recordingSession = session
            workflowMessage = "Notes enhanced and tasks extracted"
            syncError = nil
        } catch {
            if var restoredMeeting = self.meeting(for: session.meetingID),
               restoredMeeting.status == .enhancing || restoredMeeting.status == .recording {
                restoredMeeting.status = .inProgress
                replaceSelectedMeeting(restoredMeeting)
                _ = try? await repository.updateMeeting(restoredMeeting)
            }
            markWorkflowFailed(error)
        }
    }

    public func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async {
        taskMoveGeneration += 1
        let moveGeneration = taskMoveGeneration
        let previousTasksByID = Dictionary(uniqueKeysWithValues: tasks.filter { taskIDs.contains($0.id) }.map { ($0.id, $0) })
        tasks = TaskStore.moved(tasks: tasks, taskIDs: taskIDs, to: status)
        updateSelectedMeetingTasks()

        do {
            try await repository.moveTasks(taskIDs, to: status)
            tasks = try await repository.listTasks(forMeeting: nil)
            updateSelectedMeetingTasks()
            if moveGeneration == taskMoveGeneration {
                syncError = nil
            }
        } catch {
            if moveGeneration == taskMoveGeneration {
                tasks = tasks.map { task in
                    previousTasksByID[task.id] ?? task
                }
                updateSelectedMeetingTasks()
                syncError = error.localizedDescription
            }
        }
    }

    public func search(_ query: String) async {
        searchGeneration += 1
        let generation = searchGeneration

        do {
            let results = try await secondBrainSearchProvider.search(query: query, meetings: meetings, tasks: tasks)
            guard generation == searchGeneration else { return }
            searchResults = results
            syncError = nil
        } catch {
            if generation == searchGeneration {
                syncError = error.localizedDescription
            }
        }
    }

    private func streamTranscript(for meeting: Meeting) {
        transcriptTask?.cancel()
        let transcriptionProvider = transcriptionProvider

        transcriptTask = Swift.Task.detached { [weak self, transcriptionProvider, meeting] in
            do {
                let stream = try await transcriptionProvider.transcriptStream(for: meeting)
                for try await segment in stream {
                    guard !Swift.Task.isCancelled else { return }
                    await self?.appendTranscriptSegment(segment)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Swift.Task.isCancelled else { return }
                await self?.handleTranscriptStreamFailure(error, meetingID: meeting.id)
            }
        }
    }

    private func appendTranscriptSegment(_ segment: TranscriptSegment) {
        guard var meeting = meeting(for: segment.meetingID) else { return }
        if let recordingSession,
           recordingSession.meetingID == segment.meetingID,
           recordingSession.state != .recording,
           recordingSession.state != .paused {
            return
        }
        guard !meeting.transcriptSegments.contains(where: { $0.id == segment.id }) else { return }

        meeting.transcriptSegments.append(segment)
        meeting.transcriptSegments.sort { $0.startTime < $1.startTime }
        if selectedMeeting?.id == meeting.id {
            selectedMeeting = meeting
        }
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
        } else {
            meetings.insert(meeting, at: 0)
        }
    }

    private func meeting(for meetingID: UUID) -> Meeting? {
        meetings.first { $0.id == meetingID } ?? selectedMeeting.flatMap { selected in
            selected.id == meetingID ? selected : nil
        }
    }

    private func handleTranscriptStreamFailure(_ error: Error, meetingID: UUID) async {
        guard recordingSession?.meetingID == meetingID, recordingSession?.isActive == true else { return }

        try? await audioProvider.stop()
        transcriptTask = nil
        if var meeting = meeting(for: meetingID) {
            meeting.status = .inProgress
            replaceSelectedMeeting(meeting)
            _ = try? await repository.updateMeeting(meeting)
        }
        markWorkflowFailed(RecordingWorkflowError.transcriptionUnavailable(error.localizedDescription))
    }

    private func replaceSelectedMeeting(_ meeting: Meeting) {
        selectedMeeting = meeting
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
        } else {
            meetings.insert(meeting, at: 0)
        }
    }

    private func replaceTasks(forMeeting meetingID: UUID, with meetingTasks: [MeetingTask]) {
        let meetingTaskIDs = Set(meetingTasks.map(\.id))
        tasks.removeAll { task in
            task.sourceMeetingID == meetingID && !meetingTaskIDs.contains(task.id)
        }

        for task in meetingTasks {
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = task
            } else {
                tasks.append(task)
            }
        }
    }

    private func updateSelectedMeetingTasks() {
        if var meeting = selectedMeeting {
            meeting.tasks = tasks.filter { $0.sourceMeetingID == meeting.id }
            replaceSelectedMeeting(meeting)
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
        workflowMessage = nil
        syncError = error.localizedDescription
    }
}
