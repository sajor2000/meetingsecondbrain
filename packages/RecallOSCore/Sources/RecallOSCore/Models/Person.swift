import Foundation

public struct Person: Identifiable, Codable, Hashable, Sendable, SyncBacked {
    public var id: UUID
    public var convexID: String?
    public var displayName: String
    public var email: String?
    public var role: String?

    public init(id: UUID = UUID(), convexID: String? = nil, displayName: String, email: String? = nil, role: String? = nil) {
        self.id = id
        self.convexID = convexID
        self.displayName = displayName
        self.email = email
        self.role = role
    }
}
