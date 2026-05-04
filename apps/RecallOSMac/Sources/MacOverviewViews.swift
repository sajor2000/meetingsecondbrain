import RecallOSCore
import SwiftUI

struct TodayOverviewView: View {
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

struct AllMeetingsOverviewView: View {
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

struct FolderOverviewView: View {
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

struct MeetingListCard: View {
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
