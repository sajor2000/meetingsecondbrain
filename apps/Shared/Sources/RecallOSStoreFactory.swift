import Foundation
import RecallOSCore

enum RecallOSStoreFactory {
    @MainActor
    static func makeAppStore() -> RecallOSAppStore {
        let liveConvexEnabled = ProcessInfo.processInfo.environment["RECALLOS_USE_LIVE_CONVEX"] == "1"
        if liveConvexEnabled,
           ConvexRecallOSRepository.supportsLiveUse,
           let repository = ConvexRecallOSRepository.fromEnvironment() {
            return RecallOSAppStore(repository: repository)
        }

        return RecallOSAppStore.fixture()
    }
}
