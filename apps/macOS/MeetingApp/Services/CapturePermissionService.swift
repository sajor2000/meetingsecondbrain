import AVFoundation
import CoreGraphics
import Foundation

enum CapturePermissionStatus: Equatable {
    case authorized
    case denied
    case notDetermined
}

struct CapturePermissionSnapshot: Equatable {
    let microphone: CapturePermissionStatus
    let screenRecording: CapturePermissionStatus

    var isAuthorized: Bool {
        microphone == .authorized && screenRecording == .authorized
    }
}

protocol CapturePermissionChecking: Sendable {
    func checkPermissions() async -> CapturePermissionSnapshot
}

struct CapturePermissionService: CapturePermissionChecking, Sendable {
    func checkPermissions() async -> CapturePermissionSnapshot {
        async let microphone = microphonePermission()
        let screenRecording = screenRecordingPermission()

        return await CapturePermissionSnapshot(
            microphone: microphone,
            screenRecording: screenRecording
        )
    }

    private func microphonePermission() async -> CapturePermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .authorized : .denied
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private func screenRecordingPermission() -> CapturePermissionStatus {
        if CGPreflightScreenCaptureAccess() {
            return .authorized
        }

        let granted = CGRequestScreenCaptureAccess()
        return granted ? .authorized : .denied
    }
}
