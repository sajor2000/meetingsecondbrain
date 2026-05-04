import Foundation
import RecallOSCore

enum RecallOSStoreFactory {
    @MainActor
    static func makeAppStore() -> RecallOSAppStore {
        let liveConvexEnabled = ProcessInfo.processInfo.environment["RECALLOS_USE_LIVE_CONVEX"] == "1"
        if liveConvexEnabled {
            guard ConvexRecallOSRepository.supportsLiveUse else {
                return unavailableStore("Live Convex was requested, but the Swift Convex adapter is not implemented yet.")
            }
            guard ConvexRecallOSRepository.fromEnvironment() != nil else {
                return unavailableStore("Live Convex was requested, but CONVEX_URL is not configured.")
            }
            return unavailableStore("Live Convex was requested, but the Swift Convex adapter is not implemented yet.")
        }

        return RecallOSAppStore.fixture()
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
