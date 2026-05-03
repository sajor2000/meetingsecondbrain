import Core
import SwiftUI

@main
struct MeetingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(module: CoreModule())
        }
    }
}
