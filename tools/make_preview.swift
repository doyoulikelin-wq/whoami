// Arrange unmodified simulator screenshots into a review sheet.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let width = 1440, height = 880
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(red: 0.949, green: 0.945, blue: 0.929, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
    ])
}
let ink = NSColor(red: 0.16, green: 0.18, blue: 0.16, alpha: 1)
label("WhoAmI", x: 44, y: 816, size: 32, weight: .semibold, color: ink)
label("把今天的自己，好好记下来。", x: 228, y: 823, size: 16, weight: .regular,
      color: NSColor(red: 0.45, green: 0.47, blue: 0.43, alpha: 1))
let screens = [("today", "今天"), ("journal", "日记"), ("review", "复盘"), ("profile", "我的")]
for (index, screen) in screens.enumerated() {
    let x = CGFloat(44 + index * 346)
    label(screen.1, x: x + 4, y: 764, size: 17, weight: .medium, color: ink)
    let url = root.appendingPathComponent("design/screenshots/\(screen.0).png")
    guard let image = NSImage(contentsOf: url), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Missing screenshot: \(url.path)")
    }
    let rect = CGRect(x: x, y: 34, width: 314, height: 314 * 844 / 390)
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
