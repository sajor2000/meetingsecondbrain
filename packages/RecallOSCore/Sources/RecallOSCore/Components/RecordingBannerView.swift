import SwiftUI

public struct RecordingBannerView: View {
    private let state: RecordingBannerState
    private let title: String
    private let subtitle: String
    private let elapsed: String
    private let onRecord: () -> Void
    private let onPause: () -> Void
    private let onStop: () -> Void
    private let onDismiss: () -> Void
    @State private var pulsing = false

    public init(
        state: RecordingBannerState,
        title: String,
        subtitle: String,
        elapsed: String = "00:00",
        onRecord: @escaping () -> Void = {},
        onPause: @escaping () -> Void = {},
        onStop: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.state = state
        self.title = title
        self.subtitle = subtitle
        self.elapsed = elapsed
        self.onRecord = onRecord
        self.onPause = onPause
        self.onStop = onStop
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: AppSpacing.md) {
            statusDot
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(displayTitle)
                    .font(AppFont.sectionHeader)
                Text(displaySubtitle)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.appMutedText)
            }
            Spacer(minLength: AppSpacing.lg)
            actions
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppCorners.banner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.banner, style: .continuous)
                .stroke(Color.appHairline, lineWidth: 1)
        )
        .onAppear {
            if state == .recording {
                pulsing = true
            }
        }
    }

    private var displayTitle: String {
        switch state {
        case .preMeeting:
            return title
        case .inProgress:
            return "Mic detected in \(title)"
        case .recording:
            return "Recording \(title)"
        case .paused:
            return "Paused \(title)"
        case .adHoc:
            return "Unscheduled Zoom call"
        }
    }

    private var displaySubtitle: String {
        switch state {
        case .preMeeting:
            return "Starts in 2 minutes · Zoom"
        case .inProgress:
            return "Meeting appears active"
        case .recording:
            return "\(elapsed) · \(subtitle)"
        case .paused:
            return "\(elapsed) · paused"
        case .adHoc:
            return "Create ad-hoc meeting notes?"
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(state == .recording ? Color.appDanger : Color.appAccent)
            .frame(width: 10, height: 10)
            .opacity(state == .recording && pulsing ? 0.45 : 1)
            .animation(state == .recording ? AppMotion.recordingPulse : nil, value: pulsing)
    }

    @ViewBuilder
    private var actions: some View {
        if state == .recording {
            HStack(spacing: AppSpacing.xs) {
                Button("Pause", action: onPause)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Stop", action: onStop)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appDanger)
                    .controlSize(.small)
            }
        } else if state == .paused {
            HStack(spacing: AppSpacing.xs) {
                Button("Resume", action: onRecord)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                    .controlSize(.small)
                Button("Stop", action: onStop)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        } else {
            HStack(spacing: AppSpacing.xs) {
                Button("Record", action: onRecord)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                    .controlSize(.small)
                if state.allowsDismiss {
                    Button("Close", action: onDismiss)
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
            }
        }
    }
}
