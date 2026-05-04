import XCTest
@testable import RecallOSCore

final class ModelTests: XCTestCase {
    func testAIAdditionFormatsTimestampWithProvenanceArrow() {
        let addition = AIAddition(text: "Context", sourceTimestamp: 764, confidence: 0.9)

        XCTAssertEqual(addition.timestampLabel, "↗ 12:44")
    }

    func testRecordingBannerRecordingStateCannotDismiss() {
        XCTAssertFalse(RecordingBannerState.recording.allowsDismiss)
        XCTAssertFalse(RecordingBannerState.paused.allowsDismiss)
        XCTAssertTrue(RecordingBannerState.preMeeting.allowsDismiss)
        XCTAssertTrue(RecordingBannerState.inProgress.allowsDismiss)
        XCTAssertTrue(RecordingBannerState.adHoc.allowsDismiss)
    }

    func testRecordingSessionMapsLifecycleToBannerState() {
        let recording = RecordingSession(meetingID: SampleData.meetingID, state: .recording)
        let paused = RecordingSession(meetingID: SampleData.meetingID, state: .paused)
        let detected = RecordingSession(meetingID: SampleData.meetingID, state: .detected)

        XCTAssertEqual(recording.bannerState, .recording)
        XCTAssertEqual(paused.bannerState, .paused)
        XCTAssertEqual(detected.bannerState, .inProgress)
        XCTAssertTrue(paused.isActive)
    }

    func testScheduledMeetingAdvancesToInProgressInsideMeetingWindow() {
        let start = Date(timeIntervalSince1970: 1_778_270_400)
        let meeting = Meeting(
            title: "Calendar sync",
            startsAt: start,
            endsAt: start.addingTimeInterval(1_800),
            status: .scheduled
        )

        let advanced = meeting.advancedLifecycle(at: start.addingTimeInterval(60))

        XCTAssertEqual(advanced.status, .inProgress)
    }

    func testCompletedMeetingDoesNotReopenFromCalendarWindow() {
        let start = Date(timeIntervalSince1970: 1_778_270_400)
        let meeting = Meeting(
            title: "Finished sync",
            startsAt: start,
            endsAt: start.addingTimeInterval(1_800),
            status: .completed
        )

        let advanced = meeting.advancedLifecycle(at: start.addingTimeInterval(60))

        XCTAssertEqual(advanced.status, .completed)
    }

    func testSampleMeetingContainsRequiredDomainGraph() {
        let meeting = SampleData.meeting

        XCTAssertEqual(meeting.title, "AI CoE weekly")
        XCTAssertFalse(meeting.transcriptSegments.isEmpty)
        XCTAssertFalse(meeting.tasks.isEmpty)
        XCTAssertFalse(meeting.screenshots.isEmpty)
        XCTAssertFalse(meeting.decisions.isEmpty)
        XCTAssertFalse(meeting.topics.isEmpty)
    }

    func testMeetingTaskKeepsSourceProvenance() {
        let task = SampleData.tasks[0]

        XCTAssertEqual(task.sourceMeetingTitle, "AI CoE weekly")
        XCTAssertEqual(task.sourceTimestamp, 764)
        XCTAssertEqual(task.priority, .high)
    }

    func testTaskListDoneFilterOnlyReturnsCompletedTasks() {
        let sections = TaskListFilter.done.sections(for: SampleData.tasks)
        let visibleTasks = sections.flatMap(\.tasks)

        XCTAssertEqual(sections.map(\.title), ["Done"])
        XCTAssertFalse(visibleTasks.isEmpty)
        XCTAssertTrue(visibleTasks.allSatisfy { $0.status == .done })
    }

    func testTaskListAllOpenFilterExcludesCompletedTasks() {
        let sections = TaskListFilter.allOpen.sections(for: SampleData.tasks)
        let visibleTasks = sections.flatMap(\.tasks)

        XCTAssertFalse(visibleTasks.isEmpty)
        XCTAssertTrue(visibleTasks.allSatisfy { $0.status != .done })
        XCTAssertFalse(sections.contains { $0.title == "Done" })
    }

