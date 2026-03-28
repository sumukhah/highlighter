import AppKit
import Carbon
import CoreGraphics
import Testing
@testable import highlighter

@Test
func inkSegmentsFadeQuadratically() {
    let segment = InkSegment(
        start: .zero,
        end: CGPoint(x: 10, y: 10),
        createdAt: 5,
        startHue: 0,
        endHue: 0.1
    )

    #expect(segment.opacity(at: 5, fadeDuration: 2) == 1)
    #expect(segment.opacity(at: 6, fadeDuration: 2) == 0.25)
    #expect(segment.opacity(at: 7, fadeDuration: 2) == 0)
}

@Test
func expiredSegmentsArePrunedIndependently() {
    var model = EphemeralInkModel()

    model.beginStroke(at: .zero)
    _ = model.appendPoint(CGPoint(x: 20, y: 0), at: 10)
    _ = model.appendPoint(CGPoint(x: 40, y: 0), at: 11)
    model.endStroke()

    model.pruneExpiredSegments(at: 12.5, fadeDuration: 2)

    #expect(model.segments.count == 1)
    #expect(model.segments.first?.createdAt == 11)
}

@Test
func hotKeyDisplayStringUsesMacSymbols() {
    let hotKey = HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_H), modifiers: [.command, .shift, .option])

    #expect(hotKey.displayString == "⌘⇧⌥H")
}
