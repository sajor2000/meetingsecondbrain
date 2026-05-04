import SwiftUI

public struct TaskBoardView: View {
    @Binding private var tasks: [MeetingTask]
    private let columns: [TaskStatus] = [.open, .today, .waiting, .done]
    private let onMove: (([UUID], TaskStatus) -> Void)?

    public init(tasks: Binding<[MeetingTask]>, onMove: (([UUID], TaskStatus) -> Void)? = nil) {
        _tasks = tasks
        self.onMove = onMove
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ForEach(columns, id: \.self) { status in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text(title(for: status))
                                .font(AppFont.sectionHeader)
                            Spacer()
                            Text("\(tasks.filter { $0.status == status }.count)")
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.appMutedText)
                        }

                        VStack(spacing: AppSpacing.sm) {
                            ForEach(tasks.filter { $0.status == status }) { task in
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text(task.sourceMeetingTitle ?? "Meeting")
                                        .font(AppFont.metadata)
                                        .foregroundStyle(Color.appMutedText)
                                    Text(task.title)
                                        .font(AppFont.body)
                                    if !task.notes.isEmpty {
                                        Text(task.notes)
                                            .font(AppFont.secondary)
                                            .foregroundStyle(Color.appAISuggestionText)
                                            .lineLimit(3)
                                    }
                                }
                                .padding(AppSpacing.sm)
                                .frame(width: 220, alignment: .leading)
                                .hairlinePanel()
                                .draggable(task.id.uuidString)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .top)
                        .dropDestination(for: String.self) { items, _ in
                            move(items: items, to: status)
                            return true
                        }
                    }
                    .padding(AppSpacing.sm)
                    .frame(width: 250, alignment: .topLeading)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: AppCorners.panel, style: .continuous))
                }
            }
            .padding(.vertical, AppSpacing.sm)
            .animation(AppMotion.calm, value: tasks)
        }
    }

    private func move(items: [String], to status: TaskStatus) {
        let ids = items.compactMap(UUID.init(uuidString:))
        guard !ids.isEmpty else { return }

        if let onMove {
            onMove(ids, status)
        } else {
            tasks = TaskStore.moved(tasks: tasks, taskIDs: ids, to: status)
        }
    }

    private func title(for status: TaskStatus) -> String {
        switch status {
        case .open: "Inbox"
        case .today: "Today"
        case .waiting: "Waiting"
        case .done: "Done"
        }
    }
}
