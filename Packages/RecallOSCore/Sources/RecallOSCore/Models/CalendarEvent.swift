import Foundation

public struct CalendarEvent: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var externalID: String
    public var title: String
    public var startsAt: Date
    public var endsAt: Date
    public var location: String?
    public var attendees: [Person]

    public init(id: UUID = UUID(), convexID: String? = nil, externalID: String, title: String, startsAt: Date, endsAt: Date, location: String? = nil, attendees: [Person] = []) {
        self.id = id
        self.convexID = convexID
        self.externalID = externalID
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.location = location
        self.attendees = attendees
    }
}
