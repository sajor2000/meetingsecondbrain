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

    func testTaskListTodayExcludesDoneTasksWithoutCompletionDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let undatedDone = MeetingTask(title: "Old done", status: .done, completedAt: nil)
        let doneToday = MeetingTask(title: "Done today", status: .done, completedAt: now)

        let sections = TaskListFilter.today.sections(for: [undatedDone, doneToday], now: now)
        let doneTodayTasks = sections.first { $0.title == "Done today" }?.tasks ?? []

        XCTAssertEqual(doneTodayTasks.map(\.id), [doneToday.id])
    }

    func testTaskListTodayDoesNotDuplicateHighPriorityTodayTasksAsOverdue() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let highPriorityToday = MeetingTask(title: "High focus", status: .today, priority: .high)

        let sections = TaskListFilter.today.sections(for: [highPriorityToday], now: now)

        XCTAssertNil(sections.first { $0.title == "Overdue" })
        XCTAssertEqual(sections.first { $0.title == "Today" }?.tasks.map(\.id), [highPriorityToday.id])
    }

    func testTaskListTodayDoesNotDuplicateOverdueTodayTasks() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let overdueToday = MeetingTask(title: "Past due focus", status: .today, dueAt: now.addingTimeInterval(-60))

        let sections = TaskListFilter.today.sections(for: [overdueToday], now: now)

        XCTAssertEqual(sections.first { $0.title == "Overdue" }?.tasks.map(\.id), [overdueToday.id])
        XCTAssertNil(sections.first { $0.title == "Today" })
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

    func testTaskBoardDropRoutesCallbacksAndFallbackMutation() {
        let task = MeetingTask(title: "Move me", status: .open)
        var callbackTasks = [task]
        var callbackIDs: [UUID] = []
        var callbackStatus: TaskStatus?

        let handledByCallback = TaskBoardDropHandler.apply(
            items: [task.id.uuidString, "not-a-uuid"],
            to: .today,
            tasks: &callbackTasks
        ) { ids, status in
            callbackIDs = ids
            callbackStatus = status
        }

        XCTAssertTrue(handledByCallback)
        XCTAssertEqual(callbackIDs, [task.id])
        XCTAssertEqual(callbackStatus, .today)
        XCTAssertEqual(callbackTasks[0].status, .open)

        var fallbackTasks = [task]
        let handledByFallback = TaskBoardDropHandler.apply(items: [task.id.uuidString], to: .done, tasks: &fallbackTasks)
        XCTAssertTrue(handledByFallback)
        XCTAssertEqual(fallbackTasks[0].status, .done)
        XCTAssertNotNil(fallbackTasks[0].completedAt)

        let handledInvalidDrop = TaskBoardDropHandler.apply(items: ["not-a-uuid"], to: .waiting, tasks: &fallbackTasks)
        XCTAssertFalse(handledInvalidDrop)
        XCTAssertEqual(fallbackTasks[0].status, .done)
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
    func testAppStoreRollsBackOptimisticTaskMoveAfterRepositoryFailure() async {
        let meeting = SampleData.meeting
        let task = MeetingTask(title: "Rollback me", status: .open, sourceMeetingID: meeting.id)
        var selected = meeting
        selected.tasks = [task]
        let store = RecallOSAppStore(
            repository: FailingMoveRepository(meetings: [selected], tasks: [task]),
            meetings: [selected],
            selectedMeeting: selected,
            tasks: [task]
        )

        await store.moveTasks([task.id], to: .done)

        XCTAssertEqual(store.tasks.first { $0.id == task.id }?.status, .open)
        XCTAssertEqual(store.selectedMeeting?.tasks.first { $0.id == task.id }?.status, .open)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testAppStoreKeepsGlobalTasksAfterMeetingSelection() async {
        let firstMeeting = Meeting(title: "First", startsAt: Date(), endsAt: Date().addingTimeInterval(600))
        let secondMeeting = Meeting(title: "Second", startsAt: Date(), endsAt: Date().addingTimeInterval(600))
        let firstTask = MeetingTask(title: "First task", sourceMeetingID: firstMeeting.id)
        let secondTask = MeetingTask(title: "Second task", sourceMeetingID: secondMeeting.id)
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [firstMeeting, secondMeeting], tasks: [firstTask, secondTask])
        )

        await store.load()
        await store.selectMeeting(secondMeeting.id)

        XCTAssertEqual(Set(store.tasks.map(\.id)), Set([firstTask.id, secondTask.id]))
        XCTAssertEqual(store.selectedMeeting?.id, secondMeeting.id)
        XCTAssertEqual(store.selectedMeeting?.tasks.map(\.id), [secondTask.id])

        await store.search("First task")
        XCTAssertTrue(store.searchResults.contains { $0.title == "First task" })
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
        await waitUntil {
            store.recordingSession?.state == .recording && !(store.selectedMeeting?.transcriptSegments.isEmpty ?? true)
        }

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
        XCTAssertEqual(store.selectedMeeting?.status, meeting.status)
        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testStartRecordingDeniedMicrophoneDoesNotStartCapture() async {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            permissionProvider: DenyingRecordingPermissionProvider(),
            audioProvider: audioProvider,
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.startCount, 0)
        XCTAssertEqual(audioState.stopCount, 0)
        XCTAssertEqual(store.selectedMeeting?.status, meeting.status)
        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testStartRecordingIsIdempotentWhileActive() async {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000_000_000),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()
        await store.startRecording()

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.startCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .recording)
        XCTAssertEqual(store.workflowMessage, "Recording already in progress")
    }

    @MainActor
    func testConcurrentStartRecordingOnlyStartsCaptureOnce() async {
        let meeting = SampleData.meeting
        let permissionProvider = DelayedRecordingPermissionProvider()
        let audioProvider = RecordingSpyAudioProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            permissionProvider: permissionProvider,
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000_000_000),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        let firstStart = Task { @MainActor in
            await store.startRecording()
        }
        await waitUntilAsync {
            await permissionProvider.hasPendingRequest
        }

        await store.startRecording()
        await permissionProvider.allow()
        await firstStart.value

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.startCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .recording)
    }

    @MainActor
    func testPauseAndResumeRecordingUpdateSessionAndProvider() async {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000_000_000),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()
        await store.pauseRecording()

        var audioState = await audioProvider.state()
        XCTAssertEqual(audioState.pauseCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .paused)
        XCTAssertNotNil(store.recordingSession?.pausedAt)
        XCTAssertEqual(store.workflowMessage, "Recording paused")

        await store.resumeRecording()

        audioState = await audioProvider.state()
        XCTAssertEqual(audioState.resumeCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .recording)
        XCTAssertNil(store.recordingSession?.pausedAt)
        XCTAssertEqual(store.workflowMessage, "Recording resumed")
    }

    @MainActor
    func testPauseRecordingFailureMarksWorkflowFailed() async {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider(failOnPause: true)
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000_000_000),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()
        await store.pauseRecording()

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.pauseCount, 1)
        XCTAssertEqual(audioState.stopCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertEqual(store.selectedMeeting?.status, .inProgress)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testResumeRecordingFailureMarksWorkflowFailed() async {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider(failOnResume: true)
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000_000_000),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()
        await store.pauseRecording()
        let pausedAt = store.recordingSession?.pausedAt
        await store.resumeRecording()

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.resumeCount, 1)
        XCTAssertEqual(audioState.stopCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertEqual(store.recordingSession?.pausedAt, pausedAt)
        XCTAssertEqual(store.selectedMeeting?.status, .inProgress)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testOlderFailedTaskMoveDoesNotRollbackNewerSuccessfulMove() async {
        let meeting = SampleData.meeting
        let task = MeetingTask(title: "Race move", status: .open, sourceMeetingID: meeting.id)
        var selected = meeting
        selected.tasks = [task]
        let repository = OverlappingMoveRepository(meetings: [selected], tasks: [task])
        let store = RecallOSAppStore(
            repository: repository,
            meetings: [selected],
            selectedMeeting: selected,
            tasks: [task]
        )

        let firstMove = Task { @MainActor in
            await store.moveTasks([task.id], to: .done)
        }
        await waitUntilAsync {
            await repository.isFirstMoveWaiting
        }

        await store.moveTasks([task.id], to: .today)
        await repository.failFirstMove()
        await firstMove.value

        XCTAssertEqual(store.tasks.first { $0.id == task.id }?.status, .today)
        XCTAssertEqual(store.selectedMeeting?.tasks.first { $0.id == task.id }?.status, .today)
        XCTAssertNil(store.syncError)
    }

    @MainActor
    func testOlderFailedTaskMoveRollsBackWhenNewerMoveIsForDifferentTask() async {
        let meeting = SampleData.meeting
        let firstTask = MeetingTask(title: "First race move", status: .open, sourceMeetingID: meeting.id)
        let secondTask = MeetingTask(title: "Second race move", status: .open, sourceMeetingID: meeting.id)
        var selected = meeting
        selected.tasks = [firstTask, secondTask]
        let repository = OverlappingMoveRepository(meetings: [selected], tasks: [firstTask, secondTask])
        let store = RecallOSAppStore(
            repository: repository,
            meetings: [selected],
            selectedMeeting: selected,
            tasks: [firstTask, secondTask]
        )

        let firstMove = Task { @MainActor in
            await store.moveTasks([firstTask.id], to: .done)
        }
        await waitUntilAsync {
            await repository.isFirstMoveWaiting
        }

        await store.moveTasks([secondTask.id], to: .today)
        await repository.failFirstMove()
        await firstMove.value

        XCTAssertEqual(store.tasks.first { $0.id == firstTask.id }?.status, .open)
        XCTAssertEqual(store.tasks.first { $0.id == secondTask.id }?.status, .today)
        XCTAssertEqual(store.selectedMeeting?.tasks.first { $0.id == firstTask.id }?.status, .open)
        XCTAssertEqual(store.selectedMeeting?.tasks.first { $0.id == secondTask.id }?.status, .today)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testOlderSuccessfulTaskMoveDoesNotOverwriteNewerMoveForSameTask() async {
        let meeting = SampleData.meeting
        let task = MeetingTask(title: "Race move success", status: .open, sourceMeetingID: meeting.id)
        var selected = meeting
        selected.tasks = [task]
        let repository = OverlappingMoveRepository(meetings: [selected], tasks: [task])
        let store = RecallOSAppStore(
            repository: repository,
            meetings: [selected],
            selectedMeeting: selected,
            tasks: [task]
        )

        let firstMove = Task { @MainActor in
            await store.moveTasks([task.id], to: .done)
        }
        await waitUntilAsync {
            await repository.isFirstMoveWaiting
        }

        await store.moveTasks([task.id], to: .today)
        await repository.completeFirstMove()
        await firstMove.value

        XCTAssertEqual(store.tasks.first { $0.id == task.id }?.status, .today)
        XCTAssertEqual(store.selectedMeeting?.tasks.first { $0.id == task.id }?.status, .today)
        XCTAssertNil(store.syncError)
    }

    @MainActor
    func testTranscriptionFailureStopsCaptureAndMarksWorkflowFailed() async throws {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider()
        let repository = FixtureRecallOSRepository(meetings: [meeting], tasks: [])
        let store = RecallOSAppStore(
            repository: repository,
            audioProvider: audioProvider,
            transcriptionProvider: ThrowingTranscriptionProvider(),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()
        await waitUntil {
            store.recordingSession?.state == .failed
        }

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.startCount, 1)
        XCTAssertEqual(audioState.stopCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertEqual(store.selectedMeeting?.status, .inProgress)
        let storedMeetings = try await repository.listMeetings()
        let storedMeeting = try XCTUnwrap(storedMeetings.first)
        XCTAssertEqual(storedMeeting.status, .inProgress)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testEnhancementFailureRestoresNonEnhancingMeetingStatus() async throws {
        let meeting = SampleData.meeting
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000),
            enhancementProvider: FailingEnhancementProvider(),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()
        await waitUntil {
            !(store.selectedMeeting?.transcriptSegments.isEmpty ?? true)
        }
        await store.stopAndEnhanceRecording()

        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertEqual(store.selectedMeeting?.status, .inProgress)
        XCTAssertNotEqual(store.meetings.first { $0.id == meeting.id }?.status, .enhancing)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testStopFailureRestoresRecordingMeetingStatus() async throws {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider(failOnStop: true)
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()
        await waitUntil {
            !(store.selectedMeeting?.transcriptSegments.isEmpty ?? true)
        }
        await store.stopAndEnhanceRecording()

        let audioState = await audioProvider.state()
        XCTAssertEqual(audioState.stopCount, 1)
        XCTAssertEqual(store.recordingSession?.state, .failed)
        XCTAssertEqual(store.selectedMeeting?.status, .inProgress)
        XCTAssertNotEqual(store.meetings.first { $0.id == meeting.id }?.status, .recording)
        XCTAssertNotNil(store.syncError)
    }

    @MainActor
    func testCompletedRecordingCannotBeEnhancedAgainViaStopAction() async throws {
        let meeting = SampleData.meeting
        let audioProvider = RecordingSpyAudioProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: audioProvider,
            transcriptionProvider: MockTranscriptionProvider(delayNanoseconds: 1_000),
            meetings: [meeting],
            selectedMeeting: meeting
        )

        await store.startRecording()
        await waitUntil {
            !(store.selectedMeeting?.transcriptSegments.isEmpty ?? true)
        }
        await store.stopAndEnhanceRecording()
        let audioStateAfterCompletion = await audioProvider.state()

        await store.stopAndEnhanceRecording()

        let finalAudioState = await audioProvider.state()
        XCTAssertEqual(audioStateAfterCompletion.stopCount, 1)
        XCTAssertEqual(finalAudioState.stopCount, audioStateAfterCompletion.stopCount)
        XCTAssertEqual(store.recordingSession?.state, .completed)
        XCTAssertEqual(store.selectedMeeting?.status, .completed)
    }

    @MainActor
    func testStopAndEnhanceUsesRecordingMeetingAfterSelectionChanges() async throws {
        let recordingMeeting = Meeting(
            title: "Recording meeting",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(1_800),
            attendees: [SampleData.me]
        )
        let otherMeeting = Meeting(
            title: "Other meeting",
            startsAt: Date().addingTimeInterval(3_600),
            endsAt: Date().addingTimeInterval(5_400),
            attendees: [SampleData.patrick]
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
        await waitUntil {
            !(store.meetings.first { $0.id == recordingMeeting.id }?.transcriptSegments.isEmpty ?? true)
        }
        await store.selectMeeting(otherMeeting.id)

        await store.stopAndEnhanceRecording()

        XCTAssertEqual(store.selectedMeeting?.id, recordingMeeting.id)
        XCTAssertEqual(store.selectedMeeting?.status, .completed)
        XCTAssertEqual(store.meetings.first { $0.id == otherMeeting.id }?.status, .scheduled)
        XCTAssertFalse(store.meetings.first { $0.id == recordingMeeting.id }?.userNotes.isEmpty ?? true)
    }

    @MainActor
    func testTranscriptSegmentYieldedWhileStoppingDoesNotOverwriteFinalizedMeeting() async {
        let meeting = Meeting(title: "Race meeting", startsAt: Date(), endsAt: Date().addingTimeInterval(600), attendees: [SampleData.me])
        let transcriptProvider = ControlledTranscriptionProvider()
        let audioProvider = SuspendingStopAudioProvider()
        let raceSegment = TranscriptSegment(
            meetingID: meeting.id,
            speaker: SampleData.me,
            startTime: 12,
            endTime: 18,
            text: "should not arrive after finalizing",
            confidence: 0.9
        )
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            audioProvider: audioProvider,
            transcriptionProvider: transcriptProvider,
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: []
        )

        await store.startRecording()
        await waitUntilAsync { await transcriptProvider.isReady }

        let stopTask = Task { @MainActor in
            await store.stopAndEnhanceRecording()
        }
        await waitUntilAsync { await audioProvider.isStopping }
        await transcriptProvider.yield(raceSegment)
        await transcriptProvider.finish()
        await audioProvider.finishStop()
        await stopTask.value

        XCTAssertEqual(store.recordingSession?.state, .completed)
        XCTAssertFalse(store.selectedMeeting?.transcriptSegments.contains(raceSegment) ?? true)
    }

    @MainActor
    func testLateTranscriptSegmentsStayWithRecordingMeetingAfterSelectionChanges() async throws {
        let recordingMeeting = Meeting(
            title: "Recording meeting",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(1_800),
            attendees: [SampleData.me]
        )
        let otherMeeting = Meeting(
            title: "Other meeting",
            startsAt: Date().addingTimeInterval(3_600),
            endsAt: Date().addingTimeInterval(5_400),
            attendees: [SampleData.patrick]
        )
        let lateSegment = TranscriptSegment(
            meetingID: recordingMeeting.id,
            speaker: SampleData.me,
            startTime: 42,
            endTime: 51,
            text: "late routing needle",
            confidence: 0.9
        )
        let transcriptProvider = ControlledTranscriptionProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [recordingMeeting, otherMeeting], tasks: []),
            transcriptionProvider: transcriptProvider,
            meetings: [recordingMeeting, otherMeeting],
            selectedMeeting: recordingMeeting,
            tasks: []
        )

        await store.startRecording()
        await waitUntilAsync {
            await transcriptProvider.isReady
        }
        await store.selectMeeting(otherMeeting.id)
        await transcriptProvider.yield(lateSegment)
        await transcriptProvider.finish()
        await waitUntil {
            store.meetings.first { $0.id == recordingMeeting.id }?.transcriptSegments.contains(lateSegment) == true
        }

        XCTAssertTrue(store.meetings.first { $0.id == recordingMeeting.id }?.transcriptSegments.contains(lateSegment) ?? false)
        XCTAssertFalse(store.meetings.first { $0.id == otherMeeting.id }?.transcriptSegments.contains(lateSegment) ?? true)
    }

    @MainActor
    func testAppStoreLocalSearchFindsTranscriptText() async throws {
        let meeting = Meeting(
            title: "Search test",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(600),
            summary: "",
            transcriptSegments: [
                TranscriptSegment(meetingID: SampleData.meetingID, speaker: SampleData.me, startTime: 1, endTime: 2, text: "transcript-only-needle", confidence: 0.9)
            ]
        )
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: []
        )

        await store.search("transcript-only-needle")

        XCTAssertTrue(store.searchResults.contains { $0.snippet == "transcript-only-needle" })
    }

    @MainActor
    func testAppStoreLocalSearchFindsTaskText() async throws {
        let meeting = Meeting(title: "Search test", startsAt: Date(), endsAt: Date().addingTimeInterval(600))
        let task = MeetingTask(title: "task-only-needle", notes: "task note", sourceMeetingID: meeting.id)
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: [task]),
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: [task]
        )

        await store.search("task-only-needle")

        XCTAssertTrue(store.searchResults.contains { $0.title == "task-only-needle" })
    }

    @MainActor
    func testAppStoreLocalSearchFindsDecisionText() async throws {
        let meeting = Meeting(
            title: "Search test",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(600),
            decisions: [
                MeetingDecision(title: "decision-only-needle", detail: "decision detail", sourceMeetingID: SampleData.meetingID)
            ]
        )
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [meeting], tasks: []),
            meetings: [meeting],
            selectedMeeting: meeting,
            tasks: []
        )

        await store.search("decision-only-needle")

        XCTAssertTrue(store.searchResults.contains { $0.title == "decision-only-needle" })
    }

    @MainActor
    func testSearchKeepsLatestQueryWhenResponsesCompleteOutOfOrder() async {
        let searchProvider = ControlledSearchProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [], tasks: []),
            secondBrainSearchProvider: searchProvider
        )
        let oldResult = SearchResult(title: "Old", source: "Meeting", snippet: "old")
        let newResult = SearchResult(title: "New", source: "Meeting", snippet: "new")

        let oldSearch = Task { @MainActor in
            await store.search("old")
        }
        await waitUntilAsync {
            await searchProvider.hasRequest(for: "old")
        }

        let newSearch = Task { @MainActor in
            await store.search("new")
        }
        await waitUntilAsync {
            await searchProvider.hasRequest(for: "new")
        }

        await searchProvider.finish(query: "new", results: [newResult])
        await newSearch.value
        await searchProvider.finish(query: "old", results: [oldResult])
        await oldSearch.value

        XCTAssertEqual(store.searchResults, [newResult])
        XCTAssertNil(store.syncError)
    }

    @MainActor
    func testSearchIgnoresOlderFailureAfterNewerSuccess() async {
        let searchProvider = ControlledSearchProvider()
        let store = RecallOSAppStore(
            repository: FixtureRecallOSRepository(meetings: [], tasks: []),
            secondBrainSearchProvider: searchProvider
        )
        let newResult = SearchResult(title: "New", source: "Meeting", snippet: "new")

        let oldSearch = Task { @MainActor in
            await store.search("old")
        }
        await waitUntilAsync {
            await searchProvider.hasRequest(for: "old")
        }

        let newSearch = Task { @MainActor in
            await store.search("new")
        }
        await waitUntilAsync {
            await searchProvider.hasRequest(for: "new")
        }

        await searchProvider.finish(query: "new", results: [newResult])
        await newSearch.value
        await searchProvider.fail(query: "old")
        await oldSearch.value

        XCTAssertEqual(store.searchResults, [newResult])
        XCTAssertNil(store.syncError)
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
        if !condition() {
            XCTFail("Timed out waiting for condition", file: file, line: line)
        }
    }

    @MainActor
    private func waitUntilAsync(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()), Date() < deadline {
            await Task.yield()
        }
        if !(await condition()) {
            XCTFail("Timed out waiting for async condition", file: file, line: line)
        }
    }
}

