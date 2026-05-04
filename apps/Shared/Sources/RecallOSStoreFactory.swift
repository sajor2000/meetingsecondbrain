import Foundation
import RecallOSCore

enum RecallOSStoreFactory {
    @MainActor
    static func makeAppStore(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        supportsLiveUse: Bool = ConvexRecallOSRepository.supportsLiveUse,
        usePersistentStore: Bool = true,
        persistentRepositoryFactory: () throws -> any RecallOSRepository = {
            try SwiftDataRecallOSRepository.persistent()
        }
    ) -> RecallOSAppStore {
        let liveConvexEnabled = environment["RECALLOS_USE_LIVE_CONVEX"] == "1"
        if liveConvexEnabled {
            guard supportsLiveUse else {
                return unavailableStore("Live Convex was requested, but the Swift Convex adapter is not implemented yet.")
            }
            guard let repository = ConvexRecallOSRepository.fromEnvironment(environment) else {
                return unavailableStore("Live Convex was requested, but CONVEX_URL is not configured.")
            }
            return RecallOSAppStore(
                repository: repository,
                permissionProvider: permissionProvider(),
                audioProvider: audioProvider(),
                calendarProvider: calendarProvider()
            )
        }

        guard usePersistentStore else {
            return RecallOSAppStore.fixture()
        }

        do {
            return RecallOSAppStore(
                repository: try persistentRepositoryFactory(),
                permissionProvider: permissionProvider(),
                audioProvider: audioProvider(),
                calendarProvider: calendarProvider()
            )
        } catch {
            // Convex is kept as a future sync boundary and remains ignored until
            // live reads/writes exist. If local persistence cannot open, keep the
            // app usable with fixtures and surface the local-store failure.
            return RecallOSAppStore.fixture(
                syncError: error.localizedDescription,
                workflowMessage: "Using fixture data because the local store could not open."
            )
        }
    }

    private static func calendarProvider() -> any CalendarEventProvider {
        #if os(macOS)
        EventKitCalendarEventProvider()
        #else
        MockCalendarEventProvider()
        #endif
    }

    private static func permissionProvider() -> any RecordingPermissionProvider {
        #if os(macOS)
        AVFoundationRecordingPermissionProvider()
        #else
        AllowAllRecordingPermissionProvider()
        #endif
    }

    private static func audioProvider() -> any AudioCaptureProvider {
        #if os(macOS)
        AVFoundationMicrophoneAudioCaptureProvider()
        #else
        MockAudioCaptureProvider()
        #endif
    }

    @MainActor
    private static func unavailableStore(_ message: String) -> RecallOSAppStore {
        RecallOSAppStore(repository: UnavailableRecallOSRepository(message: message))
    }
}

private struct RecallOSStoreConfigurationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private actor UnavailableRecallOSRepository: RecallOSRepository {
    private let error: RecallOSStoreConfigurationError

    init(message: String) {
        self.error = RecallOSStoreConfigurationError(message: message)
    }

    func listMeetings() async throws -> [Meeting] {
        throw error
    }

    func createMeeting(_ meeting: Meeting) async throws -> Meeting {
        throw error
    }

    func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        throw error
    }

    func listTasks(forMeeting meetingID: UUID?) async throws -> [MeetingTask] {
        throw error
    }

    func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async throws {
        throw error
    }

    func listTranscriptSegments(forMeeting meetingID: UUID) async throws -> [TranscriptSegment] {
        throw error
    }

    func listScreenshots(forMeeting meetingID: UUID) async throws -> [MeetingScreenshot] {
        throw error
    }

    func listPeople() async throws -> [Person] {
        throw error
    }

    func listTopics() async throws -> [Topic] {
        throw error
    }

    func listDecisions(forMeeting meetingID: UUID?) async throws -> [MeetingDecision] {
        throw error
    }

    func listSettings() async throws -> [RecallOSSetting] {
        throw error
    }

    func searchSecondBrain(query: String) async throws -> [SearchResult] {
        throw error
    }
}
