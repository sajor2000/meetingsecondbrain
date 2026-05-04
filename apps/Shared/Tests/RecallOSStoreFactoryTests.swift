import XCTest
import RecallOSCore

@MainActor
final class RecallOSStoreFactoryTests: XCTestCase {
    func testFactoryCanUseFixtureStoreWithoutLiveConvex() async {
        let store = RecallOSStoreFactory.makeAppStore(environment: [:], usePersistentStore: false)

        await store.load()

        XCTAssertEqual(store.selectedMeeting?.title, SampleData.meeting.title)
        XCTAssertNil(store.syncError)
    }

    func testPersistentStoreFailureFallsBackToFixtureStoreWithVisibleError() async {
        let store = RecallOSStoreFactory.makeAppStore(
            environment: [:],
            persistentRepositoryFactory: {
                throw FactoryTestError(message: "Store unavailable")
            }
        )

        await store.load()

        XCTAssertEqual(store.selectedMeeting?.title, SampleData.meeting.title)
        XCTAssertEqual(store.syncError, "Store unavailable")
        XCTAssertEqual(store.workflowMessage, "Using fixture data because the local store could not open.")
    }

    func testLiveConvexOptInSurfacesUnsupportedAdapterError() async {
        let store = RecallOSStoreFactory.makeAppStore(
            environment: [
                "RECALLOS_USE_LIVE_CONVEX": "1",
                "CONVEX_URL": "https://example.convex.cloud",
            ],
            supportsLiveUse: false
        )

        await store.load()

        XCTAssertNil(store.selectedMeeting)
        XCTAssertEqual(store.syncError, "Live Convex was requested, but the Swift Convex adapter is not implemented yet.")
    }

    func testLiveConvexOptInRequiresDeploymentURLWhenAdapterIsSupported() async {
        let store = RecallOSStoreFactory.makeAppStore(
            environment: ["RECALLOS_USE_LIVE_CONVEX": "1"],
            supportsLiveUse: true
        )

        await store.load()

        XCTAssertNil(store.selectedMeeting)
        XCTAssertEqual(store.syncError, "Live Convex was requested, but CONVEX_URL is not configured.")
    }

    func testLiveConvexOptInUsesConfiguredConvexBoundaryWhenAdapterIsSupported() async {
        let store = RecallOSStoreFactory.makeAppStore(
            environment: [
                "RECALLOS_USE_LIVE_CONVEX": "1",
                "CONVEX_URL": "https://example.convex.cloud",
            ],
            supportsLiveUse: true
        )

        await store.load()

        XCTAssertNil(store.selectedMeeting)
        XCTAssertEqual(store.syncError, "Convex repository is configured as a boundary, but live subscriptions are not implemented yet.")
    }

    func testConvexRepositoryReadsDeploymentURLFromInjectedEnvironment() {
        let repository = ConvexRecallOSRepository.fromEnvironment(["CONVEX_URL": "https://example.convex.cloud"])

        XCTAssertEqual(repository?.deploymentURL, "https://example.convex.cloud")
        XCTAssertNil(ConvexRecallOSRepository.fromEnvironment([:]))
    }

    func testConvexMeetingDTOMapsDocumentIdentityToDomainModel() throws {
        let startsAt = Date(timeIntervalSince1970: 1_778_270_400)
        let endsAt = startsAt.addingTimeInterval(1_800)
        let localID = UUID()
        let calendarEventID = UUID()
        let topicID = UUID()
        let attendee = try ConvexPersonDocument(
            convexID: "people:alice",
            localId: UUID().uuidString,
            displayName: "Alice Chen",
            email: "alice@example.com",
            role: "PM"
        ).domainModel()
        let topic = try ConvexTopicDocument(
            convexID: "topics:pilot",
            localId: topicID.uuidString,
            name: "Pilot readiness",
            meetingLocalIds: [localID.uuidString]
        ).domainModel()

        let meeting = try ConvexMeetingDocument(
            convexID: "meetings:abc",
            localId: localID.uuidString,
            title: "Pilot planning",
            startsAt: RecallOSConvexMapper.milliseconds(from: startsAt),
            endsAt: RecallOSConvexMapper.milliseconds(from: endsAt),
            status: "recording",
            folderId: "folders:pilot",
            calendarEventId: "event-123",
            calendarEventLocalId: calendarEventID.uuidString,
            summary: "Discussed pilot readiness.",
            rawNotes: "Raw notes",
            enhancedNotes: "Enhanced notes"
        ).domainModel(attendees: [attendee], topics: [topic])

        XCTAssertEqual(meeting.id, localID)
        XCTAssertEqual(meeting.convexID, "meetings:abc")
        XCTAssertEqual(meeting.startsAt, startsAt)
        XCTAssertEqual(meeting.endsAt, endsAt)
        XCTAssertEqual(meeting.status, .recording)
        XCTAssertEqual(meeting.folder, "folders:pilot")
        XCTAssertEqual(meeting.calendarEventID, calendarEventID)
        XCTAssertEqual(meeting.attendees, [attendee])
        XCTAssertEqual(meeting.topics, [topic])
        XCTAssertEqual(meeting.topics.first?.meetingIDs, [localID])
        XCTAssertEqual(meeting.userNotes.map(\.body), ["Raw notes", "Enhanced notes"])
    }

