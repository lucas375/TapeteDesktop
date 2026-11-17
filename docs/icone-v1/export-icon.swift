import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("Uso: swift export-icon.swift imagem.png destino.iconset\n", stderr)
    exit(2)
}
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard let image = NSImage(contentsOf: source),
      let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Não foi possível ler a arte do ícone.\n", stderr)
    exit(1)
}
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let context = CGContext(data: nil, width: pixels, height: pixels,
                                bitsPerComponent: 8, bytesPerRow: pixels * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(bitmap, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let output = NSBitmapImageRep(cgImage: context.makeImage()!)
        let suffix = scale == 2 ? "@2x" : ""
        let path = folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try output.representation(using: .png, properties: [:])!.write(to: path)
    }
}
print("Conjunto de ícones exportado: 10 PNGs.")
