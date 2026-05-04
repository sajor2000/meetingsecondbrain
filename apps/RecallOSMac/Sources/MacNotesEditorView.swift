import RecallOSCore
import SwiftUI

struct NotesEditorView: View {
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