    func testTaskListTodayFilterOnlyShowsCompletedTasksDoneToday() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let doneToday = MeetingTask(title: "Done today", status: .done, completedAt: now)
        let doneWithoutTimestamp = MeetingTask(title: "Done without timestamp", status: .done)
        let doneYesterday = MeetingTask(title: "Done yesterday", status: .done, completedAt: yesterday)

        let doneTodaySection = TaskListFilter.today.sections(
            for: [doneToday, doneWithoutTimestamp, doneYesterday],
            now: now
        ).first { $0.title == "Done today" }

        XCTAssertEqual(doneTodaySection?.tasks, [doneToday])
    }

    func testTaskListTodayFilterDoesNotTreatPriorityAsOverdue() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let highNoDue = MeetingTask(title: "High priority no due date", status: .open, priority: .high)
        let highFutureDue = MeetingTask(title: "High priority future due", status: .open, priority: .high, dueAt: tomorrow)
        let highToday = MeetingTask(title: "High priority today", status: .today, priority: .high)
        let overdue = MeetingTask(title: "Actually overdue", status: .open, dueAt: yesterday)

        let sections = TaskListFilter.today.sections(
            for: [highNoDue, highFutureDue, highToday, overdue],
            now: now
        )

        XCTAssertEqual(sections.first { $0.title == "Overdue" }?.tasks, [overdue])
        XCTAssertEqual(sections.first { $0.title == "Today" }?.tasks, [highToday])
    }

    func testTaskStoreMoveUpdatesStatusAndCompletionDate() {
        let task = MeetingTask(title: "Prepare recap", status: .open)
        let completedAt = Date(timeIntervalSince1970: 42)

        let completed = TaskStore.moved(tasks: [task], taskIDs: [task.id], to: .done, completedAt: completedAt)
        XCTAssertEqual(completed[0].status, .done)
        XCTAssertEqual(completed[0].completedAt, completedAt)

        let reopened = TaskStore.moved(tasks: completed, taskIDs: [task.id], to: .open)
        XCTAssertEqual(reopened[0].status, .open)
        XCTAssertNil(reopened[0].completedAt)
    }

    func testSyncBackedModelsPreserveConvexID() {
        let meeting = Meeting(convexID: "meetings:abc", title: "Sync test", startsAt: Date(), endsAt: Date())
        let task = MeetingTask(convexID: "tasks:abc", title: "Sync task")

        XCTAssertEqual(meeting.convexID, "meetings:abc")
        XCTAssertEqual(task.convexID, "tasks:abc")
    }

    func testFixtureRepositoryPersistsTaskMoveWithinRepository() async throws {
        let repository = FixtureRecallOSRepository()
        let task = try await repository.listTasks(forMeeting: SampleData.meetingID)[0]

        try await repository.moveTasks([task.id], to: .done)
        let moved = try await repository.listTasks(forMeeting: SampleData.meetingID)
            .first { $0.id == task.id }

        XCTAssertEqual(moved?.status, .done)
        XCTAssertNotNil(moved?.completedAt)
    }

    func testFixtureRepositoryCreatesAndUpdatesMeetings() async throws {
        let repository = FixtureRecallOSRepository(meetings: [], tasks: [])
        var meeting = Meeting(title: "New recording", startsAt: Date(), endsAt: Date().addingTimeInterval(600))

        let created = try await repository.createMeeting(meeting)
        let meetingIDs = try await repository.listMeetings().map(\.id)
        XCTAssertEqual(meetingIDs, [created.id])

        meeting = created
        meeting.status = .completed
        meeting.tasks = [MeetingTask(title: "Follow up", sourceMeetingID: meeting.id)]

        let updated = try await repository.updateMeeting(meeting)
        let savedTasks = try await repository.listTasks(forMeeting: meeting.id)
        XCTAssertEqual(updated.status, .completed)
        XCTAssertEqual(savedTasks.count, 1)
    }

    @MainActor
    func testAppStoreLoadsFixtureDataAndOptimisticallyMovesTasks() async {
        let store = RecallOSAppStore.fixture()
        await store.load()

        guard let task = store.tasks.first(where: { $0.status != .done }) else {
            return XCTFail("Expected fixture task")
        }

        await store.moveTasks([task.id], to: .done)

        XCTAssertEqual(store.tasks.first { $0.id == task.id }?.status, .done)
        XCTAssertNil(store.syncError)
    }

    @MainActor
    func testAppStoreRunsMockRecordingEnhancementAndTaskExtraction() async throws {
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [SampleData.meeting], tasks: []),
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000),
            meetings: [SampleData.meeting],
            selectedMeeting: SampleData.meeting,
            tasks: []
        )

        await store.startRecording()
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(store.recordingSession?.state, .recording)
        XCTAssertFalse(store.selectedMeeting?.transcriptSegments.isEmpty ?? true)

        await store.stopAndEnhanceRecording()

        XCTAssertEqual(store.recordingSession?.state, .completed)
        XCTAssertEqual(store.selectedMeeting?.status, .completed)
        XCTAssertFalse(store.selectedMeeting?.userNotes.isEmpty ?? true)
        XCTAssertFalse(store.tasks.isEmpty)
        XCTAssertNil(store.syncError)
    }

    @MainActor
    func testRecordingContinuesAgainstSessionMeetingWhenSelectionChanges() async throws {
        let recordingMeetingID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let otherMeetingID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let start = Date(timeIntervalSince1970: 1_778_270_400)
        let recordingMeeting = Meeting(
            id: recordingMeetingID,
            title: "Recording meeting",
            startsAt: start,
            endsAt: start.addingTimeInterval(45 * 60),
            attendees: [SampleData.me, SampleData.patrick]
        )
        let otherMeeting = Meeting(
            id: otherMeetingID,
            title: "Other meeting",
            startsAt: start.addingTimeInterval(3_600),
            endsAt: start.addingTimeInterval(5_400),
            attendees: [SampleData.lily]
        )
        let repository = FixtureRecallOSRepository(meetings: [recordingMeeting, otherMeeting], tasks: [])
        let store = RecallOSAppStore(
            repository: repository,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000),
            meetings: [recordingMeeting, otherMeeting],
            selectedMeeting: recordingMeeting,
            tasks: []
        )

        await store.startRecording()
        await store.selectMeeting(otherMeetingID)
        try await Task.sleep(nanoseconds: 20_000_000)

        let streamedRecordingMeeting = try XCTUnwrap(store.meetings.first { $0.id == recordingMeetingID })
        XCTAssertFalse(streamedRecordingMeeting.transcriptSegments.isEmpty)
        XCTAssertEqual(store.selectedMeeting?.id, otherMeetingID)

        await store.stopAndEnhanceRecording()

        let completedRecordingMeeting = try XCTUnwrap(store.meetings.first { $0.id == recordingMeetingID })
        XCTAssertEqual(completedRecordingMeeting.status, .completed)
        XCTAssertFalse(completedRecordingMeeting.userNotes.isEmpty)
        XCTAssertEqual(store.recordingSession?.state, .completed)
        XCTAssertEqual(store.selectedMeeting?.id, otherMeetingID)
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertNil(store.syncError)
    }

    @MainActor
    func testStartRecordingIsNoOpWhileRecordingIsActive() async throws {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000),
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: []
        )

        await store.startRecording()
        try await Task.sleep(nanoseconds: 20_000_000)
        let streamedSegmentCount = store.selectedMeeting?.transcriptSegments.count
        await store.startRecording()

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.startCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .recording)
        XCTAssertEqual(store.selectedMeeting?.transcriptSegments.count, streamedSegmentCount)
        XCTAssertEqual(store.workflowMessage, "Recording already in progress")
    }

    @MainActor
    func testStopAndEnhanceUsesTranscriptSegmentsYieldedDuringAudioStop() async throws {
        let start = Date(timeIntervalSince1970: 1_778_270_400)
        let meeting = Meeting(
            title: "Final transcript meeting",
            startsAt: start,
            endsAt: start.addingTimeInterval(45 * 60),
            attendees: [SampleData.me]
        )
        let finalSegment = TranscriptSegment(
            meetingID: meeting.id,
            speaker: SampleData.me,
            startTime: 321,
            endTime: 328,
            text: "Final buffered transcript segment",
            confidence: 0.91
        )
        let captureProvider = FinalSegmentOnStopCaptureProvider(finalSegment: finalSegment)
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: captureProvider,
            transcriptionProvider: captureProvider,
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: []
        )

        await store.startRecording()
        await captureProvider.waitUntilStreamAttached()
        await store.stopAndEnhanceRecording()

        let completedMeeting = try XCTUnwrap(store.selectedMeeting)
        XCTAssertEqual(completedMeeting.status, .completed)
        XCTAssertTrue(completedMeeting.transcriptSegments.contains(finalSegment))
        XCTAssertEqual(store.tasks.first?.sourceTimestamp, finalSegment.startTime)
    }

    @MainActor
    func testCreateOrSelectMeetingFromCalendarEventAvoidsDuplicates() async throws {
        let event = CalendarEvent(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            externalID: "external-event",
            title: "Calendar planning",
            startsAt: Date(timeIntervalSince1970: 1_778_270_400),
            endsAt: Date(timeIntervalSince1970: 1_778_273_100),
            attendees: [SampleData.me, SampleData.patrick]
        )
        let repository = FixtureRecallOSRepository(meetings: [], tasks: [])
        let store = RecallOSAppStore(repository: repository, meetings: [], tasks: [])

        let first = await store.createOrSelectMeeting(for: event, now: event.startsAt.addingTimeInterval(60))
        let second = await store.createOrSelectMeeting(for: event, now: event.startsAt.addingTimeInterval(60))

        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(store.meetings.count, 1)
        XCTAssertEqual(store.selectedMeeting?.calendarEventID, event.id)
        XCTAssertEqual(store.selectedMeeting?.status, .inProgress)
    }

    @MainActor
    func testCreateOrSelectMeetingUpdatesScheduledEventBackedMeeting() async throws {
        let eventID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let start = Date(timeIntervalSince1970: 1_778_270_400)
        let existing = Meeting(
            title: "Old title",
            startsAt: start,
            endsAt: start.addingTimeInterval(1_800),
            attendees: [SampleData.me],
            calendarEventID: eventID,
            status: .scheduled
        )
        let updatedEvent = CalendarEvent(
            id: eventID,
            externalID: "updated-event",
            title: "Updated calendar planning",
            startsAt: start.addingTimeInterval(300),
            endsAt: start.addingTimeInterval(3_000),
            location: "Zoom",
            attendees: [SampleData.me, SampleData.patrick, SampleData.lily]
        )
        let repository = FixtureRecallOSRepository(meetings: [existing], tasks: [])
        let store = RecallOSAppStore(repository: repository, meetings: [existing], selectedMeeting: existing, tasks: [])

        let selected = await store.createOrSelectMeeting(for: updatedEvent, now: updatedEvent.startsAt.addingTimeInterval(60))

        XCTAssertEqual(selected?.id, existing.id)
        XCTAssertEqual(store.meetings.count, 1)
        XCTAssertEqual(store.selectedMeeting?.title, updatedEvent.title)
        XCTAssertEqual(store.selectedMeeting?.attendees.count, 3)
        XCTAssertEqual(store.selectedMeeting?.status, .inProgress)
    }

    @MainActor
    func testCalendarProviderFailureFallsBackToMockEvents() async {
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [SampleData.meeting], tasks: SampleData.tasks),
            calendarProvider: ThrowingCalendarEventProvider(),
            meetings: [SampleData.meeting],
            selectedMeeting: SampleData.meeting,
            tasks: SampleData.tasks
        )

        await store.refreshUpcomingEvents(limit: 2)

        XCTAssertEqual(store.upcomingEvents.count, 2)
        XCTAssertEqual(store.workflowMessage, "Calendar access is unavailable. Showing sample upcoming events.")
        XCTAssertNil(store.syncError)
    }

    @MainActor
    func testStartRecordingStopsAudioCaptureWhenMeetingUpdateFails() async {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider()
        let store = RecallOSAppStore(
            repository: FailingUpdateRepository(meeting: meeting),
            audioProvider: audioProvider,
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.startCount, 1)
        XCTAssertEqual(audioState.stopCount, 1)
        XCTAssertEqual(store.selectedMeeting?.status, .failed)
        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testAppStoreLocalSearchFindsTranscriptTasksAndDecisions() async throws {
        let meeting = SampleData.meeting
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: SampleData.tasks),
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: SampleData.tasks
        )

        await store.search("Kevin")

        XCTAssertFalse(store.searchResults.isEmpty)
        XCTAssertTrue(store.searchResults.contains { $0.snippet.localizedCaseInsensitiveContains("Kevin") || $0.title.localizedCaseInsensitiveContains("Kevin") })
    }
}

