// Arrange unmodified simulator screenshots into a review sheet.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let width = 1280, height = 1000
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(red: 0.902, green: 0.918, blue: 0.933, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
    ])
}
let ink = NSColor(red: 0.094, green: 0.118, blue: 0.141, alpha: 1)
label("WhoAmI", x: 44, y: 920, size: 32, weight: .semibold, color: ink)
label("总览 · 七维记录 · 日期对比", x: 228, y: 927, size: 16, weight: .regular,
      color: NSColor(red: 0.384, green: 0.427, blue: 0.471, alpha: 1))
let screens = [("dashboard", "总览"), ("record-wheel", "记录"), ("comparison", "对比")]
for (index, screen) in screens.enumerated() {
    let x = CGFloat(44 + index * 412)
    label(screen.1, x: x + 4, y: 866, size: 17, weight: .medium, color: ink)
    let url = root.appendingPathComponent("design/screenshots/\(screen.0).png")
    guard let image = NSImage(contentsOf: url), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Missing screenshot: \(url.path)")
    }
    let rect = CGRect(x: x, y: 40, width: 370, height: 370 * 844 / 390)
    context.saveGState()
    let clip = CGPath(roundedRect: rect, cornerWidth: 21, cornerHeight: 21, transform: nil)
    context.addPath(clip); context.clip()
    context.draw(cg, in: rect)
    context.restoreGState()
}
NSGraphicsContext.restoreGraphicsState()
let image = NSBitmapImageRep(cgImage: context.makeImage()!)
let data = image.representation(using: .png, properties: [:])!
let destination = root.appendingPathComponent("design/screenshots/overview.png")
try data.write(to: destination)
print(destination.path)
