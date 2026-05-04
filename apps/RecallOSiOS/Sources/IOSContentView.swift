import RecallOSCore
import SwiftUI

struct IOSContentView: View {
    @StateObject private var store: RecallOSAppStore
    @State private var showingQuickMemo = false

    init(store: RecallOSAppStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        Group {
            if let meeting = store.selectedMeeting {
                TabView {
                    TodayView(meeting: meeting, tasks: store.tasks, showingQuickMemo: $showingQuickMemo)
                        .tabItem { Label("Today", systemImage: "house") }
                    MeetingsView(meetings: store.meetings, tasks: store.tasks)
                        .tabItem { Label("Meetings", systemImage: "square") }
                    TasksView(tasks: store.tasks)
                        .tabItem { Label("Tasks", systemImage: "checkmark") }
                    BrainView(results: store.searchResults) { query in
                        Task {
                            await store.search(query)
                        }
                    }
                        .tabItem { Label("Brain", systemImage: "scope") }
                }
            } else {
                ProgressView("Loading meetings")
            }
        }
        .tint(Color.appAccent)
        .task {
            await store.load()
        }
        .sheet(isPresented: $showingQuickMemo) {
            QuickMemoView()
                .presentationDetents([.medium, .large])
        }
    }
}

private struct TodayView: View {
    let meeting: Meeting
    let tasks: [MeetingTask]
    @Binding var showingQuickMemo: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("Today")
                                .font(AppFont.pageTitle)
                            Text("Sunday, May 3")
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.appMutedText)
                        }
                        Spacer()
                        Button {
                            showingQuickMemo = true
                        } label: {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(Color.appAccent)
                        }
                        .accessibilityLabel("Quick voice memo")
                    }

                    nextMeetingCard

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("TASKS · 3")
                            .font(AppFont.tinyLabel)
                            .foregroundStyle(Color.appMutedText)
                        ForEach(tasks.prefix(3)) { task in
                            TaskRowView(task: task, compact: true)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs)
                                .hairlinePanel()
                        }
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("RECENT MEETING")
                            .font(AppFont.tinyLabel)
                            .foregroundStyle(Color.appMutedText)
                        NavigationLink {
                            MeetingReadOnlyView(meeting: meeting, tasks: tasks)
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(meeting.title)
                                    .font(AppFont.sectionHeader)
                                Text("Summary, transcript, and 4 tasks synced from Mac.")
                                    .font(AppFont.secondary)
                                    .foregroundStyle(Color.appMutedText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.md)
                            .hairlinePanel()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppSpacing.lg)
                .safeAreaPadding(.bottom, AppSpacing.xl)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var nextMeetingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Starts in 12 min · Zoom")
                .font(AppFont.metadata)
                .foregroundStyle(Color.white.opacity(0.72))
            Text("Patrick sync")
                .font(AppFont.sectionHeader)
                .foregroundStyle(.white)
            Text("Prep brief includes 3 decisions and 2 open tasks from AI CoE weekly.")
                .font(AppFont.secondary)
                .foregroundStyle(Color.white.opacity(0.88))
            Button("Start") {}
                .buttonStyle(.bordered)
                .tint(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(Color.appAccent, in: RoundedRectangle(cornerRadius: AppCorners.banner, style: .continuous))
    }
}

private struct MeetingsView: View {
    let meetings: [Meeting]
    let tasks: [MeetingTask]

    var body: some View {
        NavigationStack {
            List {
                ForEach(meetings) { meeting in
                    NavigationLink {
                        MeetingReadOnlyView(meeting: meeting, tasks: tasks.filter { $0.sourceMeetingID == meeting.id })
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(meeting.title)
                                .font(AppFont.sectionHeader)
                            Text("Sunday, May 3 · 45 min · \(meeting.attendees.count) attendees")
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.appMutedText)
                        }
                    }
                }
            }
            .navigationTitle("Meetings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TasksView: View {
    let tasks: [MeetingTask]
    @State private var filter: TaskListFilter = .today

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.md) {
                Picker("Filter", selection: $filter) {
                    ForEach(TaskListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.lg)

                List {
                    ForEach(filter.sections(for: tasks)) { section in
                        Section(section.title) {
                            ForEach(section.tasks) { task in
                                TaskRowView(task: task)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct BrainView: View {
    let results: [SearchResult]
    let onSearch: (String) -> Void
    @State private var query = "What did Patrick say about JSL POC?"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    TextField("Search meetings, people, decisions", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit {
                            onSearch(query)
                        }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: AppSpacing.sm) {
                        ForEach(["Tasks I owe Kevin", "Decisions about CLIF", "Investor prep"], id: \.self) { chip in
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
                    ForEach(results) { result in
                        SearchResultCard(result: result)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .navigationTitle("Brain")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MeetingReadOnlyView: View {
    let meeting: Meeting
    let tasks: [MeetingTask]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("45 min · \(meeting.attendees.count) attendees")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.appMutedText)

                CalmSummaryBlock(text: meeting.summary)

                ForEach(meeting.userNotes) { block in
                    HybridNoteBlockView(block: block)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("MY TASKS · 2")
                        .font(AppFont.tinyLabel)
                        .foregroundStyle(Color.appMutedText)
                    ForEach(tasks.prefix(2)) { task in
                        TaskRowView(task: task)
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct QuickMemoView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(Color.appAccent)
                Text("Listening...")
                    .font(AppFont.sectionHeader)
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("TRANSCRIBING ON DEVICE")
                        .font(AppFont.tinyLabel)
                        .foregroundStyle(Color.appMutedText)
                    Text("Ask Kevin for the final blocker list and remind me Friday morning before the manuscript review.")
                        .font(AppFont.body)
                        .lineSpacing(4)
                }
                .padding(AppSpacing.md)
                .hairlinePanel()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("EXTRACTED TASKS · 2")
                        .font(AppFont.tinyLabel)
                        .foregroundStyle(Color.appMutedText)
                    TaskRowView(task: MeetingTask(title: "Ask Kevin for blocker list", sourceMeetingTitle: "Quick note"))
                    TaskRowView(task: MeetingTask(title: "Prepare Friday reminder", sourceMeetingTitle: "Quick note"))
                }
                Spacer()
            }
            .padding(AppSpacing.lg)
            .navigationTitle("Quick note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {}
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {}
                }
            }
        }
    }
}

#Preview {
    IOSContentView(store: RecallOSAppStore.fixture())
}
