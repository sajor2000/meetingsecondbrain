import RecallOSCore
import SwiftUI

struct MacTasksContentView: View {
    @Binding var tasks: [MeetingTask]
    let onMoveTasks: ([UUID], TaskStatus) -> Void
    @State private var filter: TaskListFilter = .today

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Tasks")
                .font(AppFont.pageTitle)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xl)
            Picker("Filter", selection: $filter) {
                ForEach(TaskListFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ForEach(filter.sections(for: tasks)) { section in
                        TaskGroup(title: section.title, tasks: section.tasks)
                    }
                }
                .padding(AppSpacing.xl)
            }
        }
    }
}

struct SecondBrainContentView: View {
    let searchResults: [SearchResult]
    let onSearch: (String) -> Void
    let onOpenMeeting: (UUID) -> Void
    @State private var query = "What did Patrick say about JSL POC?"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Second brain")
                    .font(AppFont.pageTitle)
                TextField("Ask your second brain...", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit {
                        onSearch(query)
                    }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: AppSpacing.sm) {
                    ForEach(["What did Patrick say about JSL POC?", "All decisions about CLIF", "Tasks I owe Kevin"], id: \.self) { chip in
                        Button {
                            query = chip
                            onSearch(chip)
                        } label: {
                            Text(chip)
                                .font(AppFont.metadata)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .overlay(Capsule().stroke(Color.appHairline))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if searchResults.isEmpty {
                    Text("Nothing matches that yet. Try broader terms.")
                        .font(AppFont.secondary)
                        .foregroundStyle(Color.appMutedText)
                        .padding(AppSpacing.md)
                        .hairlinePanel()
                } else {
                    ForEach(searchResults) { result in
                        SearchResultCard(result: result, onOpenMeeting: onOpenMeeting)
                    }
                }
            }
            .padding(AppSpacing.xl)
        }
    }
}

struct PlaceholderContentView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppFont.pageTitle)
            Text(message)
                .font(AppFont.secondary)
                .foregroundStyle(Color.appMutedText)
                .padding(AppSpacing.md)
                .hairlinePanel()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.xl)
    }
}

struct GroupedTaskList: View {
    let tasks: [MeetingTask]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ForEach(TaskListFilter.today.sections(for: tasks)) { section in
                TaskGroup(title: section.title, tasks: section.tasks)
            }
        }
    }
}

struct TaskGroup: View {
    let title: String
    let tasks: [MeetingTask]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(AppFont.tinyLabel)
                .foregroundStyle(Color.appMutedText)
            ForEach(tasks) { task in
                TaskRowView(task: task)
                Divider()
            }
        }
    }
}
