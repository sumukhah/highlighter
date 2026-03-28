import AppKit

@MainActor
final class DrawingOverlayWindow: NSWindow {
    private(set) var drawingView: DrawingOverlayView!

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        installDrawingView(frame: CGRect(origin: .zero, size: contentRect.size), preferencesStore: .shared)
        configureWindow()
    }

    convenience init(screen: NSScreen, preferencesStore: AppPreferencesStore) {
        self.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        installDrawingView(frame: CGRect(origin: .zero, size: screen.frame.size), preferencesStore: preferencesStore)
        setFrame(screen.frame, display: false)
        collectionBehavior.insert(.moveToActiveSpace)
        contentView = drawingView
    }

    private func installDrawingView(frame: CGRect, preferencesStore: AppPreferencesStore) {
        drawingView = DrawingOverlayView(
            frame: frame,
            preferencesStore: preferencesStore
        )
    }

    private func configureWindow() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        contentView = drawingView
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
