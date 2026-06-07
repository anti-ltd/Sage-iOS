#!/usr/bin/env swift
//
// RenderAppIcon.swift — renders the Sage iOS app icon into the asset catalog.
//
// Run via `make icon`.
//
import AppKit

let size = 1024.0
let outDir = "Resources/Assets.xcassets/AppIcon.appiconset"
let outPath = "\(outDir)/icon-1024.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("no graphics context")
}

// Deep indigo → soft violet diagonal gradient — sage/wisdom palette.
let colors = [
    NSColor(srgbRed: 0x1A / 255.0, green: 0x0A / 255.0, blue: 0x3E / 255.0, alpha: 1).cgColor,
    NSColor(srgbRed: 0x5B / 255.0, green: 0x2D / 255.0, blue: 0xBE / 255.0, alpha: 1).cgColor,
]
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: colors as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: [])

// Centred white sparkles glyph at 50% of the canvas.
let glyphPt = size * 0.50
let config = NSImage.SymbolConfiguration(pointSize: glyphPt, weight: .medium)
if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor.white.set()
    let r = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let gs = tinted.size
    let origin = NSPoint(x: (size - gs.width) / 2, y: (size - gs.height) / 2)
    tinted.draw(
        at: origin, from: NSRect(origin: .zero, size: gs),
        operation: .sourceOver, fraction: 1.0)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to encode PNG")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("→ \(outPath)")
