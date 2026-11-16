import AppKit

@main
@MainActor
struct MakeIcon {
    static func main() throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                          isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                let graphics = NSGraphicsContext(bitmapImageRep: rep)!
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
                let context = graphics.cgContext
                let p = CGFloat(pixels)
                let tile = CGRect(x: p * 0.06, y: p * 0.06, width: p * 0.88, height: p * 0.88)
                let path = CGPath(roundedRect: tile, cornerWidth: p * 0.20, cornerHeight: p * 0.20, transform: nil)
                context.setFillColor(CGColor(red: 0.94, green: 0.91, blue: 0.84, alpha: 1))
                context.addPath(path); context.fillPath()
                context.saveGState()
                context.translateBy(x: p / 2, y: p / 2)
                context.rotate(by: -.pi / 12)
                RugArtwork.draw(in: context, bounds: CGRect(x: -p * 0.39, y: -p * 0.30, width: p * 0.78, height: p * 0.60), palette: .wine)
                context.restoreGState()
                NSGraphicsContext.restoreGraphicsState()
                let suffix = scale == 2 ? "@2x" : ""
                try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
            }
        }
    }
}
