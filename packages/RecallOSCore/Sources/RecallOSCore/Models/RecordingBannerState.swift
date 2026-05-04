import Foundation

public enum RecordingBannerState: String, Codable, Hashable, Sendable, CaseIterable {
    case preMeeting
    case inProgress
    case recording
    case paused
    case adHoc

    public var allowsDismiss: Bool {
        self != .recording && self != .paused
    }
}
