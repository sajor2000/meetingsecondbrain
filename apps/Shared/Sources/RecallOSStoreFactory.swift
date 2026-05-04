import RecallOSCore

enum RecallOSStoreFactory {
    @MainActor
    static func makeAppStore() -> RecallOSAppStore {
        if let repository = ConvexRecallOSRepository.fromEnvironment() {
            return RecallOSAppStore(repository: repository)
        }

        return RecallOSAppStore.fixture()
    }
}
