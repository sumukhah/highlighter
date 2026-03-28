#!/usr/bin/env swift

import AppKit

struct IconSpec {
    let fileName: String
    let size: CGFloat
}

let iconSpecs: [IconSpec] = [
    .init(fileName: "icon_16x16.png", size: 16),
    .init(fileName: "icon_16x16@2x.png", size: 32),
    .init(fileName: "icon_32x32.png", size: 32),
    .init(fileName: "icon_32x32@2x.png", size: 64),
    .init(fileName: "icon_128x128.png", size: 128),
    .init(fileName: "icon_128x128@2x.png", size: 256),
    .init(fileName: "icon_256x256.png", size: 256),
    .init(fileName: "icon_256x256@2x.png", size: 512),
    .init(fileName: "icon_512x512.png", size: 512),
    .init(fileName: "icon_512x512@2x.png", size: 1024)
]

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <output-iconset-dir>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fileManager = FileManager.default

try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

for spec in iconSpecs {
    let image = NSImage(size: NSSize(width: spec.size, height: spec.size))
    image.lockFocus()
    drawIcon(in: NSRect(origin: .zero, size: image.size))
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("Failed to render \(spec.fileName)\n", stderr)
        exit(1)
    }

    try png.write(to: outputURL.appendingPathComponent(spec.fileName))
}

private func drawIcon(in rect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    let inset = rect.width * 0.06
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = rect.width * 0.23

    let backgroundPath = NSBezierPath(roundedRect: cardRect, xRadius: cornerRadius, yRadius: cornerRadius)
    let backgroundGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.18, alpha: 1)
    ])!
    backgroundGradient.draw(in: backgroundPath, angle: 90)

    NSColor.white.withAlphaComponent(0.08).setStroke()
    backgroundPath.lineWidth = max(1, rect.width * 0.014)
    backgroundPath.stroke()

    drawGlowScribble(in: cardRect, context: context)
    drawAccentSpark(in: cardRect)
}

private func drawGlowScribble(in rect: NSRect, context: CGContext) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.34))
    path.curve(
        to: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.70),
        controlPoint1: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.14),
        controlPoint2: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.92)
    )
    path.curve(
        to: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.18),
        controlPoint1: CGPoint(x: rect.minX + rect.width * 0.92, y: rect.minY + rect.height * 0.58),
        controlPoint2: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.24)
    )
    path.lineCapStyle = .round
    path.lineJoinStyle = .round

    context.saveGState()
    context.setShadow(
        offset: .zero,
        blur: rect.width * 0.07,
        color: NSColor.systemPink.withAlphaComponent(0.30).cgColor
    )
    path.lineWidth = rect.width * 0.18
    NSColor.white.withAlphaComponent(0.12).setStroke()
    path.stroke()
    context.restoreGState()

    let colors = [
        NSColor(calibratedRed: 0.08, green: 0.94, blue: 0.98, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.31, green: 0.71, blue: 1.00, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.95, green: 0.32, blue: 0.81, alpha: 1).cgColor,
        NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.20, alpha: 1).cgColor
    ] as CFArray

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 0.35, 0.72, 1]
    )!

    context.saveGState()
    context.addPath(path.cgPath)
    context.setLineWidth(rect.width * 0.13)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.20),
        end: CGPoint(x: rect.minX + rect.width * 0.85, y: rect.minY + rect.height * 0.80),
        options: []
    )
    context.restoreGState()
}

private func drawAccentSpark(in rect: NSRect) {
    let sparkRect = NSRect(
        x: rect.minX + rect.width * 0.72,
        y: rect.minY + rect.height * 0.70,
        width: rect.width * 0.10,
        height: rect.height * 0.10
    )

    let sparkPath = NSBezierPath(ovalIn: sparkRect)
    NSColor.white.withAlphaComponent(0.92).setFill()
    sparkPath.fill()

    let haloPath = NSBezierPath(ovalIn: sparkRect.insetBy(dx: -rect.width * 0.025, dy: -rect.height * 0.025))
    NSColor.systemYellow.withAlphaComponent(0.22).setFill()
    haloPath.fill()
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}
