import Foundation
import simd

/// Position-based cloth with structural, shear and bend constraints, a tabletop,
/// inertia and a movable grab constraint. Coordinates use points, with +Z up.
struct ClothSimulation {
    struct Link {
        let a: Int
        let b: Int
        let length: Float
        let stiffness: Float
    }
    let columns: Int
    let rows: Int
    private(set) var size: SIMD2<Float>
    private(set) var positions: [SIMD3<Float>] = []
    private(set) var rest: [SIMD3<Float>] = []
    private var previous: [SIMD3<Float>] = []
    private var links: [Link] = []
    private struct Grip {
        let index: Int
        let offset: SIMD3<Float>
        let strength: Float
    }
    private var grip: [Grip] = []
    private var grabOrigin = SIMD3<Float>.zero
    private(set) var grabbedIndex: Int?
    private(set) var target = SIMD3<Float>.zero
    private var quietFrames = 0
    private(set) var isSettled = true
    var flexibility: Float = 1
    var maximumHeight: Float { positions.map(\.z).max() ?? 0 }

    init(size: CGSize, columns: Int = 57, rows: Int = 41) {
        self.columns = max(3, columns); self.rows = max(3, rows)
        self.size = SIMD2(Float(size.width), Float(size.height))
        rebuild()
    }
    mutating func resize(_ newSize: CGSize) {
        let value = SIMD2(Float(newSize.width), Float(newSize.height))
        guard simd_distance(value, size) > 0.5 else { return }
        size = value; rebuild()
    }
    private mutating func rebuild() {
        rest = (0..<(columns * rows)).map { i in
            let u = Float(i % columns) / Float(columns - 1)
            let v = Float(i / columns) / Float(rows - 1)
            return SIMD3((u - 0.5) * size.x, (v - 0.5) * size.y, 0)
        }
        links = []
        func index(_ x: Int, _ y: Int) -> Int { y * columns + x }
        for y in 0..<rows {
            for x in 0..<columns {
                let a = index(x, y)
                let offsets: [(Int, Int, Float)] = [(1, 0, 1), (0, 1, 1), (1, 1, 0.72), (-1, 1, 0.72), (2, 0, 0.34), (0, 2, 0.34)]
                for (dx, dy, stiffness) in offsets where x + dx >= 0 && x + dx < columns && y + dy < rows {
                    let b = index(x + dx, y + dy)
                    links.append(Link(a: a, b: b, length: simd_distance(rest[a], rest[b]), stiffness: stiffness))
                }
            }
        }
        flatten()
    }
    mutating func flatten() {
        positions = rest; previous = rest; grabbedIndex = nil
        grip = []
        quietFrames = 0; isSettled = true
    }
    @discardableResult
    mutating func grab(at point: SIMD2<Float>) -> Int {
        let index = positions.indices.min {
            simd_distance_squared(SIMD2(positions[$0].x, positions[$0].y), point)
                < simd_distance_squared(SIMD2(positions[$1].x, positions[$1].y), point)
        } ?? 0
        grabbedIndex = index
        grabOrigin = positions[index]
        let radius = max(8, min(size.x / Float(columns - 1), size.y / Float(rows - 1)) * 1.65)
        grip = positions.indices.compactMap { i in
            let offset = positions[i] - grabOrigin
            let distance = simd_length(offset)
            guard distance <= radius else { return nil }
            return Grip(index: i, offset: offset, strength: 0.95 - 0.32 * distance / radius)
        }
        target = positions[index] + SIMD3(0, 0, 58)
        quietFrames = 0; isSettled = false
        return index
    }
    mutating func drag(to point: SIMD2<Float>, lift: Float) {
        guard grabbedIndex != nil, point.x.isFinite, point.y.isFinite, lift.isFinite else { return }
        // A grip follows the pointer beyond the original textile rectangle.
        // Only elevation is bounded; the transparent canvas grows with the fold.
        target = SIMD3(point.x, point.y, min(min(size.x, size.y) * 0.65, max(18, lift)))
        quietFrames = 0; isSettled = false
    }
    mutating func release() { grabbedIndex = nil; grip = []; quietFrames = 0; isSettled = false }

