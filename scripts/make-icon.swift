import AppKit

let destination = CommandLine.arguments[1]
for size in [16, 32, 64, 128, 256, 512, 1024] {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  let context = NSGraphicsContext(bitmapImageRep: bitmap)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  let s = CGFloat(size)
  let rect = NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
  NSColor(calibratedRed: 0.06, green: 0.15, blue: 0.20, alpha: 1).setFill()
  NSBezierPath(roundedRect: rect, xRadius: s * 0.20, yRadius: s * 0.20).fill()
  let points = (0..<3).map { i -> NSPoint in
    let a = Double(i) * 2 * .pi / 3 + .pi / 2
    return NSPoint(x: s * 0.5 + s * 0.29 * cos(a), y: s * 0.48 + s * 0.29 * sin(a))
  }
  let line = NSBezierPath()
  line.move(to: points[0])
  line.line(to: points[1])
  line.line(to: points[2])
  line.close()
  line.lineWidth = s * 0.025
  NSColor(calibratedRed: 0.25, green: 0.65, blue: 0.70, alpha: 0.6).setStroke()
  line.stroke()
  for (i, p) in points.enumerated() {
    let r = s * 0.075
    let circle = NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
    (i == 1
      ? NSColor(calibratedRed: 1, green: 0.62, blue: 0.28, alpha: 1)
      : NSColor(calibratedRed: 0.2, green: 0.88, blue: 0.86, alpha: 1)).setFill()
    circle.fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  let data = bitmap.representation(using: .png, properties: [:])!
  if size <= 512 {
    try data.write(to: URL(fileURLWithPath: destination + "/icon_\(size)x\(size).png"))
  }
  if size >= 32 {
    let half = size / 2
    try data.write(to: URL(fileURLWithPath: destination + "/icon_\(half)x\(half)@2x.png"))
  }
}
