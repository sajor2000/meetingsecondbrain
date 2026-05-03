public struct CoreModule: Sendable {
    public let name: String
    public let defaultTranscriptionEngine: String

    public init(
        name: String = "Core",
        defaultTranscriptionEngine: String = "parakeet"
    ) {
        self.name = name
        self.defaultTranscriptionEngine = defaultTranscriptionEngine
    }
}
