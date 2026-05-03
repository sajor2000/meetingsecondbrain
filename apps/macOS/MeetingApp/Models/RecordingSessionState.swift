import Foundation

enum RecordingSessionState: Equatable {
    case idle
    case checkingPermissions
    case ready
    case recording(RecordingSessionSnapshot)
    case stopping
    case completed(RecordingArtifact)
    case failed(RecordingFailureReason)

    var isRecording: Bool {
        if case .recording = self {
            return true
        }
        return false
    }

    var canStart: Bool {
        switch self {
        case .idle, .ready, .completed, .failed:
            return true
        case .checkingPermissions, .recording, .stopping:
            return false
        }
    }

    var canStop: Bool {
        isRecording
    }
}

struct RecordingSessionSnapshot: Equatable {
    let sessionId: String
    let startedAt: Date
    let artifact: RecordingArtifact

    var elapsed: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
}

enum RecordingFailureReason: Equatable, LocalizedError {
    case microphonePermissionDenied
    case screenRecordingPermissionDenied
    case recorderFailed(String)
    case artifactLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required."
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required for system audio."
        case let .recorderFailed(message):
            return message
        case let .artifactLoadFailed(message):
            return message
        }
    }
}
