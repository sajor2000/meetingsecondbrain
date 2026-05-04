import SwiftUI

public struct SearchResultCard: View {
    private let result: SearchResult
    private let onOpenMeeting: ((UUID) -> Void)?

    public init(result: SearchResult, onOpenMeeting: ((UUID) -> Void)? = nil) {
        self.result = result
        self.onOpenMeeting = onOpenMeeting
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(result.source)
                .font(AppFont.metadata)
                .foregroundStyle(Color.appMutedText)
            Text(result.title)
                .font(AppFont.sectionHeader)
                .foregroundStyle(.primary)
            Text(result.snippet)
                .font(AppFont.secondary)
                .foregroundStyle(Color.appAISuggestionText)
                .lineLimit(3)
            Button("Show full meeting") {
                if let sourceMeetingID = result.sourceMeetingID {
                    onOpenMeeting?(sourceMeetingID)
                }
            }
                .font(AppFont.secondary)
                .foregroundStyle(Color.appAccent)
                .buttonStyle(.plain)
                .disabled(result.sourceMeetingID == nil)
        }
        .padding(AppSpacing.md)
        .hairlinePanel()
    }
}
