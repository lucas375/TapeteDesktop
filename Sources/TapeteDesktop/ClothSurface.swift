import AppKit
import MetalKit
import simd

/// A transparent, on-demand Metal surface. There is no rendering loop at rest.
@MainActor
final class ClothSurface: MTKView {
    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var uv: SIMD2<Float>
    }
    struct Uniforms {
        var viewport: SIMD4<Float>
        var pass: SIMD4<Float>
    }
    private var pipeline: MTLRenderPipelineState?
    private var queue: MTLCommandQueue?
    private var depthState: MTLDepthStencilState?
    private var texture: MTLTexture?
    private var indexBuffer: MTLBuffer?
    private var indexCount = 0
    private var lastSimulation: ClothSimulation?
    private(set) var renderingError: String?
    var palette: RugPalette = .wine { didSet { if palette != oldValue { loadTexture(); redraw() } } }
    var rotationDegrees = 0.0 { didSet { if rotationDegrees != oldValue { redraw() } } }

    init() {
        let device = MTLCreateSystemDefaultDevice()
        super.init(frame: .zero, device: device)
        isPaused = true; enableSetNeedsDisplay = false
        colorPixelFormat = .bgra8Unorm
        depthStencilPixelFormat = .depth32Float
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        framebufferOnly = true
        wantsLayer = true; layer?.isOpaque = false; layer?.backgroundColor = NSColor.clear.cgColor
        guard let device else { renderingError = "Metal indisponível"; return }
        queue = device.makeCommandQueue()
        do {
            let library = try device.makeLibrary(source: Self.shader, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "cloth_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "cloth_fragment")
            descriptor.depthAttachmentPixelFormat = .depth32Float
            let depth = MTLDepthStencilDescriptor()
            depth.depthCompareFunction = .lessEqual; depth.isDepthWriteEnabled = true
            depthState = device.makeDepthStencilState(descriptor: depth)
            let color = descriptor.colorAttachments[0]!
            color.pixelFormat = colorPixelFormat; color.isBlendingEnabled = true
            color.sourceRGBBlendFactor = .sourceAlpha; color.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color.sourceAlphaBlendFactor = .one; color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            loadTexture()
        } catch { renderingError = error.localizedDescription }
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func loadTexture() {
        guard let device else { return }
        let image = RugTexture.image(palette: palette)
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            renderingError = "Textura indisponível"; return
        }
        do {
            texture = try MTKTextureLoader(device: device).newTexture(cgImage: cg, options: [
                .SRGB: false, .generateMipmaps: true, .origin: MTKTextureLoader.Origin.bottomLeft
            ])
        } catch { renderingError = error.localizedDescription }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in self?.redraw() }
    }
    func update(_ simulation: ClothSimulation) {
        if lastSimulation?.positions.count != simulation.positions.count {
            let indices = simulation.triangleIndices
            indexCount = indices.count
            indexBuffer = device?.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)
        }
        lastSimulation = simulation; redraw()
    }
    func redraw() { draw() }
    override func draw(_ dirtyRect: NSRect) {
        guard let simulation = lastSimulation, let pipeline, let texture, let indexBuffer,
              let device, let queue, bounds.width > 0, bounds.height > 0 else { return }
        guard let descriptor = currentRenderPassDescriptor, let drawable = currentDrawable,
              let command = queue.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        let normals = simulation.normals()
        let vertices = simulation.positions.indices.map { i in
            Vertex(position: simulation.positions[i], normal: normals[i],
                   uv: SIMD2(Float(i % simulation.columns) / Float(simulation.columns - 1),
                             Float(i / simulation.columns) / Float(simulation.rows - 1)))
        }
        guard let buffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared) else {
            encoder.endEncoding(); return
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setCullMode(.none); encoder.setFrontFacing(.counterClockwise)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        let angle = RugRotation.radians(rotationDegrees)
        let viewport = SIMD4<Float>(Float(bounds.width), Float(bounds.height), Float(cos(angle)), Float(sin(angle)))
        func draw(pass: SIMD4<Float>) {
            var uniforms = Uniforms(viewport: viewport, pass: pass)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32,
                                          indexBuffer: indexBuffer, indexBufferOffset: 0)
        }
        // Several soft contact-shadow samples, projected in the light direction.
        for offset: SIMD2<Float> in [SIMD2(-2, 0), SIMD2(2, 0), SIMD2(0, -2), SIMD2(0, 2), .zero] {
            draw(pass: SIMD4(1, offset.x, offset.y, 0))
        }
        encoder.setDepthStencilState(depthState)
        draw(pass: .zero)
        encoder.endEncoding(); command.present(drawable); command.commit()
    }
    /// Deterministic off-screen render used by the app's smoke check.
    func snapshotImage(simulation: ClothSimulation, size: CGSize) throws -> NSImage {
        guard let device, let pipeline, let queue, let texture else {
            throw SmokeCheck.Failure(description: renderingError ?? "Metal initialization")
        }
        let width = Int(size.width), height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                  width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]; descriptor.storageMode = .shared
        let output = device.makeTexture(descriptor: descriptor)!
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        depthDescriptor.storageMode = .private; depthDescriptor.usage = .renderTarget
        let depthTexture = device.makeTexture(descriptor: depthDescriptor)!
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = output
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        renderPass.depthAttachment.texture = depthTexture
        renderPass.depthAttachment.loadAction = .clear; renderPass.depthAttachment.clearDepth = 1
        renderPass.depthAttachment.storeAction = .dontCare
        let command = queue.makeCommandBuffer()!
        let encoder = command.makeRenderCommandEncoder(descriptor: renderPass)!
        let normals = simulation.normals()
        let vertices = simulation.positions.indices.map { i in
            Vertex(position: simulation.positions[i], normal: normals[i],
                   uv: SIMD2(Float(i % simulation.columns) / Float(simulation.columns - 1), Float(i / simulation.columns) / Float(simulation.rows - 1)))
        }
        let indices = simulation.triangleIndices
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride)!
        let elementBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride)!
        encoder.setRenderPipelineState(pipeline); encoder.setCullMode(.none); encoder.setFrontFacing(.counterClockwise)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0); encoder.setFragmentTexture(texture, index: 0)
        for pass: SIMD4<Float> in [SIMD4(1, -2, 0, 0), SIMD4(1, 2, 0, 0), SIMD4(1, 0, -2, 0), SIMD4(1, 0, 2, 0), SIMD4(1, 0, 0, 0), .zero] {
            if pass.x == 0 { encoder.setDepthStencilState(depthState) }
            let canvas = ClothProjection.canvasSize(positions: simulation.positions, baseSize: CGSize(width: CGFloat(simulation.size.x) + 24, height: CGFloat(simulation.size.y) + 24), degrees: rotationDegrees)
            let angle = RugRotation.radians(rotationDegrees)
            var uniforms = Uniforms(viewport: SIMD4(Float(canvas.width), Float(canvas.height), Float(cos(angle)), Float(sin(angle))), pass: pass)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint32,
                                          indexBuffer: elementBuffer, indexBufferOffset: 0)
        }
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                  bitmapFormat: [], bytesPerRow: width * 4, bitsPerPixel: 32)!
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        output.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            rep.bitmapData![i] = bytes[i + 2]; rep.bitmapData![i + 1] = bytes[i + 1]
            rep.bitmapData![i + 2] = bytes[i]; rep.bitmapData![i + 3] = bytes[i + 3]
        }
        let result = NSImage(size: size); result.addRepresentation(rep); return result
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Vertex { float3 position; float3 normal; float2 uv; };
    struct Uniforms { float4 viewport; float4 pass; };
    struct Output { float4 position [[position]]; float3 normal; float2 uv; float height; };
    vertex Output cloth_vertex(const device Vertex *vertices [[buffer(0)]],
                               constant Uniforms &u [[buffer(1)]], uint id [[vertex_id]]) {
        Vertex v = vertices[id];
        float2 rotated = float2(v.position.x * u.viewport.z - v.position.y * u.viewport.w,
                                v.position.x * u.viewport.w + v.position.y * u.viewport.z);
        float3 normal = float3(v.normal.x * u.viewport.z - v.normal.y * u.viewport.w,
                               v.normal.x * u.viewport.w + v.normal.y * u.viewport.z, v.normal.z);
        float2 p;
        if (u.pass.x > 0.5) {
            p = rotated + float2(0.33, -0.45) * v.position.z + float2(2, -3) + u.pass.yz;
        } else {
            float perspective = 1500.0 / (1500.0 - v.position.z);
            p = (rotated + float2(-0.08, 0.18) * v.position.z) * perspective;
        }
        Output out;
        out.position = float4(p.x * 2.0 / u.viewport.x, p.y * 2.0 / u.viewport.y, u.pass.x > 0.5 ? 0.99 : 0.8 - v.position.z / 1000.0, 1);
        out.normal = normal; out.uv = v.uv; out.height = v.position.z;
        return out;
    }
    fragment float4 cloth_fragment(Output in [[stage_in]], bool front [[front_facing]],
                                    texture2d<float> image [[texture(0)]], constant Uniforms &u [[buffer(1)]]) {
        constexpr sampler s(filter::linear, mip_filter::linear, max_anisotropy(8), address::clamp_to_zero);
        float4 tex = image.sample(s, in.uv);
        if (tex.a < 0.015) discard_fragment();
        if (u.pass.x > 0.5) return float4(0.06, 0.045, 0.035, tex.a * 0.060 * exp(-in.height / 300.0));
        float3 normal = normalize(in.normal);
        if (!front) normal = -normal;
        float2 pixel = 1.0 / float2(image.get_width(), image.get_height());
        float3 nearby = (image.sample(s, in.uv + float2(pixel.x, 0)).rgb
                       + image.sample(s, in.uv - float2(pixel.x, 0)).rgb
                       + image.sample(s, in.uv + float2(0, pixel.y)).rgb
                       + image.sample(s, in.uv - float2(0, pixel.y)).rgb) * 0.25;
        float3 color = saturate(tex.rgb + (tex.rgb - nearby) * 0.28);
        // Slightly illustrated satin finish: cleaner contrast, stronger folds,
        // and broad highlights that do not depend on tiny photographic fibers.
        color = pow(color, float3(0.88));
        float luminance = dot(color, float3(0.299, 0.587, 0.114));
        color = saturate(mix(float3(luminance), color, 1.14));
        if (!front) {
            float gray = dot(color, float3(0.299, 0.587, 0.114));
            color = mix(color, gray * float3(1.12, 0.96, 0.78), 0.74) * 0.96;
        }
        float3 lightDirection = normalize(float3(-0.45, 0.55, 0.85));
        float diffuse = 0.48 + 0.62 * max(0.0, dot(normal, lightDirection));
        float bend = saturate(1.0 - abs(normal.z));
        float specular = pow(max(0.0, dot(normal, normalize(lightDirection + float3(0, 0, 1)))), 22.0);
        float sheen = (0.055 + 0.34 * sqrt(bend)) * specular;
        float rim = 0.13 * bend * bend;
        float foldHighlight = 0.18 * pow(saturate(1.0 - abs(normal.z - 0.45) * 1.8), 6.0);
        color = color * diffuse + float3(1.0, 0.94, 0.84) * (sheen + rim + foldHighlight);
        return float4(saturate(color), tex.a);
    }
    """
}
