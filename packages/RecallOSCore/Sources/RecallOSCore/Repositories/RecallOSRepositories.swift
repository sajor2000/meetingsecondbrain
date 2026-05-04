import Foundation

public protocol MeetingRepository: Sendable {
    func listMeetings() async throws -> [Meeting]
    func createMeeting(_ meeting: Meeting) async throws -> Meeting
    func updateMeeting(_ meeting: Meeting) async throws -> Meeting
}

public protocol TaskRepository: Sendable {
    func listTasks(forMeeting meetingID: UUID?) async throws -> [MeetingTask]
    func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async throws
}

public protocol TranscriptSegmentRepository: Sendable {
    func listTranscriptSegments(forMeeting meetingID: UUID) async throws -> [TranscriptSegment]
}

public protocol ScreenshotRepository: Sendable {
    func listScreenshots(forMeeting meetingID: UUID) async throws -> [MeetingScreenshot]
}

public protocol PeopleGraphRepository: Sendable {
    func listPeople() async throws -> [Person]
    func listTopics() async throws -> [Topic]
    func listDecisions(forMeeting meetingID: UUID?) async throws -> [MeetingDecision]
}

public protocol SettingsRepository: Sendable {
    func listSettings() async throws -> [RecallOSSetting]
}

public protocol SearchRepository: Sendable {
    func searchSecondBrain(query: String) async throws -> [SearchResult]
}

public typealias RecallOSRepository =
    MeetingRepository
    & TaskRepository
    & TranscriptSegmentRepository
    & ScreenshotRepository
    & PeopleGraphRepository
    & SettingsRepository
    & SearchRepository
