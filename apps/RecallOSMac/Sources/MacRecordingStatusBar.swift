import RecallOSCore
import SwiftUI

struct RecordingStatusBar: View {
    let session: RecordingSession?
    let workflowMessage: String?
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(session?.state == .recording ? Color.appDanger : Color.appAccent)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(AppFont.metadata)
            }
            Spacer()
            if session?.state == .recording {
                Button("Pause", action: onPause)
                Button("Stop & enhance", action: onStop)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
            } else if session?.state == .paused {
                Button("Resume", action: onResume)
                Button("Stop & enhance", action: onStop)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
            } else {
                Button("Start recording", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
            }
            Text("⌘⇧3 to screenshot")
                .font(AppFont.metadata)
                .foregroundStyle(Color.appMutedText)
        }
        .controlSize(.small)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
    }

    private var statusText: String {
        if let workflowMessage {
            return workflowMessage
        }

        switch session?.state {
        case .recording:
            return "Capturing audio · mock transcription provider"
        case .paused:
            return "Paused · transcript streaming is waiting"
        case .finalizing:
            return "Finalizing audio"
        case .enhancing:
            return "Enhancing notes and extracting tasks"
        case .completed:
            return "Enhanced notes ready"
        case .failed:
            return "Recording needs attention"
        default:
            return "Ready to record · providers configured"
        }
    }
}

enum MeetingDateFormat {
    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func timeRange(startsAt: Date, endsAt: Date) -> String {
        "\(timeString(startsAt))-\(timeString(endsAt))"
    }

    static func durationString(startsAt: Date, endsAt: Date) -> String {
        let minutes = max(1, Int(endsAt.timeIntervalSince(startsAt) / 60))
        return "\(minutes) min"
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
