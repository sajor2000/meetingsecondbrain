import RecallOSCore
import SwiftUI

struct MacContentView: View {
    @EnvironmentObject private var bannerController: RecordingBannerPanelController
    @StateObject private var store: RecallOSAppStore
    @StateObject private var lifecycleScheduler = MeetingLifecycleScheduler()
    @State private var rightRailTab = "Tasks"
    @State private var taskMode = "List"
    @State private var navigation: MacNavigation = .meeting
    @State private var highlightedTranscriptID: UUID?
    private let lifecycleTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(store: RecallOSAppStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let meeting = store.selectedMeeting {
                titleBar(meeting: meeting, session: store.recordingSession)
                Divider()
                HStack(spacing: 0) {
                    SidebarView(
                        meeting: meeting,
                        meetings: store.meetings,
                        upcomingEvents: store.upcomingEvents,
                        openTaskCount: store.tasks.filter { $0.status != .done }.count,
                        selectedNavigation: navigation,
                        selectedMeetingID: meeting.id,
                        recordingMeetingID: store.recordingSession?.meetingID,
                        onSelectMeeting: selectMeeting,
                        onSelectNavigation: selectNavigation,
                        onCreateMeetingFromEvent: { event in
                            createMeeting(from: event)
                        },
                        onCreateMeeting: {
                            createMeeting(title: "Ad-hoc meeting")
                        }
                    )
                        .frame(width: 228)
                    Divider()
                    mainContent(meeting: meeting)
                        .frame(minWidth: 470)
                    Divider()
                    RightRailView(
                        tab: $rightRailTab,
                        taskMode: $taskMode,
                        meeting: meeting,
                        tasks: $store.tasks,
                        searchResults: store.searchResults,
                        highlightedSegmentID: highlightedTranscriptID,
                        onTimestampSelected: handleTimestampSelected,
                        onSearch: { query in
                            Swift.Task { await store.search(query) }
                        },
                        onShowFullMeeting: selectMeeting,
                        onMoveTasks: { ids, status in
                            Task {
                                await store.moveTasks(ids, to: status)
                            }
                        }
                    )
                        .frame(width: 330)
                }
                Divider()
                RecordingStatusBar(
                    session: store.recordingSession,
                    workflowMessage: store.workflowMessage,
                    onStart: startRecording,
                    onPause: pauseRecording,
                    onResume: resumeRecording,
                    onStop: stopAndEnhance
                )
            } else {
                ProgressView("Loading meetings")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground)
        .task {
            await store.load()
            evaluatePreMeetingBanner()
        }
        .onReceive(lifecycleTimer) { _ in
            Swift.Task {
                await store.refreshMeetingLifecycle()
                evaluatePreMeetingBanner()
            }
        }
        .onChange(of: store.upcomingEvents) { _, _ in
            evaluatePreMeetingBanner()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showBanner(state: .preMeeting)
                } label: {
                    Label("Pre-meeting", systemImage: "calendar.badge.clock")
                }
                Button {
                    startRecording()
                } label: {
                    Label("Record", systemImage: "record.circle")
                }
                Button {
                    stopAndEnhance()
                } label: {
                    Label("Enhance", systemImage: "sparkles")
                }
            }
        }
    }

    @ViewBuilder
    private func mainContent(meeting: Meeting) -> some View {
        switch navigation {
        case .meeting:
            NotesEditorView(
                meeting: meeting,
                workflowMessage: store.workflowMessage,
                syncError: store.syncError,
                onTimestampSelected: handleTimestampSelected
            )
        case .today:
            TodayOverviewView(meeting: meeting, tasks: store.tasks) {
                navigation = .meeting
            }
        case .allMeetings:
            AllMeetingsOverviewView(meetings: store.meetings, onSelectMeeting: selectMeeting)
        case .tasks:
            MacTasksContentView(tasks: $store.tasks, onMoveTasks: { ids, status in
                Swift.Task { await store.moveTasks(ids, to: status) }
            })
        case .secondBrain:
            SecondBrainContentView(
                searchResults: store.searchResults,
                onSearch: { query in
                    Swift.Task { await store.search(query) }
                },
                onShowFullMeeting: selectMeeting
            )
        case .people:
            PlaceholderContentView(title: "People", message: "People profiles will collect recurring speakers, owners, and meeting context.")
        case let .folder(folder):
            FolderOverviewView(folder: folder, meetings: store.meetings.filter { $0.folder == folder }, onSelectMeeting: selectMeeting)
        }
    }

    private func titleBar(meeting: Meeting, session: RecordingSession?) -> some View {
        HStack {
            Text("RecallOS · \(meeting.title)")
                .font(AppFont.secondary)
                .foregroundStyle(Color.appMutedText)
            Spacer()
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(session?.state == .recording ? Color.appDanger : Color.appAccent)
                    .frame(width: 9, height: 9)
                Text(sessionTitle(session))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.appMutedText)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appSurface)
    }

    private func startRecording() {
        startRecording(from: nil)
    }

    private func startRecording(from event: CalendarEvent?) {
        navigation = .meeting
        rightRailTab = "Transcript"
        Swift.Task {
            if let event {
                await store.createOrSelectMeeting(for: event)
            }
            await store.startRecording()
            showBanner(state: store.recordingSession?.bannerState ?? .recording)
        }
    }

    private func stopAndEnhance() {
        navigation = .meeting
        rightRailTab = "Tasks"
        Swift.Task {
            await store.stopAndEnhanceRecording()
            showBanner(state: store.recordingSession?.bannerState ?? .adHoc)
        }
    }

    private func showBanner(state: RecordingBannerState, event: CalendarEvent? = nil) {
        let meeting = store.recordingSession.flatMap { session in
            store.meetings.first { $0.id == session.meetingID }
        } ?? store.selectedMeeting
        bannerController.show(
            state: state,
            title: event?.title ?? meeting?.title ?? "Ad-hoc meeting",
            subtitle: store.recordingSession?.state == .paused ? "Paused" : "Mock capture · ready for Parakeet",
            elapsed: elapsedTitle(store.recordingSession),
            onRecord: { startRecording(from: event) },
            onPause: pauseRecording,
            onResume: resumeRecording,
            onStop: stopAndEnhance,
            onDismiss: {
                if let event {
                    lifecycleScheduler.dismiss(event)
                }
            }
        )
    }

    private func pauseRecording() {
        Swift.Task {
            await store.pauseRecording()
            showBanner(state: store.recordingSession?.bannerState ?? .paused)
        }
    }

    private func resumeRecording() {
        Swift.Task {
            await store.resumeRecording()
            showBanner(state: store.recordingSession?.bannerState ?? .recording)
        }
    }

    private func selectMeeting(_ meetingID: UUID) {
        navigation = .meeting
        Swift.Task {
            await store.selectMeeting(meetingID)
        }
    }

    private func selectNavigation(_ nextNavigation: MacNavigation) {
        navigation = nextNavigation
        switch nextNavigation {
        case .meeting:
            break
        case .tasks:
            rightRailTab = "Tasks"
        case .secondBrain:
            rightRailTab = "Ask"
        case .today, .allMeetings, .people, .folder:
            break
        }
    }

    private func createMeeting(title: String, startsAt: Date = Date()) {
        navigation = .meeting
        rightRailTab = "Transcript"
        Swift.Task {
            await store.createMeeting(title: title, startsAt: startsAt)
        }
    }

    private func createMeeting(from event: CalendarEvent) {
        navigation = .meeting
        rightRailTab = "Transcript"
        Swift.Task {
            await store.createOrSelectMeeting(for: event)
        }
    }

    private func evaluatePreMeetingBanner() {
        guard store.recordingSession?.isActive != true,
              let event = lifecycleScheduler.preMeetingEvent(from: store.upcomingEvents) else {
            return
        }

        lifecycleScheduler.markPrompted(event)
        showBanner(state: .preMeeting, event: event)
    }

    private func handleTimestampSelected(_ timestamp: TimeInterval) {
        navigation = .meeting
        rightRailTab = "Transcript"
        highlightedTranscriptID = nearestTranscriptID(to: timestamp)
    }

    private func nearestTranscriptID(to timestamp: TimeInterval) -> UUID? {
        store.selectedMeeting?.transcriptSegments.min { first, second in
            abs(first.startTime - timestamp) < abs(second.startTime - timestamp)
        }?.id
    }

    private func sessionTitle(_ session: RecordingSession?) -> String {
        guard let session else { return "Ready" }
        switch session.state {
        case .idle, .scheduled:
            return "Ready"
        case .detected:
            return "Detected"
        case .recording:
            return "Recording"
        case .paused:
            return "Paused"
        case .finalizing:
            return "Finalizing"
        case .enhancing:
            return "Enhancing"
        case .completed:
            return "Enhanced"
        case .failed:
            return "Needs attention"
        }
    }

    private func elapsedTitle(_ session: RecordingSession?) -> String {
        guard let session else { return "00:00" }
        let elapsed: TimeInterval
        if let startedAt = session.startedAt {
            let end = session.pausedAt ?? session.stoppedAt ?? Date()
            elapsed = max(0, end.timeIntervalSince(startedAt))
        } else {
            elapsed = session.elapsed
        }
        return Self.elapsedFormatter.string(from: elapsed) ?? "00:00"
    }

    private static let elapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

