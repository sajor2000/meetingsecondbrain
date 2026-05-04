import SwiftUI

public struct HybridNoteBlockView: View {
    private let block: NoteBlock
    private let onTimestampSelected: (TimeInterval) -> Void

    public init(block: NoteBlock, onTimestampSelected: @escaping (TimeInterval) -> Void = { _ in }) {
        self.block = block
        self.onTimestampSelected = onTimestampSelected
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(block.title)
                .font(AppFont.sectionHeader)
                .foregroundStyle(.primary)

            Text(block.body)
                .font(AppFont.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)

            ForEach(block.aiAdditions) { addition in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Rectangle()
                        .fill(Color.appHairline)
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(addition.text)
                            .font(AppFont.secondary)
                            .foregroundStyle(Color.appAISuggestionText)
                            .lineSpacing(4)
                        TimestampLink(label: addition.timestampLabel) {
                            onTimestampSelected(addition.sourceTimestamp)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }
}
