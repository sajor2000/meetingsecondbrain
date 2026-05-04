import RecallOSCore

enum RecallOSStoreFactory {
    @MainActor
    static func makeAppStore() -> RecallOSAppStore {
        // Convex is kept as a future sync boundary, but the adapter intentionally
        // throws until live reads/writes are implemented. Prefer reliable local
        // fixture behavior even when CONVEX_URL is present in the developer env.
        return RecallOSAppStore.fixture()
    }
}