private enum MacNavigation: Hashable {
    case meeting
    case today
    case allMeetings
    case tasks
    case secondBrain
    case people
    case folder(String)
}

private struct SidebarView: View {
    let meeting: Meeting
    let meetings: [Meeting]
    let upcomingEvents: [CalendarEvent]
    let openTaskCount: Int
    let selectedNavigation: MacNavigation
    let selectedMeetingID: UUID
    let recordingMeetingID: UUID?
    let onSelectMeeting: (UUID) -> Void
    let onSelectNavigation: (MacNavigation) -> Void
    let onCreateMeetingFromEvent: (CalendarEvent) -> Void
    let onCreateMeeting: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            SidebarSection(title: "Coming up") {
                SidebarRow(
                    title: meeting.title,
                    subtitle: meeting.status == .recording ? "Recording · Zoom" : "Selected",
                    icon: "record.circle.fill",
                    badge: meeting.status == .recording ? "now" : nil,
                    selected: selectedNavigation == .meeting
                ) {
                    onSelectMeeting(meeting.id)
                }
                ForEach(upcomingEvents.prefix(3)) { event in
                    let matchingMeeting = meetings.first { candidate in
                        candidate.calendarEventID == event.id || candidate.title == event.title
                    }
                    let isRecordingEvent = matchingMeeting?.id == recordingMeetingID
                    SidebarRow(
                        title: event.title,
                        subtitle: isRecordingEvent ? "Recording · \(event.location ?? "Calendar")" : event.location ?? "Calendar",
                        icon: isRecordingEvent ? "record.circle.fill" : "circle",
                        badge: isRecordingEvent ? "now" : event.attendees.isEmpty ? nil : "\(event.attendees.count)",
                        selected: matchingMeeting?.id == selectedMeetingID && selectedNavigation == .meeting
                    ) {
                        if let matchingMeeting {
                            onSelectMeeting(matchingMeeting.id)
                        } else {
                            onCreateMeetingFromEvent(event)
                        }
                    }
                }
            }

