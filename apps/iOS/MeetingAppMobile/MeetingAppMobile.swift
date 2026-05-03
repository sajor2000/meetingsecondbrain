import Core
import SwiftUI

@main
struct MeetingAppMobile: App {
    var body: some Scene {
        WindowGroup {
            ContentView(module: CoreModule())
        }
    }
}
