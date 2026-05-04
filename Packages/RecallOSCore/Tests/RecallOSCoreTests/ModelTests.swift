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

    func testAudioCaptureArtifactKeepsLocalMetadata() throws {
        let startedAt = Date(timeIntervalSince1970: 1_778_270_400)
        let endedAt = startedAt.addingTimeInterval(12)
        let artifact = AudioCaptureArtifact(
            convexID: "audio:abc",
            meetingID: SampleData.meetingID,
            startedAt: startedAt,
            endedAt: endedAt,
            microphoneAudioPath: "/tmp/microphone.caf",
            duration: 12,
            byteSize: 4_096,
            diagnostics: "ok"
        )
        let decoded = try JSONDecoder().decode(AudioCaptureArtifact.self, from: JSONEncoder().encode(artifact))

        XCTAssertEqual(decoded.convexID, "audio:abc")
        XCTAssertEqual(decoded.meetingID, SampleData.meetingID)
        XCTAssertEqual(decoded.microphoneAudioPath, "/tmp/microphone.caf")
        XCTAssertEqual(decoded.byteSize, 4_096)
        XCTAssertEqual(Meeting(title: "No artifacts", startsAt: startedAt, endsAt: endedAt).audioArtifacts, [])
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
    func testStopStoresAudioArtifactOnRecordingMeetingWhenSelectionChanges() async throws {
        let recordingMeetingID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let otherMeetingID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
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
        let artifact = AudioCaptureArtifact(
            meetingID: recordingMeetingID,
            startedAt: start,
            endedAt: start.addingTimeInterval(10),
            microphoneAudioPath: "/tmp/recording-meeting/microphone.caf",
            duration: 10,
            byteSize: 2_048,
            diagnostics: "test artifact"
        )
        let audioProvider = ArtifactAudioProvider(artifact: artifact)
        let repository = FixtureRecallOSRepository(meetings: [recordingMeeting, otherMeeting], tasks: [])
        let store = RecallOSAppStore(
            repository: repository,
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000),
            meetings: [recordingMeeting, otherMeeting],
            selectedMeeting: recordingMeeting,
            tasks: []
        )

        await store.startRecording()
        await store.selectMeeting(otherMeetingID)
        await store.stopAndEnhanceRecording()

        let completedRecordingMeeting = try XCTUnwrap(store.meetings.first { $0.id == recordingMeetingID })
        XCTAssertEqual(completedRecordingMeeting.audioArtifacts.map(\.id), [artifact.id])
        XCTAssertEqual(completedRecordingMeeting.audioArtifacts.first?.microphoneAudioPath, artifact.microphoneAudioPath)
        XCTAssertEqual(store.selectedMeeting?.id, otherMeetingID)
        XCTAssertTrue(store.selectedMeeting?.audioArtifacts.isEmpty ?? false)
    }

    @MainActor
    func testDeniedMicrophonePermissionShowsSpecificRecoveryStateWithoutStartingAudio() async throws {
        let meeting = Meeting(
            title: "Permission denied",
            startsAt: Date(timeIntervalSince1970: 1_778_270_400),
            endsAt: Date(timeIntervalSince1970: 1_778_273_100),
            attendees: [SampleData.me]
        )
        let audioProvider = RecordingSpyAudioProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            permissionProvider: DenyingRecordingPermissionProvider(),
            audioProvider: audioProvider,
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: []
        )

        await store.startRecording()

        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertEqual(store.syncError, RecordingWorkflowError.microphonePermissionDenied.localizedDescription)
        XCTAssertEqual(store.selectedMeeting?.status, .failed)
        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.startCount, 0)
        XCTAssertEqual(audioState.stopCount, 0)
    }

    @MainActor
    func testEnhancementFailureLeavesCapturedArtifactOnRecordingMeeting() async throws {
        let meeting = Meeting(
            title: "Artifact before enhancement failure",
            startsAt: Date(timeIntervalSince1970: 1_778_270_400),
            endsAt: Date(timeIntervalSince1970: 1_778_273_100),
            attendees: [SampleData.me]
        )
        let artifact = AudioCaptureArtifact(
            meetingID: meeting.id,
            startedAt: meeting.startsAt,
            endedAt: meeting.startsAt.addingTimeInterval(8),
            microphoneAudioPath: "/tmp/failure/microphone.caf",
            duration: 8,
            byteSize: 1_024,
            diagnostics: "persisted before enhancement"
        )
        let repository = FixtureRecallOSRepository(meetings: [meeting], tasks: [])
        let store = RecallOSAppStore(
            repository: repository,
            audioProvider: ArtifactAudioProvider(artifact: artifact),
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000),
            enhancementProvider: FailingEnhancementProvider(),
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: []
        )

        await store.startRecording()
        await store.stopAndEnhanceRecording()

        let savedMeetings = try await repository.listMeetings()
        let saved = try XCTUnwrap(savedMeetings.first { $0.id == meeting.id })
        XCTAssertEqual(saved.audioArtifacts.map(\.id), [artifact.id])
        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertNotNil(store.syncError)
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
    case enhancementFailed
}

private struct ThrowingCalendarEventProvider: CalendarEventProvider {
    func upcomingEvents(limit: Int) async throws -> [CalendarEvent] {
        throw TestRepositoryError.calendarFailed
    }
}

private struct DenyingRecordingPermissionProvider: RecordingPermissionProvider {
    func requestMicrophoneAccess() async throws -> Bool {
        false
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

    func stop() async throws -> AudioCaptureArtifact? {
        stopCount += 1
        return nil
    }

    func state() -> (startCount: Int, stopCount: Int) {
        (startCount, stopCount)
    }
}

private actor ArtifactAudioProvider: AudioCaptureProvider {
    private let artifact: AudioCaptureArtifact

    init(artifact: AudioCaptureArtifact) {
        self.artifact = artifact
    }

    func start(meeting: Meeting) async throws {}

    func pause() async throws {}

    func resume() async throws {}

    func stop() async throws -> AudioCaptureArtifact? {
        artifact
    }
}

private struct FailingEnhancementProvider: NoteEnhancementProvider {
    func enhance(meeting: Meeting, transcriptSegments: [TranscriptSegment]) async throws -> EnhancedMeetingContent {
        throw TestRepositoryError.enhancementFailed
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