            SidebarSection(title: "Library") {
                SidebarRow(title: "Today", subtitle: "\(openTaskCount) open tasks", icon: "house", selected: selectedNavigation == .today) {
                    onSelectNavigation(.today)
                }
                SidebarRow(title: "All meetings", subtitle: "\(meetings.count) notes", icon: "square", selected: selectedNavigation == .allMeetings) {
                    onSelectNavigation(.allMeetings)
                }
                SidebarRow(title: "Tasks", subtitle: "\(openTaskCount) open", icon: "checkmark", badge: "\(openTaskCount)", selected: selectedNavigation == .tasks) {
                    onSelectNavigation(.tasks)
                }
                SidebarRow(title: "Second brain", subtitle: "Ask anything", icon: "scope", selected: selectedNavigation == .secondBrain) {
                    onSelectNavigation(.secondBrain)
                }
                SidebarRow(title: "People", subtitle: "\(peopleCount) profiles", icon: "person.2", selected: selectedNavigation == .people) {
                    onSelectNavigation(.people)
                }
            }

            SidebarSection(title: "Folders") {
                ForEach(folders, id: \.self) { folder in
                    SidebarRow(
                        title: folder,
                        subtitle: "\(folderCount(folder)) meetings",
                        icon: "circle.fill",
                        selected: selectedNavigation == .folder(folder)
                    ) {
                        onSelectNavigation(.folder(folder))
                    }
                }
            }

