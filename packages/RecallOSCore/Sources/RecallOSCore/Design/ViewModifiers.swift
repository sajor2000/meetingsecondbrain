import SwiftUI

public struct HairlinePanel: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(Color.appBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.panel, style: .continuous)
                    .stroke(Color.appHairline, lineWidth: 1)
            )
    }
}

public extension View {
    func hairlinePanel() -> some View {
        modifier(HairlinePanel())
    }
}

public struct CalmSummaryBlock: View {
    private let title: String
    private let text: String

    public init(title: String = "Summary", text: String) {
        self.title = title
        self.text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(AppFont.tinyLabel)
                .foregroundStyle(Color.appMutedText)
            Text(text)
                .font(AppFont.body)
                .foregroundStyle(Color.appAISuggestionText)
                .lineSpacing(4)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSecondarySurface)
    }
}
