import AppKit

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.06
    let innerRect = rect.insetBy(dx: inset, dy: inset)
    let radius = size * 0.22
    
    // Rounded rect path and clip
    let bgPath = NSBezierPath(roundedRect: innerRect, xRadius: radius, yRadius: radius)
    bgPath.addClip()
    
    // Dark gradient background
    let bgGradient = NSGradient(colors: [
        NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0),
        NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
    ])!
    bgGradient.draw(in: rect, angle: 135)
    
    // Subtle top highlight
    let highlightGradient = NSGradient(colors: [
        NSColor(white: 1.0, alpha: 0.08),
        NSColor(white: 1.0, alpha: 0.0)
    ])!
    highlightGradient.draw(in: rect, angle: 90)
    
    // Lightning bolt - smaller
    let boltSize = size * 0.35
    let ox = (size - boltSize) / 2
    let oy = (size - boltSize) / 2
    let s = boltSize / 100.0
    
    let boltPath = NSBezierPath()
    boltPath.move(to: CGPoint(x: ox + 58 * s, y: oy + 8 * s))
    boltPath.line(to: CGPoint(x: ox + 32 * s, y: oy + 46 * s))
    boltPath.line(to: CGPoint(x: ox + 46 * s, y: oy + 46 * s))
    boltPath.line(to: CGPoint(x: ox + 40 * s, y: oy + 88 * s))
    boltPath.line(to: CGPoint(x: ox + 68 * s, y: oy + 54 * s))
    boltPath.line(to: CGPoint(x: ox + 54 * s, y: oy + 54 * s))
    boltPath.close()
    
    // Shadow
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0.0, alpha: 0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -2 * s)
    shadow.shadowBlurRadius = 8 * s
    shadow.set()
    
    NSColor.white.setFill()
    boltPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    
    image.unlockFocus()
    return image
}

let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512]
let iconsetDir = "QuickMac/icon.iconset"

let fm = FileManager.default
if let files = try? fm.contentsOfDirectory(atPath: iconsetDir) {
    for file in files {
        try? fm.removeItem(atPath: "\(iconsetDir)/\(file)")
    }
}

for size in sizes {
    let image = createIcon(size: size)
    let tiff = image.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    let normalName = "\(iconsetDir)/icon_\(Int(size))x\(Int(size)).png"
    let normalData = rep.representation(using: .png, properties: [:])!
    try! normalData.write(to: URL(fileURLWithPath: normalName))
    
    if size <= 256 {
        let retinaImage = createIcon(size: size * 2)
        let retinaTiff = retinaImage.tiffRepresentation!
        let retinaRep = NSBitmapImageRep(data: retinaTiff)!
        let retinaName = "\(iconsetDir)/icon_\(Int(size))x\(Int(size))@2x.png"
        let retinaData = retinaRep.representation(using: .png, properties: [:])!
        try! retinaData.write(to: URL(fileURLWithPath: retinaName))
    }
}

let bigImage = createIcon(size: 1024)
let bigTiff = bigImage.tiffRepresentation!
let bigRep = NSBitmapImageRep(data: bigTiff)!
let bigData = bigRep.representation(using: .png, properties: [:])!
try! bigData.write(to: URL(fileURLWithPath: "\(iconsetDir)/icon_512x512@2x.png"))

print("Icon set created successfully")
