import Foundation
import simd

/// Matches the Metal projection, including the five contact-shadow samples.
enum ClothProjection {
    static func textile(_ position: SIMD3<Float>, degrees: Double) -> CGPoint {
        let rotated = RugRotation.rotate(CGPoint(x: CGFloat(position.x), y: CGFloat(position.y)), degrees: degrees)
        let z = CGFloat(position.z)
        let perspective = 1500 / (1500 - z)
        return CGPoint(x: (rotated.x - 0.08 * z) * perspective,
                       y: (rotated.y + 0.18 * z) * perspective)
    }

    static func shadow(_ position: SIMD3<Float>, degrees: Double) -> CGPoint {
        let rotated = RugRotation.rotate(CGPoint(x: CGFloat(position.x), y: CGFloat(position.y)), degrees: degrees)
        return CGPoint(x: rotated.x + 0.33 * CGFloat(position.z) + 2,
                       y: rotated.y - 0.45 * CGFloat(position.z) - 3)
    }

    static func canvasSize(positions: [SIMD3<Float>], baseSize: CGSize, degrees: Double) -> CGSize {
        let minimum = RugRotation.canvasSize(baseSize: baseSize, degrees: degrees)
        var halfWidth = minimum.width / 2, halfHeight = minimum.height / 2
        for position in positions {
            let cloth = textile(position, degrees: degrees), contact = shadow(position, degrees: degrees)
            halfWidth = max(halfWidth, abs(cloth.x) + 4, abs(contact.x) + 6)
            halfHeight = max(halfHeight, abs(cloth.y) + 4, abs(contact.y) + 6)
        }
        // Grow in symmetric blocks to preserve the rest center and avoid
        // reallocating the Metal drawable on every small pointer movement.
        return CGSize(width: minimum.width + 64 * ceil(max(0, halfWidth - minimum.width / 2) / 32),
                      height: minimum.height + 64 * ceil(max(0, halfHeight - minimum.height / 2) / 32))
    }
}
