import Foundation

public struct SearchResult: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var source: String
    public var snippet: String
    public var sourceMeetingID: UUID?

    public init(id: UUID = UUID(), title: String, source: String, snippet: String, sourceMeetingID: UUID? = nil) {
        self.id = id
        self.title = title
        self.source = source
        self.snippet = snippet
        self.sourceMeetingID = sourceMeetingID
    }
}
