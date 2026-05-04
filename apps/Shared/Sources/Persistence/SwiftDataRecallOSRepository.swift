import Foundation
import RecallOSCore
import SwiftData

enum SwiftDataRecallOSRepositoryError: LocalizedError {
    case containerUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .containerUnavailable(message):
            "Local RecallOS store could not be opened: \(message)"
        }
    }
}

@MainActor
final class SwiftDataRecallOSRepository: RecallOSRepository, @unchecked Sendable {
    private let container: ModelContainer
    private let context: ModelContext
    private let searchProvider = LocalSecondBrainSearchProvider()

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        self.context.autosaveEnabled = false
    }

    static func persistent() throws -> SwiftDataRecallOSRepository {
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration("RecallOSLocalStore", schema: schema, isStoredInMemoryOnly: false)
            return try SwiftDataRecallOSRepository(container: ModelContainer(for: schema, configurations: [configuration]))
        } catch {
            throw SwiftDataRecallOSRepositoryError.containerUnavailable(error.localizedDescription)
        }
    }

    static func inMemory() throws -> SwiftDataRecallOSRepository {
        let schema = persistenceSchema
        let configuration = ModelConfiguration("RecallOSInMemoryStore", schema: schema, isStoredInMemoryOnly: true)
        return try SwiftDataRecallOSRepository(container: ModelContainer(for: schema, configurations: [configuration]))
    }

    static func temporaryStore(url: URL) throws -> SwiftDataRecallOSRepository {
        let schema = persistenceSchema
        let configuration = ModelConfiguration("RecallOSTemporaryStore", schema: schema, url: url)
        return try SwiftDataRecallOSRepository(container: ModelContainer(for: schema, configurations: [configuration]))
    }

    func listMeetings() async throws -> [Meeting] {
        try seedIfNeeded()
        return try fetchMeetings().map(RecallOSPersistenceMapper.meeting(from:))
    }

    func createMeeting(_ meeting: Meeting) async throws -> Meeting {
        try replaceMeeting(meeting)
        return meeting
    }

    func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        try replaceMeeting(meeting)
        return meeting
    }

    func listTasks(forMeeting meetingID: UUID?) async throws -> [MeetingTask] {
        try seedIfNeeded()
        let meetings = try fetchMeetings().map(RecallOSPersistenceMapper.meeting(from:))
        let tasks = meetings.flatMap(\.tasks)
        guard let meetingID else { return tasks }
        return tasks.filter { $0.sourceMeetingID == meetingID }
    }

    func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async throws {
        let ids = Set(taskIDs)
        let now = Date()
        let meetings = try fetchMeetings()

        for meeting in meetings {
            for task in meeting.tasks where ids.contains(task.id) {
                task.status = status.rawValue
                task.completedAt = status == .done ? task.completedAt ?? now : nil
            }
        }

        try save()
    }

    func listTranscriptSegments(forMeeting meetingID: UUID) async throws -> [TranscriptSegment] {
        try seedIfNeeded()
        return try fetchMeetings()
            .first { $0.id == meetingID }?
            .transcriptSegments
            .map(RecallOSPersistenceMapper.transcriptSegment(fromPersistent:))
            .sorted { $0.startTime < $1.startTime } ?? []
    }

    func listScreenshots(forMeeting meetingID: UUID) async throws -> [MeetingScreenshot] {
        try seedIfNeeded()
        return try fetchMeetings()
            .first { $0.id == meetingID }?
            .screenshots
            .map(RecallOSPersistenceMapper.screenshot(fromPersistent:)) ?? []
    }

    func listPeople() async throws -> [Person] {
        try seedIfNeeded()
        var peopleByID: [UUID: Person] = [:]

        for meeting in try fetchMeetings().map(RecallOSPersistenceMapper.meeting(from:)) {
            for person in meeting.attendees {
                peopleByID[person.id] = person
            }
            for segment in meeting.transcriptSegments {
                peopleByID[segment.speaker.id] = segment.speaker
            }
            for task in meeting.tasks {
                if let owner = task.owner {
                    peopleByID[owner.id] = owner
                }
            }
        }

        return peopleByID.values.sorted { $0.displayName < $1.displayName }
    }

    func listTopics() async throws -> [Topic] {
        try seedIfNeeded()
        return try fetchMeetings()
            .map(RecallOSPersistenceMapper.meeting(from:))
            .flatMap(\.topics)
    }

    func listDecisions(forMeeting meetingID: UUID?) async throws -> [MeetingDecision] {
        try seedIfNeeded()
        let decisions = try fetchMeetings()
            .map(RecallOSPersistenceMapper.meeting(from:))
            .flatMap(\.decisions)
        guard let meetingID else { return decisions }
        return decisions.filter { $0.sourceMeetingID == meetingID }
    }

    func listSettings() async throws -> [RecallOSSetting] {
        try seedSettingsIfNeeded()
        return try context.fetch(FetchDescriptor<PersistentRecallOSSetting>())
            .map(RecallOSPersistenceMapper.setting(from:))
            .sorted { $0.key < $1.key }
    }

    func searchSecondBrain(query: String) async throws -> [SearchResult] {
        let meetings = try await listMeetings()
        let tasks = try await listTasks(forMeeting: nil)
        return try await searchProvider.search(query: query, meetings: meetings, tasks: tasks)
    }

    private func replaceMeeting(_ meeting: Meeting) throws {
        if let existing = try fetchMeetings().first(where: { $0.id == meeting.id }) {
            context.delete(existing)
        }

        context.insert(RecallOSPersistenceMapper.persistentMeeting(from: meeting))
        try save()
    }

    private func seedIfNeeded() throws {
        if try fetchMeetings().isEmpty {
            context.insert(RecallOSPersistenceMapper.persistentMeeting(from: SampleData.meeting))
            try seedSettingsIfNeeded(saveImmediately: false)
            try save()
        }
    }

    private func seedSettingsIfNeeded(saveImmediately: Bool = true) throws {
        let existing = try context.fetch(FetchDescriptor<PersistentRecallOSSetting>())
        guard existing.isEmpty else { return }

        for setting in Self.defaultSettings {
            context.insert(RecallOSPersistenceMapper.persistentSetting(from: setting))
        }

        if saveImmediately {
            try save()
        }
    }

    private func fetchMeetings() throws -> [PersistentMeeting] {
        let descriptor = FetchDescriptor<PersistentMeeting>(
            sortBy: [SortDescriptor(\.startsAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    private static var persistenceSchema: Schema {
        Schema([
            PersistentMeeting.self,
            PersistentPersonRecord.self,
            PersistentNoteBlock.self,
            PersistentAIAddition.self,
            PersistentTranscriptSegment.self,
            PersistentMeetingTask.self,
            PersistentMeetingScreenshot.self,
            PersistentMeetingDecision.self,
            PersistentTopic.self,
            PersistentAudioCaptureArtifact.self,
            PersistentCalendarEvent.self,
            PersistentRecallOSSetting.self
        ])
    }

    private static var defaultSettings: [RecallOSSetting] {
        [
            RecallOSSetting(key: "transcription.provider", value: "mock-local"),
            RecallOSSetting(key: "tasks.defaultView", value: "list"),
            RecallOSSetting(key: "sync.provider", value: "local-first")
        ]
    }
}
