import RecallOSCore
import SwiftUI

@main
struct RecallOSMacApp: App {
    @StateObject private var bannerController = RecordingBannerPanelController()
    @StateObject private var store = RecallOSStoreFactory.makeAppStore()

    var body: some Scene {
        WindowGroup {
            MacContentView(store: store)
                .environmentObject(bannerController)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .commands {
            CommandMenu("RecallOS") {
                Button("Search Second Brain") {}
                    .keyboardShortcut("k", modifiers: [.command])
                Button("Record") {
                    startRecordingFromCommand()
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button("Stop Recording") {
                    stopRecordingFromCommand()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("New Task") {}
                    .keyboardShortcut("n", modifiers: [])
            }
        }
    }

    private func startRecordingFromCommand() {
        Task {
            await store.startRecording()
            showBannerFromCommand()
        }
    }

    private func stopRecordingFromCommand() {
        Task {
            await store.stopAndEnhanceRecording()
            showBannerFromCommand()
        }
    }

    private func pauseRecordingFromCommand() {
        Task {
            await store.pauseRecording()
            showBannerFromCommand()
        }
    }

    private func resumeRecordingFromCommand() {
        Task {
            await store.resumeRecording()
            showBannerFromCommand()
        }
    }

    @MainActor
    private func showBannerFromCommand() {
        let title = store.selectedMeeting?.title ?? "Ad-hoc meeting"
        bannerController.show(
            state: store.recordingSession?.bannerState ?? .preMeeting,
            title: title,
            subtitle: store.workflowMessage ?? "Mock capture · ready for Parakeet",
            onRecord: startRecordingFromCommand,
            onPause: pauseRecordingFromCommand,
            onResume: resumeRecordingFromCommand,
            onStop: stopRecordingFromCommand
        )
    }
}
