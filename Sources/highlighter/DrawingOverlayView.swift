import AppKit
import QuartzCore

@MainActor
final class DrawingOverlayView: NSView {
    var onSessionEmpty: (() -> Void)?

    private let preferencesStore: AppPreferencesStore
    private var inkModel = EphemeralInkModel()
    private var displayTimer: Timer?
    private var isDraggingStroke = false
    private var currentStrokeHasMovement = false
    private var hasProducedVisibleInk = false

    init(frame frameRect: NSRect, preferencesStore: AppPreferencesStore) {
        self.preferencesStore = preferencesStore
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        window?.initialFirstResponder = self
        window?.makeFirstResponder(self)
        discardCursorRects()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: PenCursor.shared)
    }

    override func mouseDown(with event: NSEvent) {
        window?.invalidateCursorRects(for: self)

        ensureDisplayTimerRunning()
        isDraggingStroke = true
        currentStrokeHasMovement = false
        inkModel.beginStroke(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let timestamp = CACurrentMediaTime()
        let appendedSegment = inkModel.appendPoint(point, at: timestamp)
        currentStrokeHasMovement = appendedSegment || currentStrokeHasMovement
        hasProducedVisibleInk = hasProducedVisibleInk || appendedSegment
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            inkModel.endStroke()
            isDraggingStroke = false
            currentStrokeHasMovement = false
        }

        guard !currentStrokeHasMovement else {
            needsDisplay = true
            return
        }

        ensureDisplayTimerRunning()
        inkModel.addTap(at: convert(event.locationInWindow, from: nil), at: CACurrentMediaTime())
        hasProducedVisibleInk = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let preferences = preferencesStore.preferences
        let now = CACurrentMediaTime()

        context.clear(bounds)
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        for segment in inkModel.visibleSegments(at: now, fadeDuration: preferences.fadeDuration) {
            let opacity = segment.opacity(at: now, fadeDuration: preferences.fadeDuration)
            guard opacity > 0.001 else { continue }

            drawGlow(for: segment, opacity: opacity, width: preferences.strokeWidth, in: context)
            drawSegment(segment, opacity: opacity, width: preferences.strokeWidth, in: context)
        }
    }

    func clearAll() {
        inkModel.clear()
        hasProducedVisibleInk = false
        needsDisplay = true
    }

    func prepareForDismissal() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func ensureDisplayTimerRunning() {
        guard displayTimer == nil else { return }

        displayTimer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let fadeDuration = preferencesStore.preferences.fadeDuration
        inkModel.pruneExpiredSegments(at: now, fadeDuration: fadeDuration)

        if hasProducedVisibleInk, inkModel.isEmpty, !isDraggingStroke {
            displayTimer?.invalidate()
            displayTimer = nil
            onSessionEmpty?()
            return
        }

        needsDisplay = true
    }

    private func drawGlow(for segment: InkSegment, opacity: CGFloat, width: CGFloat, in context: CGContext) {
        let glowWidth = width * 1.85
        let glowStartColor = NSColor(
            calibratedHue: segment.startHue,
            saturation: 0.7,
            brightness: 1,
            alpha: opacity * 0.18
        )
        let glowEndColor = NSColor(
            calibratedHue: segment.endHue,
            saturation: 0.8,
            brightness: 1,
            alpha: opacity * 0.08
        )

        strokeGradient(
            from: segment.start,
            to: segment.end,
            startColor: glowStartColor,
            endColor: glowEndColor,
            width: glowWidth,
            in: context
        )
    }

    private func drawSegment(_ segment: InkSegment, opacity: CGFloat, width: CGFloat, in context: CGContext) {
        let startColor = NSColor(
            calibratedHue: segment.startHue,
            saturation: 0.75,
            brightness: 1,
            alpha: opacity
        )
        let endColor = NSColor(
            calibratedHue: segment.endHue,
            saturation: 0.92,
            brightness: 1,
            alpha: opacity
        )

        strokeGradient(
            from: segment.start,
            to: segment.end,
            startColor: startColor,
            endColor: endColor,
            width: width,
            in: context
        )
    }

    private func strokeGradient(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        startColor: NSColor,
        endColor: NSColor,
        width: CGFloat,
        in context: CGContext
    ) {
        let actualEndPoint: CGPoint
        if hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y) < 0.01 {
            actualEndPoint = CGPoint(x: endPoint.x + 0.4, y: endPoint.y + 0.4)
        } else {
            actualEndPoint = endPoint
        }

        let colors = [startColor.cgColor, endColor.cgColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }

        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(width)
        context.beginPath()
        context.move(to: startPoint)
        context.addLine(to: actualEndPoint)
        context.replacePathWithStrokedPath()
        context.clip()
        context.drawLinearGradient(gradient, start: startPoint, end: actualEndPoint, options: [])
        context.restoreGState()
    }
}

private enum PenCursor {
    @MainActor
    static let shared: NSCursor = {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()

        let outerRect = NSRect(x: 4, y: 4, width: 16, height: 16)
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let outer = NSBezierPath(ovalIn: outerRect)
        outer.lineWidth = 2
        outer.stroke()

        NSColor.systemPink.setFill()
        NSBezierPath(ovalIn: NSRect(x: 10, y: 10, width: 4, height: 4)).fill()

        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }()
}
