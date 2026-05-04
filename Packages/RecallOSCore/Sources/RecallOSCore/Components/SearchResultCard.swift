import SwiftUI

public struct SearchResultCard: View {
    private let result: SearchResult

    public init(result: SearchResult) {
        self.result = result
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
            Button("Show full meeting") {}
                .font(AppFont.secondary)
                .foregroundStyle(Color.appAccent)
                .buttonStyle(.plain)
        }
        .padding(AppSpacing.md)
        .hairlinePanel()
    }
}