private enum TestRepositoryError: Error {
    case updateFailed
}

private struct DenyingRecordingPermissionProvider: RecordingPermissionProvider {
    func requestMicrophoneAccess() async throws -> Bool {
        false
    }
}

private actor DelayedRecordingPermissionProvider: RecordingPermissionProvider {
    private var continuation: CheckedContinuation<Bool, Error>?

    var hasPendingRequest: Bool {
        continuation != nil
    }

    func requestMicrophoneAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func allow() {
        continuation?.resume(returning: true)
        continuation = nil
    }
}

private actor RecordingSpyAudioProvider: AudioCaptureProvider {
    private let failOnPause: Bool
    private let failOnResume: Bool
    private let failOnStop: Bool
    private var startCount = 0
    private var pauseCount = 0
    private var resumeCount = 0
    private var stopCount = 0

    init(failOnPause: Bool = false, failOnResume: Bool = false, failOnStop: Bool = false) {
        self.failOnPause = failOnPause
        self.failOnResume = failOnResume
        self.failOnStop = failOnStop
    }

    func start(meeting: Meeting) async throws {
        startCount += 1
    }

    func pause() async throws {
        pauseCount += 1
        if failOnPause {
            throw TestRepositoryError.updateFailed
        }
    }

    func resume() async throws {
        resumeCount += 1
        if failOnResume {
            throw TestRepositoryError.updateFailed
        }
    }

    func stop() async throws {
        stopCount += 1
        if failOnStop {
            throw TestRepositoryError.updateFailed
        }
    }

    func state() -> (startCount: Int, pauseCount: Int, resumeCount: Int, stopCount: Int) {
        (startCount, pauseCount, resumeCount, stopCount)
    }
}

