import AppKit
import ImageIO
import UniformTypeIdentifiers

struct IconImage {
    let filename: String
    let size: Int
}

let iphoneIcons: [IconImage] = [
    .init(filename: "AppIcon-20@2x.png", size: 40),
    .init(filename: "AppIcon-20@3x.png", size: 60),
    .init(filename: "AppIcon-29@2x.png", size: 58),
    .init(filename: "AppIcon-29@3x.png", size: 87),
    .init(filename: "AppIcon-40@2x.png", size: 80),
    .init(filename: "AppIcon-40@3x.png", size: 120),
    .init(filename: "AppIcon-60@2x.png", size: 120),
    .init(filename: "AppIcon-60@3x.png", size: 180),
    .init(filename: "AppIcon-1024.png", size: 1024)
]

let watchIcons: [IconImage] = [
    .init(filename: "AppIcon-24@2x.png", size: 48),
    .init(filename: "AppIcon-27.5@2x.png", size: 55),
    .init(filename: "AppIcon-29@2x.png", size: 58),
    .init(filename: "AppIcon-29@3x.png", size: 87),
    .init(filename: "AppIcon-40@2x.png", size: 80),
    .init(filename: "AppIcon-44@2x.png", size: 88),
    .init(filename: "AppIcon-50@2x.png", size: 100),
    .init(filename: "AppIcon-86@2x.png", size: 172),
    .init(filename: "AppIcon-98@2x.png", size: 196),
    .init(filename: "AppIcon-108@2x.png", size: 216),
    .init(filename: "AppIcon-1024.png", size: 1024)
]

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(size: Int, to url: URL) throws {
    let width = size
    let height = size
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }

    let canvas = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    context.setFillColor(NSColor.white.cgColor)
    context.fill(canvas)

    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: CGFloat(size) / 1024.0, y: -CGFloat(size) / 1024.0)

    context.setFillColor(NSColor.black.cgColor)

    let vertical = CGRect(x: 314, y: 246, width: 116, height: 532)
    context.addPath(roundedRect(vertical, radius: 58))
    context.fillPath()

    let bowlOuter = CGRect(x: 314, y: 246, width: 396, height: 326)
    context.addPath(roundedRect(bowlOuter, radius: 163))
    context.fillPath()

    context.setBlendMode(.clear)
    let bowlInner = CGRect(x: 430, y: 362, width: 150, height: 94)
    context.addPath(roundedRect(bowlInner, radius: 47))
    context.fillPath()

    let lowerCut = CGRect(x: 430, y: 510, width: 350, height: 286)
    context.addPath(roundedRect(lowerCut, radius: 72))
    context.fillPath()

    context.setBlendMode(.normal)
    context.setFillColor(NSColor.black.cgColor)
    let dot = CGRect(x: 616, y: 596, width: 88, height: 88)
    context.fillEllipse(in: dot)

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "IconGenerator", code: 2)
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "IconGenerator", code: 3)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iphoneDirectory = root.appendingPathComponent("PeterAI/PeterAI/Assets.xcassets/AppIcon.appiconset")
let watchDirectory = root.appendingPathComponent("PeterAI/PeterAIWatch/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(at: watchDirectory, withIntermediateDirectories: true)

for icon in iphoneIcons {
    try drawIcon(size: icon.size, to: iphoneDirectory.appendingPathComponent(icon.filename))
}

for icon in watchIcons {
    try drawIcon(size: icon.size, to: watchDirectory.appendingPathComponent(icon.filename))
}
