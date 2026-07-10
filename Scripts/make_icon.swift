#!/usr/bin/env swift
// Generates AppIcon.icns: a glassy gradient squircle with a Windows-11-style
// snap layout motif. Usage: swift Scripts/make_icon.swift <output-dir>
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist"
let iconsetPath = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let s = size
    // macOS icon grid: content squircle inset ~10% on each side.
    let inset = s * 0.10
    let bounds = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = bounds.width * 0.225
    let squircle = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

    // Deep blue → violet vertical gradient.
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.36, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.42, green: 0.20, blue: 0.92, alpha: 1),
    ])!
    gradient.draw(in: squircle, angle: -90)

    // Soft top sheen for the glassy feel.
    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    let sheen = NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.28),
        NSColor(calibratedWhite: 1, alpha: 0.0),
    ])!
    sheen.draw(in: NSRect(x: bounds.minX, y: bounds.midY, width: bounds.width, height: bounds.height / 2),
               angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Snap layout motif: wide-left cell + two stacked cells.
    let pad = bounds.width * 0.16
    let area = bounds.insetBy(dx: pad, dy: pad)
    let gap = bounds.width * 0.045
    let cellRadius = bounds.width * 0.055

    func cell(_ rect: NSRect, alpha: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: cellRadius, yRadius: cellRadius)
        NSColor(calibratedWhite: 1, alpha: alpha).setFill()
        path.fill()
    }

    let leftWidth = area.width * 0.58 - gap / 2
    let rightWidth = area.width - leftWidth - gap
    cell(NSRect(x: area.minX, y: area.minY, width: leftWidth, height: area.height), alpha: 0.95)
    let halfHeight = (area.height - gap) / 2
    cell(NSRect(x: area.minX + leftWidth + gap, y: area.minY + halfHeight + gap,
                width: rightWidth, height: halfHeight), alpha: 0.6)
    cell(NSRect(x: area.minX + leftWidth + gap, y: area.minY,
                width: rightWidth, height: halfHeight), alpha: 0.6)

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, pixels: Int, name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
               from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}

for size in [16, 32, 128, 256, 512] {
    let image = draw(size: CGFloat(size * 2))
    savePNG(image, pixels: size, name: "icon_\(size)x\(size)")
    savePNG(image, pixels: size * 2, name: "icon_\(size)x\(size)@2x")
}

let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconsetPath, "-o", "\(outputDir)/AppIcon.icns"]
task.launch()
task.waitUntilExit()
exit(task.terminationStatus)
