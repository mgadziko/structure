#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let iconset = root
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("StructureIcon.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let iconFiles: [(name: String, size: Int)] = [
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

for iconFile in iconFiles {
    let image = NSImage(size: NSSize(width: iconFile.size, height: iconFile.size))
    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: iconFile.size, height: iconFile.size)
    NSColor.white.setFill()
    bounds.fill()

    let scale = CGFloat(iconFile.size) / 1024
    let circleDiameter = 520 * scale
    let strokeWidth = max(1.25, 18 * scale)
    let circles: [(color: NSColor, center: CGPoint)] = [
        (NSColor(calibratedRed: 0.93, green: 0.05, blue: 0.08, alpha: 0.62), CGPoint(x: 392 * scale, y: 608 * scale)),
        (NSColor(calibratedRed: 0.98, green: 0.84, blue: 0.06, alpha: 0.62), CGPoint(x: 632 * scale, y: 608 * scale)),
        (NSColor(calibratedRed: 0.05, green: 0.27, blue: 0.92, alpha: 0.62), CGPoint(x: 512 * scale, y: 392 * scale))
    ]

    for circle in circles {
        let rect = NSRect(
            x: circle.center.x - circleDiameter / 2,
            y: circle.center.y - circleDiameter / 2,
            width: circleDiameter,
            height: circleDiameter
        )
        let path = NSBezierPath(ovalIn: rect)
        circle.color.setFill()
        path.fill()
    }

    for circle in circles {
        let rect = NSRect(
            x: circle.center.x - circleDiameter / 2,
            y: circle.center.y - circleDiameter / 2,
            width: circleDiameter,
            height: circleDiameter
        )
        let path = NSBezierPath(ovalIn: rect)
        NSColor.white.withAlphaComponent(0.88).setStroke()
        path.lineWidth = strokeWidth
        path.stroke()
    }

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(iconFile.name)")
    }

    try png.write(to: iconset.appendingPathComponent(iconFile.name))
}
