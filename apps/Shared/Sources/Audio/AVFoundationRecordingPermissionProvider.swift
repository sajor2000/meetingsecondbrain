#if os(macOS)
@preconcurrency import AVFoundation
import RecallOSCore

struct AVFoundationRecordingPermissionProvider: RecordingPermissionProvider {
    func requestMicrophoneAccess() async throws -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
#endif
