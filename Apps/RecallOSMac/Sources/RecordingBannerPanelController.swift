import AppKit
import RecallOSCore
import SwiftUI

@MainActor
final class RecordingBannerPanelController: ObservableObject {
    private var panel: NSPanel?

    func show(
        state: RecordingBannerState,
        title: String = "AI CoE weekly",
        subtitle: String = "Parakeet on Neural Engine",
        elapsed: String = "00:00",
        onRecord: @escaping () -> Void = {},
        onPause: @escaping () -> Void = {},
        onResume: @escaping () -> Void = {},
        onStop: @escaping () -> Void = {}
    ) {
        let view = RecordingBannerView(
            state: state,
            title: title,
            subtitle: subtitle,
            elapsed: elapsed,
            onRecord: onRecord,
            onPause: onPause,
            onResume: onResume,
            onStop: onStop,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        let hostingView = NSHostingView(rootView: view)
        let size = NSSize(width: 360, height: 66)

        let panel = panel ?? NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.setFrame(frameForTopRight(size: size), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    private func frameForTopRight(size: NSSize) -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: screen.maxX - size.width - 16,
            y: screen.maxY - size.height - 16
        )
        return NSRect(origin: origin, size: size)
    }
}
