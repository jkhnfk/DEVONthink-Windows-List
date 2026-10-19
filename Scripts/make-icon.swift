#!/usr/bin/env swift
//
// Draws the app icon (a rounded, gradient tile with a sidebar glyph) and writes
// every size needed for an .iconset folder.
//
// Usage: swift Scripts/make-icon.swift <output-iconset-directory>
//

import AppKit

let baseSize: CGFloat = 1024
let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/AppIcon.iconset"

func makeBaseImage() -> NSImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(baseSize),
        pixelsHigh: Int(baseSize),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let fullRect = NSRect(x: 0, y: 0, width: baseSize, height: baseSize)
    NSColor.clear.setFill()
    fullRect.fill()

    // Apple's icon grid: the rounded square occupies ~82% of the canvas.
    let inset = baseSize * 0.09
    let tile = fullRect.insetBy(dx: inset, dy: inset)
    let radius = tile.width * 0.2237
    let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.29, green: 0.42, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.47, green: 0.24, blue: 0.85, alpha: 1)
    ])!
    gradient.draw(in: path, angle: -90)

    // Subtle top highlight.
    NSColor.white.withAlphaComponent(0.12).setFill()
    NSBezierPath(
        roundedRect: NSRect(x: tile.minX + 40, y: tile.midY, width: tile.width - 80, height: tile.height / 2 - 60),
        xRadius: radius * 0.8,
        yRadius: radius * 0.8
    ).fill()

    // Sidebar panel on the right.
    let panelWidth = tile.width * 0.34
    let panelRect = NSRect(
        x: tile.maxX - panelWidth - tile.width * 0.08,
        y: tile.minY + tile.height * 0.18,
        width: panelWidth,
        height: tile.height * 0.64
    )
    NSColor.white.withAlphaComponent(0.92).setFill()
    NSBezierPath(roundedRect: panelRect, xRadius: panelWidth * 0.14, yRadius: panelWidth * 0.14).fill()

    // Three "window" rows inside the panel.
    let rowHeight = panelRect.height * 0.09
    let rowInset = panelRect.width * 0.16
    for index in 0..<3 {
        let rowRect = NSRect(
            x: panelRect.minX + rowInset,
            y: panelRect.maxY - rowInset - rowHeight - CGFloat(index) * rowHeight * 1.9,
            width: panelRect.width - rowInset * 2,
            height: rowHeight
        )
        NSColor(srgbRed: 0.35, green: 0.36, blue: 0.85, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: rowRect, xRadius: rowHeight / 2, yRadius: rowHeight / 2).fill()
    }

    // Three list rows on the left.
    let listWidth = tile.width * 0.36
    let listHeight = tile.height * 0.075
    for index in 0..<3 {
        let rowRect = NSRect(
            x: tile.minX + tile.width * 0.09,
            y: panelRect.maxY - CGFloat(index) * listHeight * 1.85 - listHeight,
            width: listWidth - CGFloat(index) * listWidth * 0.14,
            height: listHeight
        )
        NSColor.white.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: rowRect, xRadius: listHeight / 2, yRadius: listHeight / 2).fill()
    }

    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: baseSize, height: baseSize))
    image.addRepresentation(rep)
    return image
}

func writePNG(of image: NSImage, pixels: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make-icon", code: 1)
    }
    try data.write(to: url)
}

let baseImage = makeBaseImage()
let directory = URL(fileURLWithPath: outputDirectory)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    try writePNG(of: baseImage, pixels: variant.pixels, to: directory.appendingPathComponent(variant.name))
}

print("Wrote \(variants.count) icon images to \(directory.path)")
