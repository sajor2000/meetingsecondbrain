import RecallOSCore
import XCTest

final class RecallOSiOSTests: XCTestCase {
    func testCompanionFixtureLoadsOnIOS() async {
        let store = await RecallOSAppStore.fixture()

        await store.load()

        let selectedTitle = await store.selectedMeeting?.title
        let taskCount = await store.tasks.count

        XCTAssertEqual(selectedTitle, SampleData.meeting.title)
        XCTAssertGreaterThan(taskCount, 0)
    }
}
