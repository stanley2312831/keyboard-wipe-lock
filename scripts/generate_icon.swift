import AppKit
import Foundation

let fm = FileManager.default
let base = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = base.appendingPathComponent("build/AppIcon.iconset")

try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func makeIcon(size: Int, to url: URL) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let image = NSImage(size: rect.size)
    image.lockFocus()

    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.03, dy: CGFloat(size) * 0.03),
                          xRadius: CGFloat(size) * 0.22,
                          yRadius: CGFloat(size) * 0.22)
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.14, alpha: 1.0).setFill()
    bg.fill()

    let circleRect = rect.insetBy(dx: CGFloat(size) * 0.17, dy: CGFloat(size) * 0.17)
    let circle = NSBezierPath(ovalIn: circleRect)
    NSColor(calibratedRed: 0.17, green: 0.55, blue: 0.95, alpha: 1.0).setFill()
    circle.fill()

    let text = "🧽"
    let fontSize = CGFloat(size) * 0.52
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize),
    ]
    let attr = NSAttributedString(string: text, attributes: attrs)
    let tsize = attr.size()
    let trect = NSRect(x: (CGFloat(size) - tsize.width) / 2,
                       y: (CGFloat(size) - tsize.height) / 2 - CGFloat(size) * 0.02,
                       width: tsize.width,
                       height: tsize.height)
    attr.draw(in: trect)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        return
    }
    try? png.write(to: url)
}

for (size, name) in specs {
    makeIcon(size: size, to: iconset.appendingPathComponent(name))
}

print("Generated iconset at \(iconset.path)")
