import RecallOSCore

enum RecallOSStoreFactory {
    @MainActor
    static func makeAppStore() -> RecallOSAppStore {
        do {
            return RecallOSAppStore(
                repository: try SwiftDataRecallOSRepository.persistent(),
                permissionProvider: permissionProvider(),
                audioProvider: audioProvider(),
                calendarProvider: calendarProvider()
            )
        } catch {
            // Convex is kept as a future sync boundary and remains ignored until
            // live reads/writes exist. If local persistence cannot open, keep the
            // app usable with fixtures and surface the local-store failure.
            return RecallOSAppStore.fixture(
                syncError: error.localizedDescription,
                workflowMessage: "Using fixture data because the local store could not open."
            )
        }
    }

    private static func calendarProvider() -> any CalendarEventProvider {
        #if os(macOS)
        EventKitCalendarEventProvider()
        #else
        MockCalendarEventProvider()
        #endif
    }

    private static func permissionProvider() -> any RecordingPermissionProvider {
        #if os(macOS)
        AVFoundationRecordingPermissionProvider()
        #else
        AllowAllRecordingPermissionProvider()
        #endif
    }

    private static func audioProvider() -> any AudioCaptureProvider {
        #if os(macOS)
        AVFoundationMicrophoneAudioCaptureProvider()
        #else
        MockAudioCaptureProvider()
        #endif
    }
}