    func testConvexTaskDTOMapsLocalRelationshipsAndDates() throws {
        let taskID = UUID()
        let meetingID = UUID()
        let dueAt = Date(timeIntervalSince1970: 1_778_310_000)
        let completedAt = Date(timeIntervalSince1970: 1_778_313_000)
        let ownerDocument = ConvexPersonDocument(
            convexID: "people:owner",
            localId: UUID().uuidString,
            displayName: "Owner",
            email: nil,
            role: nil
        )

        let task = try ConvexTaskDocument(
            convexID: "tasks:abc",
            localId: taskID.uuidString,
            title: "Send recap",
            notes: nil,
            status: "done",
            priority: "high",
            owner: ownerDocument,
            dueAt: RecallOSConvexMapper.milliseconds(from: dueAt),
            completedAt: RecallOSConvexMapper.milliseconds(from: completedAt),
            sourceMeetingLocalId: meetingID.uuidString,
            sourceTimestamp: 321,
            extractionConfidence: 0.87
        ).domainModel()

        XCTAssertEqual(task.id, taskID)
        XCTAssertEqual(task.convexID, "tasks:abc")
        XCTAssertEqual(task.notes, "")
        XCTAssertEqual(task.status, .done)
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.dueAt, dueAt)
        XCTAssertEqual(task.completedAt, completedAt)
        XCTAssertEqual(task.sourceMeetingID, meetingID)
        XCTAssertEqual(task.sourceTimestamp, 321)
        XCTAssertEqual(task.owner?.convexID, "people:owner")
    }

    func testConvexDTORejectsInvalidLocalIDInsteadOfGeneratingUnstableUUID() {
        let document = ConvexMeetingDocument(
            convexID: "meetings:bad",
            localId: "not-a-uuid",
            title: "Bad document",
            startsAt: 0,
            endsAt: 1,
            status: "scheduled",
            folderId: nil,
            calendarEventId: nil,
            calendarEventLocalId: nil,
            summary: nil,
            rawNotes: nil,
            enhancedNotes: nil
        )

        XCTAssertThrowsError(try document.domainModel()) { error in
            XCTAssertEqual(error as? RecallOSConvexMappingError, .invalidLocalID("not-a-uuid", field: "localId"))
        }
    }

    func testConvexDTORejectsInvalidMeetingStatus() {
        let document = ConvexMeetingDocument(
            convexID: "meetings:bad-status",
            localId: UUID().uuidString,
            title: "Bad status",
            startsAt: 0,
            endsAt: 1,
            status: "started",
            folderId: nil,
            calendarEventId: nil,
            calendarEventLocalId: nil,
            summary: nil,
            rawNotes: nil,
            enhancedNotes: nil
        )

        XCTAssertThrowsError(try document.domainModel()) { error in
            XCTAssertEqual(error as? RecallOSConvexMappingError, .invalidStatus("started"))
        }
    }

    func testConvexDTORejectsInvalidTaskStatusAndPriority() {
        let badStatus = ConvexTaskDocument(
            convexID: "tasks:bad-status",
            localId: UUID().uuidString,
            title: "Bad task",
            notes: nil,
            status: "todo",
            priority: "medium",
            owner: nil,
            dueAt: nil,
            completedAt: nil,
            sourceMeetingLocalId: nil,
            sourceTimestamp: nil,
            extractionConfidence: nil
        )
        let badPriority = ConvexTaskDocument(
            convexID: "tasks:bad-priority",
            localId: UUID().uuidString,
            title: "Bad task",
            notes: nil,
            status: "open",
            priority: "urgent",
            owner: nil,
            dueAt: nil,
            completedAt: nil,
            sourceMeetingLocalId: nil,
            sourceTimestamp: nil,
            extractionConfidence: nil
        )

        XCTAssertThrowsError(try badStatus.domainModel()) { error in
            XCTAssertEqual(error as? RecallOSConvexMappingError, .invalidStatus("todo"))
        }
        XCTAssertThrowsError(try badPriority.domainModel()) { error in
            XCTAssertEqual(error as? RecallOSConvexMappingError, .invalidPriority("urgent"))
        }
    }

    func testConvexDTORejectsInvalidRelationshipLocalIDs() {
        let meeting = ConvexMeetingDocument(
            convexID: "meetings:bad-calendar",
            localId: UUID().uuidString,
            title: "Bad calendar",
            startsAt: 0,
            endsAt: 1,
            status: "scheduled",
            folderId: nil,
            calendarEventId: "external-calendar-id",
            calendarEventLocalId: "not-a-calendar-event-uuid",
            summary: nil,
            rawNotes: nil,
            enhancedNotes: nil
        )
        let topic = ConvexTopicDocument(
            convexID: "topics:bad-meeting",
            localId: UUID().uuidString,
            name: "Bad topic",
            meetingLocalIds: ["not-a-meeting-uuid"]
        )
        let segment = ConvexTranscriptSegmentDocument(
            convexID: "segments:bad-meeting",
            localId: UUID().uuidString,
            meetingLocalId: "not-a-meeting-uuid",
            speaker: nil,
            startTime: 0,
            endTime: 1,
            text: "Bad segment",
            confidence: 1
        )
        let task = ConvexTaskDocument(
            convexID: "tasks:bad-source",
            localId: UUID().uuidString,
            title: "Bad source",
            notes: nil,
            status: "open",
            priority: "medium",
            owner: nil,
            dueAt: nil,
            completedAt: nil,
            sourceMeetingLocalId: "not-a-source-meeting-uuid",
            sourceTimestamp: nil,
            extractionConfidence: nil
        )

        XCTAssertThrowsError(try meeting.domainModel()) { error in
            XCTAssertEqual(error as? RecallOSConvexMappingError, .invalidLocalID("not-a-calendar-event-uuid", field: "calendarEventLocalId"))
        }
        XCTAssertThrowsError(try topic.domainModel()) { error in
            XCTAssertEqual(error as? RecallOSConvexMappingError, .invalidLocalID("not-a-meeting-uuid", field: "meetingLocalIds"))
        }
        XCTAssertThrowsError(try segment.domainModel()) { error in
            XCTAssertEqual(error as? RecallOSConvexMappingError, .invalidLocalID("not-a-meeting-uuid", field: "meetingLocalId"))
        }
        XCTAssertThrowsError(try task.domainModel()) { error in
            XCTAssertEqual(error as? RecallOSConvexMappingError, .invalidLocalID("not-a-source-meeting-uuid", field: "sourceMeetingLocalId"))
        }
    }

    func testConvexTranscriptScreenshotDecisionAndSettingDTOsPreserveConvexIDs() throws {
        let meetingID = UUID()
        let speakerDocument = ConvexPersonDocument(
            convexID: "people:speaker",
            localId: UUID().uuidString,
            displayName: "Speaker",
            email: nil,
            role: nil
        )

        let segment = try ConvexTranscriptSegmentDocument(
            convexID: "segments:abc",
            localId: UUID().uuidString,
            meetingLocalId: meetingID.uuidString,
            speaker: speakerDocument,
            startTime: 12,
            endTime: 18,
            text: "Transcript text",
            confidence: 0.92
        ).domainModel()
        let screenshot = try ConvexScreenshotDocument(
            convexID: "screenshots:abc",
            localId: UUID().uuidString,
            meetingLocalId: meetingID.uuidString,
            capturedAt: 42,
            storageId: "storage:screenshot",
            caption: nil
        ).domainModel()
        let decision = try ConvexDecisionDocument(
            convexID: "decisions:abc",
            localId: UUID().uuidString,
            meetingLocalId: meetingID.uuidString,
            title: "Decision",
            detail: "Ship the pilot.",
            sourceTimestamp: 64
        ).domainModel()
        let settingUpdatedAt = Date(timeIntervalSince1970: 1_778_270_500)
        let setting = try ConvexSettingDocument(
            convexID: "settings:abc",
            localId: UUID().uuidString,
            key: "tasks.defaultView",
            value: "list",
            updatedAt: RecallOSConvexMapper.milliseconds(from: settingUpdatedAt)
        ).domainModel()

        XCTAssertEqual(segment.convexID, "segments:abc")
        XCTAssertEqual(segment.meetingID, meetingID)
        XCTAssertEqual(segment.speaker.convexID, "people:speaker")
        XCTAssertEqual(screenshot.convexID, "screenshots:abc")
        XCTAssertEqual(screenshot.caption, "")
        XCTAssertEqual(decision.convexID, "decisions:abc")
        XCTAssertEqual(decision.sourceMeetingID, meetingID)
        XCTAssertEqual(setting.convexID, "settings:abc")
        XCTAssertEqual(setting.updatedAt, settingUpdatedAt)
    }
}

private struct FactoryTestError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
