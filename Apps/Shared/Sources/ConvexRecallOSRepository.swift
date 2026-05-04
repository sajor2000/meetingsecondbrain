import Foundation
import RecallOSCore

#if os(iOS) && canImport(ConvexMobile)
import ConvexMobile
#endif

enum ConvexRecallOSRepositoryError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Convex repository is configured as a boundary, but live subscriptions are not implemented yet."
        }
    }
}

actor ConvexRecallOSRepository: RecallOSRepository {
    private let deploymentURL: String

    init(deploymentURL: String) {
        self.deploymentURL = deploymentURL
    }

    static func fromEnvironment() -> ConvexRecallOSRepository? {
        guard let url = ProcessInfo.processInfo.environment["CONVEX_URL"], !url.isEmpty else {
            return nil
        }
        return ConvexRecallOSRepository(deploymentURL: url)
    }

    func listMeetings() async throws -> [Meeting] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func createMeeting(_ meeting: Meeting) async throws -> Meeting {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func listTasks(forMeeting meetingID: UUID?) async throws -> [MeetingTask] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async throws {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func listTranscriptSegments(forMeeting meetingID: UUID) async throws -> [TranscriptSegment] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func listScreenshots(forMeeting meetingID: UUID) async throws -> [MeetingScreenshot] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func listPeople() async throws -> [Person] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func listTopics() async throws -> [Topic] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func listDecisions(forMeeting meetingID: UUID?) async throws -> [MeetingDecision] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func listSettings() async throws -> [RecallOSSetting] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }

    func searchSecondBrain(query: String) async throws -> [SearchResult] {
        throw ConvexRecallOSRepositoryError.notConfigured
    }
}
