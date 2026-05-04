import SwiftUI

public struct SearchResultCard: View {
    private let result: SearchResult
    private let onShowFullMeeting: (UUID) -> Void

    public init(result: SearchResult, onShowFullMeeting: @escaping (UUID) -> Void = { _ in }) {
        self.result = result
        self.onShowFullMeeting = onShowFullMeeting
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
            if let sourceMeetingID = result.sourceMeetingID {
                Button("Show full meeting") {
                    onShowFullMeeting(sourceMeetingID)
                }
                .font(AppFont.secondary)
                .foregroundStyle(Color.appAccent)
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .hairlinePanel()
    }
}
