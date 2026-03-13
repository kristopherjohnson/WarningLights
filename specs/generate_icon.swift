#!/usr/bin/env swift
//
// Generates app icon PNGs for WarningLights.
// Run: swift specs/generate_icon.swift
//
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Rounded-corner triangle path centered in a square of given size
func trianglePath(in size: CGFloat, cornerRadius: CGFloat) -> CGPath {
    let topY = size * 0.15
    let bottomY = size * 0.82
    let centerX = size / 2.0

    let height = bottomY - topY
    let halfBase = height / sqrt(3.0) * 1.1  // slightly wider than equilateral

    let top = CGPoint(x: centerX, y: topY)
    let bottomLeft = CGPoint(x: centerX - halfBase, y: bottomY)
    let bottomRight = CGPoint(x: centerX + halfBase, y: bottomY)

    let path = CGMutablePath()

    let startPoint = CGPoint(
        x: (bottomLeft.x + bottomRight.x) / 2,
        y: bottomLeft.y
    )
    path.move(to: startPoint)

    path.addArc(tangent1End: bottomRight, tangent2End: top, radius: cornerRadius)
    path.addArc(tangent1End: top, tangent2End: bottomLeft, radius: cornerRadius)
    path.addArc(tangent1End: bottomLeft, tangent2End: bottomRight, radius: cornerRadius)

    path.closeSubpath()
    return path
}

func generateIcon(size: Int, outputPath: String) {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create context for size \(size)")
        return
    }

    // Dark brownish background with rounded-rect (macOS icon shape)
    let bgColor = CGColor(red: 0.231, green: 0.165, blue: 0.102, alpha: 1.0)  // ~#3B2A1A
    ctx.setFillColor(bgColor)

    let iconRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.185
    let bgPath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.fillPath()

    // Orange triangle (solid, rounded corners)
    let orangeColor = CGColor(red: 1.0, green: 0.549, blue: 0.0, alpha: 1.0)  // #FF8C00
    ctx.setFillColor(orangeColor)

    // CoreGraphics Y-up → flip for top-down drawing
    ctx.saveGState()
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    let triCornerRadius = s * 0.06
    let tri = trianglePath(in: s, cornerRadius: triCornerRadius)
    ctx.addPath(tri)
    ctx.fillPath()

    ctx.restoreGState()

    guard let image = ctx.makeImage() else {
        print("Failed to make image for size \(size)")
        return
    }

    let url = URL(fileURLWithPath: outputPath)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Failed to create image destination for \(outputPath)")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Generated \(outputPath)")
}

// Resolve output directory relative to script location
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let projectDir = URL(fileURLWithPath: scriptDir).deletingLastPathComponent().path
let outputDir = "\(projectDir)/WarningLights/Assets.xcassets/AppIcon.appiconset"
let sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    generateIcon(size: size, outputPath: "\(outputDir)/icon_\(size)x\(size).png")
}

print("Done!")
