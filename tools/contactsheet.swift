// Build a contact sheet PNG from simulator screenshots (cropped to the watch face, labelled with the file name).
// Usage: contactsheet <out.png> <shot.png>...   Used by scripts/device-smoke.sh to review many devices in one image.
import AppKit
let args = CommandLine.arguments
let out = args[1]; let files = Array(args[2...])
let cols = 8, cellW = 150, cellH = 175, label = 14
let rows = (files.count + cols - 1) / cols
let W = cols * cellW, H = rows * cellH
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
for (i, f) in files.enumerated() {
    guard let img = NSImage(contentsOfFile: f) else { continue }
    let c = i % cols, r = i / cols
    let x = c * cellW, y = H - (r + 1) * cellH
    // crop the watch face area (skip title bar and status bar), keep aspect
    let sz = img.size
    let crop = NSRect(x: sz.width * 0.12, y: sz.height * 0.22, width: sz.width * 0.76, height: sz.height * 0.58)
    let scale = min(Double(cellW - 4) / crop.width, Double(cellH - label - 2) / crop.height)
    let dw = crop.width * scale, dh = crop.height * scale
    img.draw(in: NSRect(x: Double(x) + (Double(cellW) - dw) / 2, y: Double(y + label), width: dw, height: dh), from: crop, operation: .copy, fraction: 1)
    let name = ((f as NSString).lastPathComponent as NSString).deletingPathExtension.replacingOccurrences(of: "-widget", with: "")
    (name as NSString).draw(at: NSPoint(x: x + 3, y: y + 1), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.black])
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
