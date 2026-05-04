import Foundation

public enum TaskListFilter: String, CaseIterable, Identifiable, Sendable {
    case today
    case thisWeek
    case allOpen
    case done

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: "Today"
        case .thisWeek: "Week"
        case .allOpen: "All"
        case .done: "Done"
        }
    }

    public func sections(for tasks: [MeetingTask], now: Date = Date()) -> [TaskListSection] {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 24 * 60 * 60)

        switch self {
        case .today:
            return Self.nonEmpty([
                TaskListSection(title: "Overdue", tasks: tasks.filter { $0.isOverdue(relativeTo: now) }),
                TaskListSection(title: "Today", tasks: tasks.filter { $0.status == .today && !$0.isOverdue(relativeTo: now) }),
                TaskListSection(title: "Done today", tasks: tasks.filter { task in
                    guard task.status == .done, let completedAt = task.completedAt else { return false }
                    return calendar.isDate(completedAt, inSameDayAs: now)
                })
            ])
        case .thisWeek:
            return Self.nonEmpty([
                TaskListSection(title: "Due this week", tasks: tasks.filter { task in
                    guard task.status != .done, let dueAt = task.dueAt else { return false }
                    return dueAt <= weekEnd
                }),
                TaskListSection(title: "Waiting", tasks: tasks.filter { $0.status == .waiting })
            ])
        case .allOpen:
            return Self.nonEmpty([
                TaskListSection(title: "Open", tasks: tasks.filter { $0.status == .open }),
                TaskListSection(title: "Today", tasks: tasks.filter { $0.status == .today }),
                TaskListSection(title: "Waiting", tasks: tasks.filter { $0.status == .waiting })
            ])
        case .done:
            return Self.nonEmpty([
                TaskListSection(title: "Done", tasks: tasks.filter { $0.status == .done })
            ])
        }
    }

    private static func nonEmpty(_ sections: [TaskListSection]) -> [TaskListSection] {
        sections.filter { !$0.tasks.isEmpty }
    }
}

public struct TaskListSection: Identifiable, Equatable, Sendable {
    public var id: String { title }
    public let title: String
    public let tasks: [MeetingTask]

    public init(title: String, tasks: [MeetingTask]) {
        self.title = title
        self.tasks = tasks
    }
}

private extension MeetingTask {
    func isOverdue(relativeTo now: Date) -> Bool {
        guard status != .done, let dueAt else { return false }
        return dueAt < now
    }
}
