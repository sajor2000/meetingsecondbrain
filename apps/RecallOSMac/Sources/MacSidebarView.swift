import RecallOSCore
import SwiftUI

struct SidebarView: View {
    let meeting: Meeting
    let meetings: [Meeting]
    let upcomingEvents: [CalendarEvent]
    let openTaskCount: Int
    let selectedNavigation: MacNavigation
    let selectedMeetingID: UUID
    let onSelectMeeting: (UUID) -> Void
    let onSelectNavigation: (MacNavigation) -> Void
    let onCreateMeetingFromEvent: (String, Date) -> Void
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
                    SidebarRow(
                        title: event.title,
                        subtitle: event.location ?? "Calendar",
                        icon: "circle",
                        badge: event.attendees.isEmpty ? nil : "\(event.attendees.count)",
                        selected: matchingMeeting?.id == selectedMeetingID && selectedNavigation == .meeting
                    ) {
                        if let matchingMeeting {
                            onSelectMeeting(matchingMeeting.id)
                        } else {
                            onCreateMeetingFromEvent(event.title, event.startsAt)
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

struct SidebarSection<Content: View>: View {
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

struct SidebarRow: View {
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
