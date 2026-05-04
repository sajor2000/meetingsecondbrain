import RecallOSCore
import SwiftUI

struct RightRailView: View {
    @Binding var tab: String
    @Binding var taskMode: String
    let meeting: Meeting
    @Binding var tasks: [MeetingTask]
    let searchResults: [SearchResult]
    let highlightedSegmentID: UUID?
    let onTimestampSelected: (TimeInterval) -> Void
    let onSearch: (String) -> Void
    let onOpenMeeting: (UUID) -> Void
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
                    SearchResultCard(result: result, onOpenMeeting: onOpenMeeting)
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