    mutating func step(deltaTime: Float) {
        guard !isSettled else { return }
        let dt = min(1 / Float(30), max(1 / Float(240), deltaTime)) / 2
        let pull = SIMD2(target.x - grabOrigin.x, target.y - grabOrigin.y)
        let distance = simd_length(pull)
        let direction = distance > 0.01 ? pull / distance : SIMD2<Float>(1, 0)
        let angle = min(1.8, distance / max(1, min(size.x, size.y) * 0.52) * 1.8)
        let gripRotation = simd_quatf(angle: angle, axis: SIMD3(-direction.y, direction.x, 0))
        var maxMotion: Float = 0
        for _ in 0..<2 {
            for i in positions.indices {
                let position = positions[i]
                let velocity = (position - previous[i]) * 0.975
                previous[i] = position
                let restoring = (rest[i] - position) * SIMD3<Float>(32, 32, 7)
                positions[i] += velocity + (restoring + SIMD3(0, 0, -680)) * dt * dt
            }
            for _ in 0..<7 {
                for link in links {
                    let difference = positions[link.b] - positions[link.a]
                    let distance = simd_length(difference)
                    guard distance > 0.0001 else { continue }
                    let correction = difference * ((distance - link.length) / distance * 0.5 * link.stiffness)
                    positions[link.a] += correction
                    positions[link.b] -= correction
                }
                for i in positions.indices {
                    // The floor prevents the carpet from falling behind the desktop plane.
                    if positions[i].z < 0 {
                        positions[i].z = 0
                        previous[i].z = min(previous[i].z, 0)
                        previous[i].x += (positions[i].x - previous[i].x) * 0.15
                        previous[i].y += (positions[i].y - previous[i].y) * 0.15
                    }
                    // Gentle tethers prevent dragging one corner from moving the whole rug.
                    let tether: Float = grabbedIndex == nil ? 0.0025 : 0.00065 / max(0.5, flexibility)
                    positions[i].x += (rest[i].x - positions[i].x) * tether
                    positions[i].y += (rest[i].y - positions[i].y) * tether
                }
                if grabbedIndex != nil {
                    // A small rotating grip preserves local texel area instead of
                    // stretching the pattern into a single needle at the cursor.
                    for point in grip {
                        var destination = target + gripRotation.act(point.offset)
                        destination.z = max(0, destination.z)
                        positions[point.index] = simd_mix(positions[point.index], destination,
                                                        SIMD3(repeating: point.strength))
                        previous[point.index] = positions[point.index]
                    }
                }
            }
            for i in positions.indices {
                maxMotion = max(maxMotion, simd_distance_squared(positions[i], previous[i]))
            }
        }
        if grabbedIndex == nil && maxMotion < 0.025 && maximumHeight < 0.8 { quietFrames += 1 }
        else { quietFrames = 0 }
        if quietFrames > 24 { flatten() }
    }

    func normals() -> [SIMD3<Float>] {
        positions.indices.map { i in
            let x = i % columns, y = i / columns
            let left = positions[y * columns + max(0, x - 1)]
            let right = positions[y * columns + min(columns - 1, x + 1)]
            let bottom = positions[max(0, y - 1) * columns + x]
            let top = positions[min(rows - 1, y + 1) * columns + x]
            let cross = simd_cross(right - left, top - bottom)
            return simd_length_squared(cross) > 0.00001 ? simd_normalize(cross) : SIMD3(0, 0, 1)
        }
    }
    var triangleIndices: [UInt32] {
        var result: [UInt32] = []
        for y in 0..<(rows - 1) {
            for x in 0..<(columns - 1) {
                let a = UInt32(y * columns + x), b = a + 1, c = a + UInt32(columns), d = c + 1
                result += [a, b, c, b, d, c]
            }
        }
        return result
    }
}
