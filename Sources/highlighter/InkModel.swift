import CoreGraphics
import Foundation

struct InkSegment: Equatable {
    let start: CGPoint
    let end: CGPoint
    let createdAt: TimeInterval
    let startHue: CGFloat
    let endHue: CGFloat

    func opacity(at time: TimeInterval, fadeDuration: TimeInterval) -> CGFloat {
        guard fadeDuration > 0 else { return 0 }
        let progress = ((time - createdAt) / fadeDuration).clamped(to: 0...1)
        let remaining = 1 - progress
        return remaining * remaining
    }
}

struct EphemeralInkModel {
    private(set) var segments: [InkSegment] = []
    private var lastPoint: CGPoint?
    private var hueCursor: CGFloat = 0

    var isEmpty: Bool {
        segments.isEmpty
    }

    mutating func beginStroke(at point: CGPoint) {
        lastPoint = point
    }

    @discardableResult
    mutating func appendPoint(_ point: CGPoint, at time: TimeInterval) -> Bool {
        guard let lastPoint else {
            beginStroke(at: point)
            return false
        }

        let dx = point.x - lastPoint.x
        let dy = point.y - lastPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 0.35 else {
            self.lastPoint = point
            return false
        }

        let startHue = hueCursor.normalizedHue
        let hueIncrement = max(0.01, min(distance / 220, 0.08))
        hueCursor = (hueCursor + hueIncrement).normalizedHue

        segments.append(
            InkSegment(
                start: lastPoint,
                end: point,
                createdAt: time,
                startHue: startHue,
                endHue: hueCursor
            )
        )

        self.lastPoint = point
        return true
    }

    mutating func addTap(at point: CGPoint, at time: TimeInterval) {
        beginStroke(at: point)
        _ = appendPoint(CGPoint(x: point.x + 0.2, y: point.y + 0.2), at: time)
        endStroke()
    }

    mutating func endStroke() {
        lastPoint = nil
    }

    mutating func pruneExpiredSegments(at time: TimeInterval, fadeDuration: TimeInterval) {
        segments.removeAll { time - $0.createdAt >= fadeDuration }
    }

    func visibleSegments(at time: TimeInterval, fadeDuration: TimeInterval) -> [InkSegment] {
        segments.filter { time - $0.createdAt < fadeDuration }
    }

    mutating func clear() {
        segments.removeAll()
        lastPoint = nil
    }
}

private extension BinaryFloatingPoint {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

private extension CGFloat {
    var normalizedHue: CGFloat {
        let remainder = truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
    }
}
