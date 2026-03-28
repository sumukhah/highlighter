import AppKit

@MainActor
final class OverlayController {
    var onStateChange: (() -> Void)?

    private let preferencesStore: AppPreferencesStore
    private var overlayWindow: DrawingOverlayWindow?
    private weak var previousFrontmostApplication: NSRunningApplication?

    init(preferencesStore: AppPreferencesStore) {
        self.preferencesStore = preferencesStore
    }

    var isPresentingOverlay: Bool {
        overlayWindow != nil
    }

    func toggleDrawingMode() {
        if isPresentingOverlay {
            clearAndExit()
        } else {
            startDrawing()
        }
    }

    func clearAndExit() {
        overlayWindow?.drawingView.clearAll()
        tearDownOverlay(restorePreviousApplication: true)
    }

    private func startDrawing() {
        guard overlayWindow == nil else { return }
        guard let targetScreen = NSScreen.activeScreen else { return }

        previousFrontmostApplication = NSWorkspace.shared.frontmostApplication

        let window = DrawingOverlayWindow(screen: targetScreen, preferencesStore: preferencesStore)
        window.drawingView.onSessionEmpty = { [weak self] in
            self?.tearDownOverlay(restorePreviousApplication: true)
        }

        overlayWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        onStateChange?()
    }

    private func tearDownOverlay(restorePreviousApplication: Bool) {
        guard let overlayWindow else { return }

        overlayWindow.drawingView.prepareForDismissal()
        overlayWindow.orderOut(nil)
        self.overlayWindow = nil
        onStateChange?()

        guard restorePreviousApplication else { return }
        guard let previousFrontmostApplication else { return }
        guard previousFrontmostApplication != NSRunningApplication.current else { return }
        previousFrontmostApplication.activate(options: [.activateIgnoringOtherApps])
    }
}

private extension NSScreen {
    static var activeScreen: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first
    }
}