            Spacer()
            Button {
                onCreateMeeting()
            } label: {
                Label("New meeting", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
            .controlSize(.small)

            Text("j/k navigate · x complete · n new")
                .font(AppFont.tinyLabel)
                .foregroundStyle(Color.appMutedText)
        }
        .padding(AppSpacing.lg)
        .background(Color.appSurface)
    }

    private var folders: [String] {
        Array(Set(meetings.compactMap(\.folder))).sorted()
    }

    private func folderCount(_ folder: String) -> Int {
        meetings.filter { $0.folder == folder }.count
    }

    private var peopleCount: Int {
        Set(meetings.flatMap { $0.attendees.map(\.id) }).count
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(AppFont.tinyLabel)
                .foregroundStyle(Color.appMutedText)
            content
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var badge: String?
    var selected = false
    var action: () -> Void = {}
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(selected ? Color.white : Color.appAccent)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.secondary)
                    Text(subtitle)
                        .font(AppFont.metadata)
                        .foregroundStyle(selected ? Color.white.opacity(0.82) : Color.appMutedText)
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(AppFont.tinyLabel)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(selected ? Color.white.opacity(0.35) : Color.appHairline))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: AppCorners.panel))
        .contentShape(RoundedRectangle(cornerRadius: AppCorners.panel))
        .onHover { isHovering = $0 }
        .accessibilityLabel("\(title), \(subtitle)")
    }

    private var rowBackground: Color {
        if selected {
            return Color.appAccent
        }
        return isHovering ? Color.appSecondarySurface : Color.clear
    }
}

private struct NotesEditorView: View {
    let meeting: Meeting
    let workflowMessage: String?
    let syncError: String?
    let onTimestampSelected: (TimeInterval) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(meeting.title)
                            .font(AppFont.pageTitle)
                        HStack(spacing: AppSpacing.sm) {
                            Text(MeetingDateFormat.dateString(meeting.startsAt))
                            Text(MeetingDateFormat.timeRange(startsAt: meeting.startsAt, endsAt: meeting.endsAt))
                            Text("\(meeting.attendees.count) attendees")
                            if showsTemplateBadge {
                                Text("AI CoE template applied")
                                    .foregroundStyle(Color.appAccent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .overlay(Capsule().stroke(Color.appAccent.opacity(0.4)))
                            }
                        }
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.appMutedText)
                }

                CalmSummaryBlock(text: meeting.summary)

                if let syncError {
                    Text(syncError)
                        .font(AppFont.secondary)
                        .foregroundStyle(Color.appDanger)
                        .padding(AppSpacing.md)
                        .hairlinePanel()
                } else if let workflowMessage {
                    Text(workflowMessage)
                        .font(AppFont.secondary)
                        .foregroundStyle(Color.appAccent)
                        .padding(AppSpacing.md)
                        .hairlinePanel()
                }

                ForEach(meeting.userNotes) { block in
                    HybridNoteBlockView(block: block, onTimestampSelected: onTimestampSelected)
                }

                if !meeting.audioArtifacts.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Audio artifacts")
                            .font(AppFont.sectionHeader)
                        ForEach(meeting.audioArtifacts) { artifact in
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(artifact.microphoneAudioPath ?? "Microphone artifact pending")
                                    .font(AppFont.metadata)
                                    .foregroundStyle(Color.appAISuggestionText)
                                    .lineLimit(2)
                                Text(artifact.byteSize.map { "\($0) bytes" } ?? artifact.diagnostics)
                                    .font(AppFont.metadata)
                                    .foregroundStyle(Color.appMutedText)
                            }
                            Divider()
                        }
                    }
                    .padding(AppSpacing.md)
                    .hairlinePanel()
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Enhancement preview")
                        .font(AppFont.sectionHeader)
                    Text("Keep my notes, add the missing context")
                        .font(AppFont.body)
                    HStack {
                        Button("Reject AI additions") {}
                        Button("Edit before saving") {}
                        Button("Accept enhancement") {}
                            .buttonStyle(.borderedProminent)
                            .tint(Color.appAccent)
                    }
                    .controlSize(.small)
                }
                .padding(AppSpacing.md)
                .hairlinePanel()
            }
            .padding(AppSpacing.xl)
        }
    }

    private var showsTemplateBadge: Bool {
        meeting.title == "AI CoE weekly"
    }
}

