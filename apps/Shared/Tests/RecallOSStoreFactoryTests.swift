import XCTest
import RecallOSCore

@MainActor
final class RecallOSStoreFactoryTests: XCTestCase {
    func testFactoryCanUseFixtureStoreWithoutLiveConvex() async {
        let store = RecallOSStoreFactory.makeAppStore(environment: [:], usePersistentStore: false)

        await store.load()

        XCTAssertEqual(store.selectedMeeting?.title, SampleData.meeting.title)
        XCTAssertNil(store.syncError)
    }

    func testLiveConvexOptInSurfacesUnsupportedAdapterError() async {
        let store = RecallOSStoreFactory.makeAppStore(
            environment: [
                "RECALLOS_USE_LIVE_CONVEX": "1",
                "CONVEX_URL": "https://example.convex.cloud",
            ],
            supportsLiveUse: false
        )

        await store.load()

        XCTAssertNil(store.selectedMeeting)
        XCTAssertEqual(store.syncError, "Live Convex was requested, but the Swift Convex adapter is not implemented yet.")
    }

    func testLiveConvexOptInRequiresDeploymentURLWhenAdapterIsSupported() async {
        let store = RecallOSStoreFactory.makeAppStore(
            environment: ["RECALLOS_USE_LIVE_CONVEX": "1"],
            supportsLiveUse: true
        )

        await store.load()

        XCTAssertNil(store.selectedMeeting)
        XCTAssertEqual(store.syncError, "Live Convex was requested, but CONVEX_URL is not configured.")
    }

    func testConvexRepositoryReadsDeploymentURLFromInjectedEnvironment() {
        let repository = ConvexRecallOSRepository.fromEnvironment(["CONVEX_URL": "https://example.convex.cloud"])

        XCTAssertEqual(repository?.deploymentURL, "https://example.convex.cloud")
        XCTAssertNil(ConvexRecallOSRepository.fromEnvironment([:]))
    }
}
