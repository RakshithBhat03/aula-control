#!/usr/bin/env swift
import AppKit

// Renders the AULA Control app icon at 1024×1024.
let output = CommandLine.arguments.dropFirst().first ?? "build/AppIcon-1024.png"
let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let context = NSGraphicsContext.current!.cgContext
context.setAllowsAntialiasing(true)

// Background: dark rounded square.
let bgRect = NSRect(x: 40, y: 40, width: size - 80, height: size - 80)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: 200, yRadius: 200)
let bgGradient = NSGradient(colors: [
    NSColor(srgbRed: 0.11, green: 0.13, blue: 0.16, alpha: 1),
    NSColor(srgbRed: 0.035, green: 0.04, blue: 0.055, alpha: 1)
])!
bgGradient.draw(in: bg, angle: -60)

// Subtle amber glow behind the key.
context.saveGState()
let glow = NSBezierPath(ovalIn: NSRect(x: 190, y: 190, width: 644, height: 644))
NSColor(srgbRed: 0.96, green: 0.70, blue: 0.26, alpha: 0.18).setFill()
glow.fill()
context.restoreGState()

// Two dark keycaps behind.
func drawKeycap(_ rect: NSRect, radius: CGFloat, top: NSColor, bottom: NSColor, border: NSColor, shadow: Bool = true) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    if shadow {
        let shadowObj = NSShadow()
        shadowObj.shadowBlurRadius = 34
        shadowObj.shadowOffset = NSSize(width: 0, height: -16)
        shadowObj.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadowObj.set()
    }
    NSGradient(colors: [top, bottom])!.draw(in: path, angle: -90)
    NSGraphicsContext.current?.saveGraphicsState()
    border.setStroke()
    path.lineWidth = 6
    path.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
}

drawKeycap(NSRect(x: 250, y: 330, width: 380, height: 340), radius: 60,
           top: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.22, alpha: 1),
           bottom: NSColor(srgbRed: 0.09, green: 0.10, blue: 0.13, alpha: 1),
           border: NSColor.white.withAlphaComponent(0.08))

drawKeycap(NSRect(x: 360, y: 250, width: 380, height: 340), radius: 60,
           top: NSColor(srgbRed: 0.18, green: 0.20, blue: 0.24, alpha: 1),
           bottom: NSColor(srgbRed: 0.10, green: 0.11, blue: 0.14, alpha: 1),
           border: NSColor.white.withAlphaComponent(0.09))

// Amber keycap front.
let keyRect = NSRect(x: 300, y: 420, width: 424, height: 380)
let keyPath = NSBezierPath(roundedRect: keyRect, xRadius: 66, yRadius: 66)
let shadow = NSShadow()
shadow.shadowBlurRadius = 42
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowColor = NSColor(srgbRed: 0.95, green: 0.6, blue: 0.1, alpha: 0.5)
shadow.set()
NSGradient(colors: [
    NSColor(srgbRed: 1.0, green: 0.78, blue: 0.36, alpha: 1),
    NSColor(srgbRed: 0.93, green: 0.58, blue: 0.12, alpha: 1)
])!.draw(in: keyPath, angle: -90)

// Keycap top highlight.
NSGraphicsContext.current?.saveGraphicsState()
keyPath.addClip()
let highlight = NSBezierPath(roundedRect: NSRect(x: 324, y: 690, width: 376, height: 86), xRadius: 40, yRadius: 40)
NSColor.white.withAlphaComponent(0.28).setFill()
highlight.fill()
NSGraphicsContext.current?.restoreGraphicsState()

// "A" monogram.
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let font = NSFont.systemFont(ofSize: 230, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(srgbRed: 0.10, green: 0.075, blue: 0.03, alpha: 1),
    .paragraphStyle: paragraph,
]
let monogram = NSAttributedString(string: "A", attributes: attributes)
let textSize = monogram.size()
monogram.draw(in: NSRect(x: keyRect.midX - textSize.width / 2,
                          y: keyRect.midY - textSize.height / 2 - 8,
                          width: textSize.width, height: textSize.height))

// Small three-key hint under the main key.
for index in 0..<3 {
    let rect = NSRect(x: 300 + CGFloat(index) * 152, y: 260, width: 120, height: 92)
    drawKeycap(rect, radius: 24,
               top: NSColor(srgbRed: 0.22, green: 0.25, blue: 0.30, alpha: 1),
               bottom: NSColor(srgbRed: 0.12, green: 0.14, blue: 0.17, alpha: 1),
               border: NSColor.white.withAlphaComponent(0.10),
               shadow: false)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}
try png.write(to: URL(fileURLWithPath: output))
print(output)
