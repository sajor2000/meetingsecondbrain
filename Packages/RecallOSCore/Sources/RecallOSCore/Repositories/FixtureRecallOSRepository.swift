import Foundation

public actor FixtureRecallOSRepository: RecallOSRepository {
    private var meetings: [Meeting]
    private var tasks: [MeetingTask]
    private var searchResults: [SearchResult]

    public init(
        meetings: [Meeting] = [SampleData.meeting],
        tasks: [MeetingTask] = SampleData.tasks,
        searchResults: [SearchResult] = SampleData.searchResults
    ) {
        self.meetings = meetings
        self.tasks = tasks
        self.searchResults = searchResults
    }

    public func listMeetings() async throws -> [Meeting] {
        meetings.map { meeting in
            var updated = meeting
            updated.tasks = tasks.filter { $0.sourceMeetingID == meeting.id }
            return updated
        }
    }

    public func createMeeting(_ meeting: Meeting) async throws -> Meeting {
        meetings.insert(meeting, at: 0)
        return meeting
    }

    public func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
        } else {
            meetings.insert(meeting, at: 0)
        }

        let meetingTaskIDs = Set(meeting.tasks.map(\.id))
        tasks.removeAll { existing in
            existing.sourceMeetingID == meeting.id && !meetingTaskIDs.contains(existing.id)
        }

        for task in meeting.tasks {
            if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[taskIndex] = task
            } else {
                tasks.append(task)
            }
        }

        return meeting
    }

    public func listTasks(forMeeting meetingID: UUID?) async throws -> [MeetingTask] {
        guard let meetingID else { return tasks }
        return tasks.filter { $0.sourceMeetingID == meetingID }
    }

    public func moveTasks(_ taskIDs: [UUID], to status: TaskStatus) async throws {
        tasks = TaskStore.moved(tasks: tasks, taskIDs: taskIDs, to: status)
    }

    public func listTranscriptSegments(forMeeting meetingID: UUID) async throws -> [TranscriptSegment] {
        SampleData.transcriptSegments.filter { $0.meetingID == meetingID }
    }

    public func listScreenshots(forMeeting meetingID: UUID) async throws -> [MeetingScreenshot] {
        meetings.first(where: { $0.id == meetingID })?.screenshots ?? []
    }

    public func listPeople() async throws -> [Person] {
        Array(Set(meetings.flatMap(\.attendees))).sorted { $0.displayName < $1.displayName }
    }

    public func listTopics() async throws -> [Topic] {
        meetings.flatMap(\.topics)
    }

    public func listDecisions(forMeeting meetingID: UUID?) async throws -> [MeetingDecision] {
        let decisions = meetings.flatMap(\.decisions)
        guard let meetingID else { return decisions }
        return decisions.filter { $0.sourceMeetingID == meetingID }
    }

    public func listSettings() async throws -> [RecallOSSetting] {
        [
            RecallOSSetting(key: "transcription.provider", value: "hybrid-cloud"),
            RecallOSSetting(key: "tasks.defaultView", value: "list")
        ]
    }

    public func searchSecondBrain(query: String) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return searchResults }

        return searchResults.filter { result in
            result.title.localizedCaseInsensitiveContains(trimmed)
                || result.source.localizedCaseInsensitiveContains(trimmed)
                || result.snippet.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
