import RecallOSCore
import SwiftUI

struct MacContentView: View {
    @EnvironmentObject private var bannerController: RecordingBannerPanelController
    @StateObject private var store: RecallOSAppStore
    @State private var rightRailTab = "Tasks"
    @State private var taskMode = "List"
    @State private var navigation: MacNavigation = .meeting
    @State private var highlightedTranscriptID: UUID?

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
                        onSelectMeeting: selectMeeting,
                        onSelectNavigation: selectNavigation,
                        onCreateMeetingFromEvent: { title, startsAt in
                            createMeeting(title: title, startsAt: startsAt)
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
                        onOpenMeeting: selectMeeting,
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
                    onPause: {
                        Swift.Task { await store.pauseRecording() }
                    },
                    onResume: {
                        Swift.Task { await store.resumeRecording() }
                    },
                    onStop: stopAndEnhance
                )
            } else {
                LoadingStateView(syncError: store.syncError)
            }
        }
        .background(Color.appBackground)
        .task {
            await store.load()
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
                onOpenMeeting: selectMeeting
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
        navigation = .meeting
        rightRailTab = "Transcript"
        Swift.Task {
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

    private func showBanner(state: RecordingBannerState) {
        let meeting = store.selectedMeeting
        bannerController.show(
            state: state,
            title: meeting?.title ?? "Ad-hoc meeting",
            subtitle: store.recordingSession?.state == .paused ? "Paused" : "Mock capture · ready for Parakeet",
            elapsed: elapsedTitle(store.recordingSession),
            onRecord: {
                startRecording()
            },
            onPause: {
                Swift.Task {
                    await store.pauseRecording()
                    showBanner(state: store.recordingSession?.bannerState ?? .adHoc)
                }
            },
            onResume: {
                Swift.Task {
                    await store.resumeRecording()
                    showBanner(state: store.recordingSession?.bannerState ?? .adHoc)
                }
            },
            onStop: stopAndEnhance
        )
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

#Preview {
    MacContentView(store: RecallOSAppStore.fixture())
        .environmentObject(RecordingBannerPanelController())
}
