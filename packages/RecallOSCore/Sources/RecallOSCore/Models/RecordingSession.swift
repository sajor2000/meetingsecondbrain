import Foundation

public struct RecordingSession: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var meetingID: UUID
    public var state: RecordingSessionState
    public var startedAt: Date?
    public var pausedAt: Date?
    public var stoppedAt: Date?
    public var elapsed: TimeInterval
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        meetingID: UUID,
        state: RecordingSessionState = .idle,
        startedAt: Date? = nil,
        pausedAt: Date? = nil,
        stoppedAt: Date? = nil,
        elapsed: TimeInterval = 0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.meetingID = meetingID
        self.state = state
        self.startedAt = startedAt
        self.pausedAt = pausedAt
        self.stoppedAt = stoppedAt
        self.elapsed = elapsed
        self.errorMessage = errorMessage
    }

    public var isActive: Bool {
        state == .recording || state == .paused || state == .finalizing || state == .enhancing
    }

    public var bannerState: RecordingBannerState {
        switch state {
        case .idle, .scheduled:
            .preMeeting
        case .detected:
            .inProgress
        case .recording, .finalizing, .enhancing:
            .recording
        case .paused:
            .paused
        case .completed, .failed:
            .adHoc
        }
    }
}

public enum RecordingSessionState: String, Codable, Hashable, Sendable, CaseIterable {
    case idle
    case scheduled
    case detected
    case recording
    case paused
    case finalizing
    case enhancing
    case completed
    case failed
}

public enum RecordingWorkflowError: LocalizedError, Equatable, Sendable {
    case noSelectedMeeting
    case microphonePermissionDenied
    case captureUnavailable(String)
    case transcriptionUnavailable(String)
    case enhancementFailed(String)
    case taskExtractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noSelectedMeeting:
            "No meeting is selected for recording."
        case .microphonePermissionDenied:
            "Microphone access is required before RecallOS can record a meeting."
        case let .captureUnavailable(reason):
            "Audio capture is unavailable: \(reason)"
        case let .transcriptionUnavailable(reason):
            "Transcription is unavailable: \(reason)"
        case let .enhancementFailed(reason):
            "Enhancement failed: \(reason)"
        case let .taskExtractionFailed(reason):
            "Task extraction failed: \(reason)"
        }
    }
}
