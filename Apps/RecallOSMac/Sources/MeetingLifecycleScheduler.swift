import Foundation
import RecallOSCore

@MainActor
final class MeetingLifecycleScheduler: ObservableObject {
    private var dismissedEventIDs: Set<UUID> = []
    private var promptedEventIDs: Set<UUID> = []
    private let preMeetingLeadTime: TimeInterval
    private let defaults: UserDefaults
    private let dismissedEventsKey: String

    init(
        preMeetingLeadTime: TimeInterval = 2 * 60,
        defaults: UserDefaults = .standard,
        dismissedEventsKey: String = "RecallOS.dismissedPreMeetingEventIDs"
    ) {
        self.preMeetingLeadTime = preMeetingLeadTime
        self.defaults = defaults
        self.dismissedEventsKey = dismissedEventsKey
        self.dismissedEventIDs = Set(
            defaults.stringArray(forKey: dismissedEventsKey)?
                .compactMap(UUID.init(uuidString:)) ?? []
        )
    }

    func preMeetingEvent(from events: [CalendarEvent], now: Date = Date()) -> CalendarEvent? {
        events
            .filter { event in
                !dismissedEventIDs.contains(event.id)
                    && !promptedEventIDs.contains(event.id)
                    && event.startsAt >= now
                    && event.startsAt.timeIntervalSince(now) <= preMeetingLeadTime
            }
            .sorted { first, second in
                if first.attendees.count == second.attendees.count {
                    return first.startsAt < second.startsAt
                }
                return first.attendees.count > second.attendees.count
            }
            .first
    }

    func markPrompted(_ event: CalendarEvent) {
        promptedEventIDs.insert(event.id)
    }

    func dismiss(_ event: CalendarEvent) {
        dismissedEventIDs.insert(event.id)
        defaults.set(dismissedEventIDs.map(\.uuidString), forKey: dismissedEventsKey)
    }
}
