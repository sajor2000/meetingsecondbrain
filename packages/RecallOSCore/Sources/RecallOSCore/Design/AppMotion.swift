import SwiftUI

public enum AppMotion {
    public static let quick = Animation.easeOut(duration: 0.16)
    public static let calm = Animation.easeInOut(duration: 0.24)
    public static let recordingPulse = Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
}