private struct RightRailView: View {
    @Binding var tab: String
    @Binding var taskMode: String
    let meeting: Meeting
    @Binding var tasks: [MeetingTask]
    let searchResults: [SearchResult]
    let highlightedSegmentID: UUID?
    let onTimestampSelected: (TimeInterval) -> Void
    let onSearch: (String) -> Void
    let onShowFullMeeting: (UUID) -> Void
    let onMoveTasks: ([UUID], TaskStatus) -> Void
    @State private var brainQuery = "What did Patrick say about JSL POC?"

    var body: some View {
        VStack(spacing: 0) {
            Picker("Rail", selection: $tab) {
                Text("Transcript").tag("Transcript")
                Text("Ask").tag("Ask")
                Text("Tasks").tag("Tasks")
            }
            .pickerStyle(.segmented)
            .padding(AppSpacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if tab == "Tasks" {
                        taskRail
                    } else if tab == "Transcript" {
                        transcriptRail
                    } else {
                        brainRail
                    }
                }
                .padding(AppSpacing.md)
            }
        }
        .background(Color.appSurface)
    }

    private var taskRail: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Picker("Mode", selection: $taskMode) {
                Text("List").tag("List")
                Text("Board").tag("Board")
            }
            .pickerStyle(.segmented)

            if taskMode == "Board" {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Board mode is optional for meeting-derived task workflow.")
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.appMutedText)
                    TaskBoardView(tasks: $tasks, onMove: onMoveTasks)
                }
            } else {
                GroupedTaskList(tasks: tasks)
            }
        }
    }

    private var transcriptRail: some View {
        ForEach(meeting.transcriptSegments) { segment in
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(segment.speaker.displayName)
                        .font(AppFont.tinyLabel)
                        .foregroundStyle(Color.appAccent)
                    Spacer()
                    TimestampLink(label: "↗ \(Self.timestampFormatter.string(from: segment.startTime) ?? "00:00")") {
                        onTimestampSelected(segment.startTime)
                    }
                }
                Text(segment.text)
                    .font(AppFont.secondary)
                    .foregroundStyle(Color.appAISuggestionText)
            }
            .padding(AppSpacing.sm)
            .background(
                highlightedSegmentID == segment.id ? Color.appAccent.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: AppCorners.panel)
            )
            Divider()
        }
    }

    private var brainRail: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            TextField("Ask across meetings", text: $brainQuery)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit {
                    onSearch(brainQuery)
                }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: AppSpacing.xs) {
                ForEach(["Tasks I owe Kevin", "Decisions about CLIF", "Investor prep"], id: \.self) { chip in
                    Button {
                        brainQuery = chip
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
                    SearchResultCard(result: result, onShowFullMeeting: onShowFullMeeting)
                }
            }
        }
    }

    private static let timestampFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

private struct TodayOverviewView: View {
    let meeting: Meeting
    let tasks: [MeetingTask]
    let onOpenMeeting: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Today")
                    .font(AppFont.pageTitle)
                Text(MeetingDateFormat.dateString(Date()))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.appMutedText)

                Button(action: onOpenMeeting) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(meeting.title)
                            .font(AppFont.sectionHeader)
                        Text("\(MeetingDateFormat.timeRange(startsAt: meeting.startsAt, endsAt: meeting.endsAt)) · \(meeting.attendees.count) attendees")
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.appMutedText)
                        Text(meeting.summary)
                            .font(AppFont.secondary)
                            .foregroundStyle(Color.appAISuggestionText)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .hairlinePanel()
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("TASKS · \(tasks.filter { $0.status != .done }.count)")
                        .font(AppFont.tinyLabel)
                        .foregroundStyle(Color.appMutedText)
                    ForEach(tasks.prefix(4)) { task in
                        TaskRowView(task: task)
                        Divider()
                    }
                }
            }
            .padding(AppSpacing.xl)
        }
    }
}

