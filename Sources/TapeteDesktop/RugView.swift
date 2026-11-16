import AppKit
import simd

@MainActor
final class RugView: NSView {
    var palette: RugPalette = .wine { didSet { surface.palette = palette; needsDisplay = true } }
    var clothEnabled = true { didSet { if !clothEnabled { flatten() } } }
    var flexibility: Float = 1 { didSet { simulation.flexibility = flexibility } }
    var baseSize = CGSize(width: 640, height: 440) { didSet { if baseSize != oldValue { expandedCanvas = nil; needsLayout = true } } }
    var rotationDegrees = 0.0 { didSet {
        if rotationDegrees != oldValue { expandedCanvas = nil }
        surface.rotationDegrees = rotationDegrees; needsDisplay = true
    } }
    private var expandedCanvas: CGSize?
    var canvasSize: CGSize { expandedCanvas ?? RugRotation.canvasSize(baseSize: baseSize, degrees: rotationDegrees) }
    var clothTarget: SIMD3<Float> { simulation.target }
    var projectedClothPoints: [CGPoint] { simulation.positions.map { ClothProjection.textile($0, degrees: rotationDegrees) } }
    private let surface = ClothSurface()
    private var simulation = ClothSimulation(size: CGSize(width: 616, height: 416))
    private var animationTimer: Timer?
    private var lastFrameTime = 0.0
    private var clothGesture = false
    private var movingGesture = false
    private var rotatingGesture = false
    private var lastPointerAngle = 0.0
    private var gestureRotation = 0.0
    private var grabAnchor = SIMD2<Float>.zero
    private(set) var isAnimating = false
    var maximumClothHeight: Float { simulation.maximumHeight }
    var renderingError: String? { surface.renderingError }
    var isLocked = false {
        didSet {
            if isLocked { dragOrigin = nil; flatten() }
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }
    var onFrameChanged: ((CGRect) -> Void)?
    var onCanvasChanged: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onLock: (() -> Void)?
    var onResize: ((CGSize) -> Void)?
    var onEditSize: (() -> Void)?
    var onRotate: ((Double) -> Void)?
    var onEditRotation: (() -> Void)?
    private var tracking: NSTrackingArea?
    private var dragOrigin: CGPoint?
    private var initialFrame = CGRect.zero
    private var dragEdges: ResizeEdges = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(surface)
        surface.frame = bounds; surface.autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    convenience init() { self.init(frame: .zero) }

    override func layout() {
        super.layout()
        simulation.resize(CGSize(width: max(60, baseSize.width - 24), height: max(60, baseSize.height - 24)))
        surface.frame = bounds
        surface.update(simulation)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopAnimation() }
        else { needsLayout = true; layoutSubtreeIfNeeded(); surface.update(simulation) }
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard super.hitTest(point) != nil else { return nil }
        let local = RugRotation.localPoint(convert(point, from: superview), in: bounds, degrees: rotationDegrees)
        let area = CGRect(x: -baseSize.width / 2, y: -baseSize.height / 2, width: baseSize.width, height: baseSize.height)
        return area.contains(local) ? self : nil
    }
    func flatten() {
        simulation.flatten(); clothGesture = false
        stopAnimation(); fitCanvas(); surface.update(simulation)
    }
    private func fitCanvas() {
        let previous = canvasSize
        if simulation.isSettled { expandedCanvas = nil }
        else {
            let needed = ClothProjection.canvasSize(positions: simulation.positions, baseSize: baseSize, degrees: rotationDegrees)
            expandedCanvas = CGSize(width: max(previous.width, needed.width), height: max(previous.height, needed.height))
        }
        if canvasSize != previous { onCanvasChanged?() }
    }
    func suspendAnimation() { flatten() }
    private func stopAnimation() { animationTimer?.invalidate(); animationTimer = nil; isAnimating = false }
    private func startAnimation() {
        guard animationTimer == nil else { return }
        lastFrameTime = ProcessInfo.processInfo.systemUptime; isAnimating = true
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advanceFrame() }
        }
        animationTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }

    private func advanceFrame() {
        guard isAnimating else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = Float(now - lastFrameTime)
        guard elapsed >= 1 / Float(240) else { return }
        lastFrameTime = now; advanceAnimation(deltaTime: elapsed)
    }

    func advanceAnimation(deltaTime: Float) {
        guard isAnimating else { return }
        simulation.step(deltaTime: deltaTime)
        fitCanvas()
        surface.update(simulation)
        if simulation.isSettled { stopAnimation() }
    }

    override var acceptsFirstResponder: Bool { false }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }

    override func draw(_ dirtyRect: NSRect) {
        if surface.renderingError != nil {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.saveGState()
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.rotate(by: RugRotation.radians(rotationDegrees))
            let size = CGSize(width: baseSize.width - 24, height: baseSize.height - 24)
            RugTexture.image(palette: palette).draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
            context.restoreGState()
        }
    }

    override func mouseEntered(with event: NSEvent) { updateCursor(event) }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseMoved(with event: NSEvent) { updateCursor(event) }

    override func resetCursorRects() {
        guard !isLocked else { return }
        addCursorRect(bounds, cursor: .openHand)
    }

    private func basePoint(_ event: NSEvent) -> CGPoint {
        let point = RugRotation.localPoint(convert(event.locationInWindow, from: nil), in: bounds, degrees: rotationDegrees)
        return CGPoint(x: point.x + baseSize.width / 2, y: point.y + baseSize.height / 2)
    }

    private func updateCursor(_ event: NSEvent) {
        guard !isLocked else { return }
        cursor(for: RugGeometry.edges(at: basePoint(event), in: CGRect(origin: .zero, size: baseSize))).set()
    }

    private func cursor(for edges: ResizeEdges) -> NSCursor {
        if edges.isEmpty { return .openHand }
        let horizontal = edges.contains(.left) || edges.contains(.right)
        let vertical = edges.contains(.top) || edges.contains(.bottom)
        let rising = (edges.contains(.left) && edges.contains(.bottom)) || (edges.contains(.right) && edges.contains(.top))
        let direction = horizontal && vertical ? (rising ? 45.0 : 135.0) : (horizontal ? 0.0 : 90.0)
        let axis = Int((RugRotation.normalized(direction - rotationDegrees).truncatingRemainder(dividingBy: 180) + 22.5) / 45) % 4
        switch axis {
        case 0: return .resizeLeftRight
        case 1: return Self.risingCursor
        case 2: return .resizeUpDown
        default: return Self.fallingCursor
        }
    }

    private static let risingCursor = diagonalCursor(rising: true)
    private static let fallingCursor = diagonalCursor(rising: false)
    private static func diagonalCursor(rising: Bool) -> NSCursor {
        let image = NSImage(size: NSSize(width: 24, height: 24), flipped: false) { _ in
            let path = NSBezierPath()
            let points: [CGPoint] = [CGPoint(x: 5, y: 5), CGPoint(x: 19, y: 19),
                                     CGPoint(x: 12, y: 19), CGPoint(x: 19, y: 19), CGPoint(x: 19, y: 12),
                                     CGPoint(x: 5, y: 12), CGPoint(x: 5, y: 5), CGPoint(x: 12, y: 5)]
            func p(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: rising ? point.y : 24 - point.y) }
            path.move(to: p(points[0])); path.line(to: p(points[1]))
            path.move(to: p(points[2])); path.line(to: p(points[3])); path.line(to: p(points[4]))
            path.move(to: p(points[5])); path.line(to: p(points[6])); path.line(to: p(points[7]))
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            NSColor.white.setStroke(); path.lineWidth = 4; path.stroke()
            NSColor.black.setStroke(); path.lineWidth = 2; path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }

    override func mouseDown(with event: NSEvent) {
        beginDrag(at: basePoint(event), screenPoint: NSEvent.mouseLocation,
                  modifiers: event.modifierFlags, clickCount: event.clickCount)
    }
    func beginDrag(at point: CGPoint, screenPoint: CGPoint, modifiers: NSEvent.ModifierFlags = [], clickCount: Int = 1) {
        guard !isLocked, let window else { return }
        if clickCount == 2 { flatten(); return }
        initialFrame = RugRotation.baseFrame(center: CGPoint(x: window.frame.midX, y: window.frame.midY), size: baseSize)
        dragOrigin = screenPoint
        rotatingGesture = modifiers.contains([.option, .shift])
        if rotatingGesture {
            gestureRotation = rotationDegrees
            lastPointerAngle = atan2(screenPoint.y - initialFrame.midY, screenPoint.x - initialFrame.midX)
            clothGesture = false; dragEdges = []; NSCursor.crosshair.set(); return
        }
        let forceMove = modifiers.contains(.option)
        movingGesture = forceMove
        dragEdges = forceMove ? [] : RugGeometry.edges(at: point, in: CGRect(origin: .zero, size: baseSize))
        clothGesture = !movingGesture && dragEdges.isEmpty && clothEnabled && surface.renderingError == nil
        if clothGesture {
            let index = simulation.grab(at: SIMD2(Float(point.x - baseSize.width / 2), Float(point.y - baseSize.height / 2)))
            grabAnchor = SIMD2(simulation.positions[index].x, simulation.positions[index].y)
            startAnimation()
        }
        if dragEdges.isEmpty { NSCursor.closedHand.set() }
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        continueDrag(at: NSEvent.mouseLocation, pressure: Float(event.pressure))
    }
    func continueDrag(at pointer: CGPoint, pressure: Float = 0) {
        guard !isLocked, let origin = dragOrigin, window != nil else { return }
        if rotatingGesture {
            let angle = atan2(pointer.y - initialFrame.midY, pointer.x - initialFrame.midX)
            var step = angle - lastPointerAngle
            if step > .pi { step -= 2 * .pi }
            if step < -.pi { step += 2 * .pi }
            gestureRotation -= step * 180 / .pi
            lastPointerAngle = angle; onRotate?(gestureRotation); return
        }
        let delta = CGSize(width: pointer.x - origin.x, height: pointer.y - origin.y)
        if clothGesture {
            let length = hypot(Float(delta.width), Float(delta.height))
            let local = RugRotation.rotate(CGPoint(x: delta.width, y: delta.height), degrees: -rotationDegrees)
            simulation.drag(to: grabAnchor + SIMD2(Float(local.x), Float(local.y)),
                            lift: 58 + length * 0.88 * flexibility + max(0, pressure) * 24)
            advanceFrame()
            return
        }
        let frame: CGRect
        if dragEdges.isEmpty {
            guard movingGesture else { return }
            frame = initialFrame.offsetBy(dx: delta.width, dy: delta.height)
        }
        else { frame = RugRotation.resizing(baseFrame: initialFrame, delta: delta, edges: dragEdges, degrees: rotationDegrees) }
        onFrameChanged?(frame)
    }
    override func mouseUp(with event: NSEvent) {
        endDrag()
        window?.invalidateCursorRects(for: self)
        updateCursor(event); needsDisplay = true
    }
    func endDrag() {
        guard dragOrigin != nil else { return }
        if clothGesture {
            simulation.release(); startAnimation()
        }
        else { onDragEnded?() }
        dragOrigin = nil; dragEdges = []; clothGesture = false; movingGesture = false; rotatingGesture = false
    }
    override var mouseDownCanMoveWindow: Bool { false }

    override func rightMouseDown(with event: NSEvent) {
        guard !isLocked else { return }
        NSMenu.popUpContextMenu(makeContextMenu(), with: event, for: self)
    }
    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(RugSizeMenu.item(currentSize: baseSize,
                                     resize: { [weak self] in self?.onResize?($0) },
                                     custom: { [weak self] in self?.onEditSize?() }))
        menu.addItem(RugRotationMenu.item(degrees: rotationDegrees,
                                         rotate: { [weak self] in self?.onRotate?($0) },
                                         custom: { [weak self] in self?.onEditRotation?() }))
        menu.addItem(.separator())
        let smooth = NSMenuItem(title: "Alisar tapete", action: #selector(flattenRug), keyEquivalent: "")
        smooth.target = self; menu.addItem(smooth)
        let item = NSMenuItem(title: "Travar tapete", action: #selector(lockRug), keyEquivalent: "")
        item.target = self; menu.addItem(item)
        return menu
    }
    @objc private func flattenRug() { flatten() }
    @objc private func lockRug() { onLock?() }
}
