import RecallOSCore

enum RecallOSStoreFactory {
    @MainActor
    static func makeAppStore() -> RecallOSAppStore {
        do {
            return RecallOSAppStore(repository: try SwiftDataRecallOSRepository.persistent())
        } catch {
            // Convex is kept as a future sync boundary and remains ignored until
            // live reads/writes exist. If local persistence cannot open, keep the
            // app usable with fixtures and surface the local-store failure.
            return RecallOSAppStore.fixture(
                syncError: error.localizedDescription,
                workflowMessage: "Using fixture data because the local store could not open."
            )
        }
    }
}
