import Combine
import Foundation

public final class TaskStore: ObservableObject {
    @Published public var tasks: [MeetingTask]

    public init(tasks: [MeetingTask]) {
        self.tasks = tasks
    }

    public convenience init(meeting: Meeting) {
        self.init(tasks: meeting.tasks)
    }

    public func move(taskIDs: [UUID], to status: TaskStatus, completedAt: Date = Date()) {
        tasks = Self.moved(tasks: tasks, taskIDs: taskIDs, to: status, completedAt: completedAt)
    }

    public static func moved(
        tasks: [MeetingTask],
        taskIDs: [UUID],
        to status: TaskStatus,
        completedAt: Date = Date()
    ) -> [MeetingTask] {
        tasks.map { task in
            guard taskIDs.contains(task.id) else { return task }

            var updated = task
            updated.status = status
            updated.completedAt = status == .done ? completedAt : nil
            return updated
        }
    }
}
