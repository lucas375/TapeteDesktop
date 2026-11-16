import AppKit
import CoreImage

@MainActor
enum RugTexture {
    private static var cache: [RugPalette: NSImage] = [:]
    static var hasPhotographicTexture: Bool { textureURL != nil }
    private static var textureURL: URL? {
        if let url = Bundle.main.url(forResource: "PersianRug", withExtension: "png") { return url }
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: "PersianRug", withExtension: "png")
        #else
        return nil
        #endif
    }
    static func image(palette: RugPalette) -> NSImage {
        if let value = cache[palette] { return value }
        guard let url = textureURL, let original = NSImage(contentsOf: url) else {
            let fallback = NSImage(size: CGSize(width: 1440, height: 1000), flipped: false) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                RugArtwork.draw(in: context, bounds: rect, palette: palette); return true
            }
            cache[palette] = fallback; return fallback
        }
        guard palette != .wine,
              let cg = original.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cube = CIFilter(name: "CIColorCube") else {
            cache[palette] = original; return original
        }
        let dimension = 24
        var values: [Float] = []
        for b in 0..<dimension { for g in 0..<dimension { for r in 0..<dimension {
            let color = SIMD3<Float>(Float(r), Float(g), Float(b)) / Float(dimension - 1)
            let weight = min(1, max(0, (color.x - max(color.y, color.z) * 1.18) * 7))
            let replacement: SIMD3<Float>
            if palette == .indigo {
                replacement = SIMD3(color.x * 0.30 + color.y * 0.30,
                                    color.x * 0.36 + color.y * 0.55,
                                    color.x * 0.70 + color.z * 0.24)
            } else {
                replacement = SIMD3(color.x * 0.48 + color.y * 0.23,
                                    color.x * 0.48 + color.y * 0.52,
                                    color.x * 0.26 + color.z * 0.48)
            }
            let output = color + (replacement - color) * weight
            values += [output.x, output.y, output.z, 1]
        } } }
        cube.setValue(CIImage(cgImage: cg), forKey: kCIInputImageKey)
        cube.setValue(dimension, forKey: "inputCubeDimension")
        cube.setValue(values.withUnsafeBytes { Data($0) }, forKey: "inputCubeData")
        if let output = cube.outputImage, let result = CIContext().createCGImage(output, from: output.extent) {
            let image = NSImage(cgImage: result, size: original.size); cache[palette] = image; return image
        }
        cache[palette] = original; return original
    }
}
