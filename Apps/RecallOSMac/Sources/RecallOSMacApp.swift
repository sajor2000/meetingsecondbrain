import Foundation
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
        bannerController.show(
            state: store.recordingSession?.bannerState ?? .preMeeting,
            title: recordingMeetingTitle(),
            subtitle: store.workflowMessage ?? "Mock capture · ready for Parakeet",
            elapsed: elapsedTitle(store.recordingSession),
            onRecord: startRecordingFromCommand,
            onPause: pauseRecordingFromCommand,
            onResume: resumeRecordingFromCommand,
            onStop: stopRecordingFromCommand
        )
    }

    private func recordingMeetingTitle() -> String {
        if let recordingMeetingID = store.recordingSession?.meetingID,
           let recordingMeeting = store.meetings.first(where: { $0.id == recordingMeetingID }) {
            return recordingMeeting.title
        }
        return store.selectedMeeting?.title ?? "Ad-hoc meeting"
    }

    private func elapsedTitle(_ session: RecordingSession?) -> String {
        guard let session else { return "00:00" }
        let elapsed: TimeInterval
        if let startedAt = session.startedAt {
            let end = session.pausedAt ?? session.stoppedAt ?? Date()
            elapsed = max(0, end.timeIntervalSince(startedAt))
        } else {
            elapsed = session.elapsed
        }
        return Self.elapsedFormatter.string(from: elapsed) ?? "00:00"
    }

    private static let elapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}
