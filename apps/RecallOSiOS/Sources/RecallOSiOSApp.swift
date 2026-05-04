import RecallOSCore
import SwiftUI

@main
struct RecallOSiOSApp: App {
    @StateObject private var store = RecallOSStoreFactory.makeAppStore()

    var body: some Scene {
        WindowGroup {
            IOSContentView(store: store)
        }
    }
}
