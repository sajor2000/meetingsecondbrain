import SwiftUI

public struct TaskRowView: View {
    private let task: MeetingTask
    private let compact: Bool

    public init(task: MeetingTask, compact: Bool = false) {
        self.task = task
        self.compact = compact
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: task.status == .done ? "checkmark.square.fill" : "square")
                .foregroundStyle(task.status == .done ? Color.appAccent : Color.appAccent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(task.title)
                    .font(AppFont.body)
                    .strikethrough(task.status == .done)
                    .foregroundStyle(task.status == .done ? Color.appMutedText : Color.primary)
                    .lineLimit(compact ? 2 : nil)
                HStack(spacing: AppSpacing.xs) {
                    if let sourceMeetingTitle = task.sourceMeetingTitle {
                        Text(sourceMeetingTitle)
                    }
                    if let timestamp = task.sourceTimestamp {
                        Text("↗ \(Self.timestampFormatter.string(from: timestamp) ?? "00:00")")
                            .foregroundStyle(Color.appAccent)
                    }
                }
                .font(AppFont.metadata)
                .foregroundStyle(Color.appMutedText)
            }

            Spacer(minLength: AppSpacing.sm)
            Text(task.priority.rawValue.capitalized)
                .font(AppFont.tinyLabel)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .foregroundStyle(task.priority == .high ? Color.appAccent : Color.appMutedText)
                .overlay(
                    Capsule()
                        .stroke(Color.appHairline, lineWidth: 1)
                )
        }
        .padding(.vertical, compact ? AppSpacing.xs : AppSpacing.sm)
    }

    private static let timestampFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}