private struct AllMeetingsOverviewView: View {
    let meetings: [Meeting]
    let onSelectMeeting: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("All meetings")
                    .font(AppFont.pageTitle)
                ForEach(meetings) { meeting in
                    Button {
                        onSelectMeeting(meeting.id)
                    } label: {
                        MeetingListCard(meeting: meeting)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.xl)
        }
    }
}

private struct FolderOverviewView: View {
    let folder: String
    let meetings: [Meeting]
    let onSelectMeeting: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(folder)
                    .font(AppFont.pageTitle)
                if meetings.isEmpty {
                    Text("Meetings moved here will appear in this folder.")
                        .font(AppFont.secondary)
                        .foregroundStyle(Color.appMutedText)
                } else {
                    ForEach(meetings) { meeting in
                        Button {
                            onSelectMeeting(meeting.id)
                        } label: {
                            MeetingListCard(meeting: meeting)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppSpacing.xl)
        }
    }
}

private struct MeetingListCard: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(meeting.title)
                .font(AppFont.sectionHeader)
            Text("\(MeetingDateFormat.dateString(meeting.startsAt)) · \(MeetingDateFormat.durationString(startsAt: meeting.startsAt, endsAt: meeting.endsAt)) · \(meeting.attendees.count) attendees")
                .font(AppFont.metadata)
                .foregroundStyle(Color.appMutedText)
            Text(meeting.summary.isEmpty ? "Your meetings will appear here." : meeting.summary)
                .font(AppFont.secondary)
                .foregroundStyle(Color.appAISuggestionText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .hairlinePanel()
    }
}

private struct MacTasksContentView: View {
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

private struct SecondBrainContentView: View {
    let searchResults: [SearchResult]
    let onSearch: (String) -> Void
    let onShowFullMeeting: (UUID) -> Void
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
                        SearchResultCard(result: result, onShowFullMeeting: onShowFullMeeting)
                    }
                }
            }
            .padding(AppSpacing.xl)
        }
    }
}

private struct PlaceholderContentView: View {
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

private struct GroupedTaskList: View {
    let tasks: [MeetingTask]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            TaskGroup(title: "Overdue", tasks: tasks.filter { $0.priority == .high && $0.status != .done })
            TaskGroup(title: "Today", tasks: tasks.filter { $0.status == .today })
            TaskGroup(title: "Done today", tasks: tasks.filter { $0.status == .done })
        }
    }
}

private struct TaskGroup: View {
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

private struct RecordingStatusBar: View {
    let session: RecordingSession?
    let workflowMessage: String?
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(session?.state == .recording ? Color.appDanger : Color.appAccent)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(AppFont.metadata)
            }
            Spacer()
            if session?.state == .recording {
                Button("Pause", action: onPause)
                Button("Stop & enhance", action: onStop)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
            } else if session?.state == .paused {
                Button("Resume", action: onResume)
                Button("Stop & enhance", action: onStop)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
            } else {
                Button("Start recording", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
            }
            Text("⌘⇧3 to screenshot")
                .font(AppFont.metadata)
                .foregroundStyle(Color.appMutedText)
        }
        .controlSize(.small)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
    }

    private var statusText: String {
        if let workflowMessage {
            return workflowMessage
        }

        switch session?.state {
        case .recording:
            return "Capturing audio · mock transcription provider"
        case .paused:
            return "Paused · transcript streaming is waiting"
        case .finalizing:
            return "Finalizing audio"
        case .enhancing:
            return "Enhancing notes and extracting tasks"
        case .completed:
            return "Enhanced notes ready"
        case .failed:
            return "Recording needs attention"
        default:
            return "Ready to record · providers configured"
        }
    }
}

private enum MeetingDateFormat {
    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func timeRange(startsAt: Date, endsAt: Date) -> String {
        "\(timeString(startsAt))-\(timeString(endsAt))"
    }

    static func durationString(startsAt: Date, endsAt: Date) -> String {
        let minutes = max(1, Int(endsAt.timeIntervalSince(startsAt) / 60))
        return "\(minutes) min"
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    MacContentView(store: RecallOSAppStore.fixture())
        .environmentObject(RecordingBannerPanelController())
}