private actor SuspendingStopAudioProvider: AudioCaptureProvider {
    private var stopContinuation: CheckedContinuation<Void, Error>?
    private(set) var isStopping = false

    func start(meeting: Meeting) async throws {}
    func pause() async throws {}
    func resume() async throws {}

    func stop() async throws {
        isStopping = true
        try await withCheckedThrowingContinuation { continuation in
            stopContinuation = continuation
        }
        isStopping = false
    }

    func finishStop() {
        stopContinuation?.resume()
        stopContinuation = nil
    }
}

private struct ThrowingTranscriptionProvider: TranscriptionProvider {
    func transcriptStream(for meeting: Meeting) async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        throw TestRepositoryError.updateFailed
    }
}

private actor ControlledTranscriptionProvider: TranscriptionProvider {
    private var continuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?

    var isReady: Bool {
        continuation != nil
    }

    func transcriptStream(for meeting: Meeting) async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.setContinuation(continuation)
            }
        }
    }

    func yield(_ segment: TranscriptSegment) {
        continuation?.yield(segment)
    }

    func finish() {
        continuation?.finish()
        continuation = nil
    }

    private func setContinuation(_ continuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation) async {
        self.continuation = continuation
    }
}

private actor ControlledSearchProvider: SecondBrainSearchProvider {
    private var continuations: [String: CheckedContinuation<[SearchResult], Error>] = [:]

    func search(query: String, meetings: [Meeting], tasks: [MeetingTask]) async throws -> [SearchResult] {
        try await withCheckedThrowingContinuation { continuation in
            continuations[query] = continuation
        }
    }

    func hasRequest(for query: String) -> Bool {
        continuations[query] != nil
    }

    func finish(query: String, results: [SearchResult]) {
        continuations.removeValue(forKey: query)?.resume(returning: results)
    }

    func fail(query: String) {
        continuations.removeValue(forKey: query)?.resume(throwing: TestRepositoryError.updateFailed)
    }
}

