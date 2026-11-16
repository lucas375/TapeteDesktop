import Foundation

enum RugOrientation: Int, CaseIterable, Identifiable {
    case up, right, down, left
    var id: Int { rawValue }
    var degrees: Double { Double(rawValue * 90) }
    var symbol: String {
        switch self { case .up: return "arrow.up"; case .right: return "arrow.right"; case .down: return "arrow.down"; case .left: return "arrow.left" }
    }
    var arrow: String {
        switch self { case .up: return "↑"; case .right: return "→"; case .down: return "↓"; case .left: return "←" }
    }
    var title: String {
        switch self { case .up: return "Para cima"; case .right: return "Para a direita"; case .down: return "Para baixo"; case .left: return "Para a esquerda" }
    }
    static func current(degrees: Double) -> Self {
        Self(rawValue: Int(RugRotation.quarterTurn(degrees) / 90)) ?? .up
    }
}

/// Public angles are clockwise; cloth and AppKit coordinates use +Y upward.
enum RugRotation {
    static let padding: CGFloat = 24

    static func normalized(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let angle = degrees.truncatingRemainder(dividingBy: 360)
        return angle < 0 ? angle + 360 : angle
    }

    static func radians(_ degrees: Double) -> Double { -normalized(degrees) * .pi / 180 }

    static func quarterTurn(_ degrees: Double) -> Double {
        Double(Int((normalized(degrees) + 45) / 90) % 4) * 90
    }

    static func rotate(_ vector: CGPoint, degrees: Double) -> CGPoint {
        let angle = radians(degrees)
        return CGPoint(x: vector.x * cos(angle) - vector.y * sin(angle),
                       y: vector.x * sin(angle) + vector.y * cos(angle))
    }

    static func canvasSize(baseSize: CGSize, degrees: Double) -> CGSize {
        let angle = radians(degrees)
        let c = abs(cos(angle)) < 1e-10 ? 0 : abs(cos(angle))
        let s = abs(sin(angle)) < 1e-10 ? 0 : abs(sin(angle))
        let w = max(1, baseSize.width - padding), h = max(1, baseSize.height - padding)
        return CGSize(width: w * c + h * s + padding, height: w * s + h * c + padding)
    }

    static func baseFrame(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
               width: size.width, height: size.height)
    }

    static func displayFrame(baseFrame: CGRect, degrees: Double, expandedCanvas: CGSize? = nil) -> CGRect {
        let canvas = canvasSize(baseSize: baseFrame.size, degrees: degrees)
        var frame = self.baseFrame(center: CGPoint(x: baseFrame.midX, y: baseFrame.midY),
                                   size: CGSize(width: ceil(canvas.width), height: ceil(canvas.height)))
        // NSPanel initialization and subsequent setFrame calls round fractional
        // rectangles differently. Persist the exact cloth frame, but give AppKit
        // a deterministic integral display frame so reopening cannot move it.
        frame.origin.x = frame.origin.x.rounded()
        frame.origin.y = frame.origin.y.rounded()
        if let expandedCanvas {
            // Expand the already-aligned rest frame. Rounding its center again
            // can shift a half-point anchor when the origin crosses screen zero.
            frame = frame.insetBy(dx: -ceil(max(0, expandedCanvas.width - frame.width) / 2),
                                  dy: -ceil(max(0, expandedCanvas.height - frame.height) / 2))
        }
        return frame
    }

    static func localPoint(_ point: CGPoint, in bounds: CGRect, degrees: Double) -> CGPoint {
        rotate(CGPoint(x: point.x - bounds.midX, y: point.y - bounds.midY), degrees: -degrees)
    }

    /// Resize in cloth axes and rotate the center shift back into screen axes.
    /// The opposite edge or corner remains fixed even at arbitrary angles.
    static func resizing(baseFrame: CGRect, delta: CGSize, edges: ResizeEdges, degrees: Double) -> CGRect {
        let localDelta = rotate(CGPoint(x: delta.width, y: delta.height), degrees: -degrees)
        let original = CGRect(origin: .zero, size: baseFrame.size)
        let resized = RugGeometry.resizing(original, delta: CGSize(width: localDelta.x, height: localDelta.y), edges: edges)
        let shift = rotate(CGPoint(x: resized.midX - original.midX, y: resized.midY - original.midY), degrees: degrees)
        return self.baseFrame(center: CGPoint(x: baseFrame.midX + shift.x, y: baseFrame.midY + shift.y), size: resized.size)
    }
}
