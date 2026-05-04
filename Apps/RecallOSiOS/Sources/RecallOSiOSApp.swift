import RecallOSCore
import SwiftUI

@main
struct RecallOSiOSApp: App {
    var body: some Scene {
        WindowGroup {
            IOSContentView(store: RecallOSStoreFactory.makeAppStore())
        }
    }
}