private enum TestRepositoryError: Error {
    case updateFailed
    case calendarFailed
}

private struct ThrowingCalendarEventProvider: CalendarEventProvider {
    func upcomingEvents(limit: Int) async throws -> [CalendarEvent] {
        throw TestRepositoryError.calendarFailed
    }
}

private actor RecordingSpyAudioProvider: AudioCaptureProvider {
    private var startCount = 0
    private var stopCount = 0

    func start(meeting: Meeting) async throws {
        startCount += 1
    }

    func pause() async throws {}

    func resume() async throws {}

    func stop() async throws {
        stopCount += 1
    }

    func state() -> (startCount: Int, stopCount: Int) {
        (startCount, stopCount)
    }
}

private actor FinalSegmentOnStopCaptureProvider: AudioCaptureProvider, TranscriptionProvider {
    private let finalSegment: TranscriptSegment
    private var continuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?

    init(finalSegment: TranscriptSegment) {
        self.finalSegment = finalSegment
    }

    func start(meeting: Meeting) async throws {}

    func pause() async throws {}

    func resume() async throws {}

    func stop() async throws {
        continuation?.yield(finalSegment)
        continuation?.finish()
        await Task.yield()
    }

    func transcriptStream(for meeting: Meeting) async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStreamAttached() async {
        while continuation == nil {
            await Task.yield()
        }
    }
}

private actor FailingUpdateRepository: RecallOSRepository {
    private let meeting: Meeting

    init(meeting: Meeting) {
        self.meeting = meeting
    }

    func listMeetings() async throws -> [Meeting] {
        [meeting]
    }

    func createMeeting(_ meeting: Meeting) async throws -> Meeting {
        meeting
    }

    func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        throw TestRepositoryError.updateFailed
    }

    func listTasks(forMeeting meetingID: UUID?) async throws -> [MeetingTask] {
        []
    }

    func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async throws {}

    func listTranscriptSegments(forMeeting meetingID: UUID) async throws -> [TranscriptSegment] {
        []
    }

    func listScreenshots(forMeeting meetingID: UUID) async throws -> [MeetingScreenshot] {
        []
    }

    func listPeople() async throws -> [Person] {
        []
    }

    func listTopics() async throws -> [Topic] {
        []
    }

    func listDecisions(forMeeting meetingID: UUID?) async throws -> [MeetingDecision] {
        []
    }

    func listSettings() async throws -> [RecallOSSetting] {
        []
    }

    func searchSecondBrain(query: String) async throws -> [SearchResult] {
        []
    }
}
