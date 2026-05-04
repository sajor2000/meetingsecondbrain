import SwiftUI

public struct TimestampLink: View {
    private let label: String
    private let action: () -> Void

    public init(label: String, action: @escaping () -> Void = {}) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.secondary)
                .foregroundStyle(Color.appAccent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open audio at \(label)")
    }
}
