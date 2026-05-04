import CryptoKit
import EventKit
import Foundation
import RecallOSCore

enum EventKitCalendarEventProviderError: LocalizedError {
    case accessDenied
    case accessRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Calendar access is denied or restricted."
        case let .accessRequestFailed(reason):
            "Calendar access request failed: \(reason)"
        }
    }
}

actor EventKitCalendarEventProvider: CalendarEventProvider {
    private let eventStore: EKEventStore
    private let lookahead: TimeInterval

    init(
        eventStore: EKEventStore = EKEventStore(),
        lookahead: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.eventStore = eventStore
        self.lookahead = lookahead
    }

    func upcomingEvents(limit: Int) async throws -> [CalendarEvent] {
        guard limit > 0 else { return [] }
        guard try await hasCalendarAccess() else {
            throw EventKitCalendarEventProviderError.accessDenied
        }

        let now = Date()
        let end = now.addingTimeInterval(lookahead)
        let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: nil)

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .map(Self.calendarEvent(from:))
            .sorted { first, second in
                if first.startsAt == second.startsAt {
                    return first.attendees.count > second.attendees.count
                }
                return first.startsAt < second.startsAt
            }
            .prefix(limit)
            .map { $0 }
    }

    private func hasCalendarAccess() async throws -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                throw EventKitCalendarEventProviderError.accessRequestFailed(error.localizedDescription)
            }
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    private static func calendarEvent(from event: EKEvent) -> CalendarEvent {
        let externalID = event.eventIdentifier ?? "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)"
        return CalendarEvent(
            id: deterministicID(for: externalID),
            externalID: externalID,
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? event.title : "Untitled meeting",
            startsAt: event.startDate,
            endsAt: event.endDate,
            location: event.location,
            attendees: attendees(from: event, externalID: externalID)
        )
    }

    private static func attendees(from event: EKEvent, externalID: String) -> [Person] {
        (event.attendees ?? [])
            .compactMap { participant -> Person? in
                guard let name = participant.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                    return nil
                }
                let email = participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                return Person(
                    id: deterministicID(for: "\(externalID):\(name):\(email)"),
                    displayName: name,
                    email: email.isEmpty ? nil : email
                )
            }
    }

    private static func deterministicID(for value: String) -> UUID {
        let digest = SHA256.hash(data: Data(value.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