private actor FailingMoveRepository: RecallOSRepository {
    private var meetings: [Meeting]
    private var tasks: [MeetingTask]

    init(meetings: [Meeting], tasks: [MeetingTask]) {
        self.meetings = meetings
        self.tasks = tasks
    }

    func listMeetings() async throws -> [Meeting] {
        meetings
    }

    func createMeeting(_ meeting: Meeting) async throws -> Meeting {
        meeting
    }

    func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        meeting
    }

    func listTasks(forMeeting meetingID: UUID?) async throws -> [MeetingTask] {
        guard let meetingID else { return tasks }
        return tasks.filter { $0.sourceMeetingID == meetingID }
    }

    func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async throws {
        throw TestRepositoryError.updateFailed
    }

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

private actor OverlappingMoveRepository: RecallOSRepository {
    private var meetings: [Meeting]
    private var tasks: [MeetingTask]
    private var moveCount = 0
    private var firstMoveContinuation: CheckedContinuation<Void, Error>?

    init(meetings: [Meeting], tasks: [MeetingTask]) {
        self.meetings = meetings
        self.tasks = tasks
    }

    var isFirstMoveWaiting: Bool {
        firstMoveContinuation != nil
    }

    func failFirstMove() {
        firstMoveContinuation?.resume(throwing: TestRepositoryError.updateFailed)
        firstMoveContinuation = nil
    }

    func completeFirstMove() {
        firstMoveContinuation?.resume()
        firstMoveContinuation = nil
    }

    func listMeetings() async throws -> [Meeting] {
        meetings
    }

    func createMeeting(_ meeting: Meeting) async throws -> Meeting {
        meeting
    }

    func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        meeting
    }

    func listTasks(forMeeting meetingID: UUID?) async throws -> [MeetingTask] {
        guard let meetingID else { return tasks }
        return tasks.filter { $0.sourceMeetingID == meetingID }
    }

    func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async throws {
        moveCount += 1
        if moveCount == 1 {
            try await withCheckedThrowingContinuation { continuation in
                firstMoveContinuation = continuation
            }
        }
        tasks = TaskStore.moved(tasks: tasks, taskIDs: taskIDs, to: status)
    }

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

private struct FailingEnhancementProvider: NoteEnhancementProvider {
    func enhance(meeting: Meeting, transcriptSegments: [TranscriptSegment]) async throws -> EnhancedMeetingContent {
        throw TestRepositoryError.updateFailed
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
