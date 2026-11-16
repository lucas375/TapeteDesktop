import XCTest
import simd
@testable import TapeteDesktop

final class ClothSimulationTests: XCTestCase {
    private func cloth() -> ClothSimulation { ClothSimulation(size: CGSize(width: 616, height: 416), columns: 19, rows: 15) }
    func testTouchLiftsTheChosenPointAndPropagatesToNeighbours() {
        var cloth = cloth()
        let grabbed = cloth.grab(at: SIMD2(180, 100))
        for _ in 0..<35 { cloth.step(deltaTime: 1 / 60) }
        XCTAssertGreaterThan(cloth.positions[grabbed].z, 28)
        XCTAssertGreaterThan(cloth.positions.filter { $0.z > 3 }.count, 5)
        XCTAssertFalse(cloth.isSettled)
    }
    func testCornerPullProducesSpatialFoldWithoutInvalidPositions() {
        var cloth = cloth()
        let index = cloth.grab(at: SIMD2(290, 190))
        cloth.drag(to: SIMD2(90, 40), lift: 140)
        for _ in 0..<65 { cloth.step(deltaTime: 1 / 60) }
        XCTAssertGreaterThan(cloth.maximumHeight, 110)
        XCTAssertLessThan(cloth.positions[index].x, cloth.rest[index].x - 100)
        XCTAssertTrue(cloth.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.z >= -0.001 })
        XCTAssertTrue(cloth.normals().allSatisfy { abs(simd_length($0) - 1) < 0.001 })
    }
    func testReleaseSettlesAndStopsSimulation() {
        var cloth = cloth()
        cloth.grab(at: SIMD2(180, 100)); cloth.drag(to: SIMD2(50, 20), lift: 100)
        for _ in 0..<35 { cloth.step(deltaTime: 1 / 60) }
        cloth.release()
        for _ in 0..<650 where !cloth.isSettled { cloth.step(deltaTime: 1 / 60) }
        XCTAssertTrue(cloth.isSettled)
        XCTAssertEqual(cloth.positions, cloth.rest)
    }
    func testStrongPullPreservesThePatternAreaAroundTheGrip() {
        var cloth = cloth()
        let i = cloth.grab(at: SIMD2(120, 60))
        let adjacent = i + 1, above = i + cloth.columns
        let originalArea = simd_length(simd_cross(cloth.rest[adjacent] - cloth.rest[i],
                                                 cloth.rest[above] - cloth.rest[i]))
        cloth.drag(to: SIMD2(-40, -30), lift: 145)
        for _ in 0..<70 { cloth.step(deltaTime: 1 / 60) }
        let pulledArea = simd_length(simd_cross(cloth.positions[adjacent] - cloth.positions[i],
                                               cloth.positions[above] - cloth.positions[i]))
        XCTAssertGreaterThan(pulledArea / originalArea, 0.5, "The pattern must not collapse into the grab point")
        XCTAssertLessThan(pulledArea / originalArea, 1.65, "The pattern must not stretch into a spike")
        XCTAssertLessThan(simd_distance(cloth.positions[i], cloth.target), 4)
    }
    func testFlattenAndResizeReleaseGrabAndStopMotion() {
        var cloth = cloth(); cloth.grab(at: .zero)
        cloth.step(deltaTime: 1 / 60); cloth.flatten()
        XCTAssertNil(cloth.grabbedIndex); XCTAssertTrue(cloth.isSettled)
        cloth.grab(at: .zero); cloth.resize(CGSize(width: 900, height: 600))
        XCTAssertNil(cloth.grabbedIndex); XCTAssertEqual(cloth.size, SIMD2(900, 600))
        XCTAssertEqual(cloth.positions, cloth.rest)
    }
    func testExtremePointerAndDelayedFrameStayFinite() {
        var cloth = cloth(); cloth.grab(at: .zero)
        cloth.drag(to: SIMD2(100_000, -100_000), lift: 100_000)
        for _ in 0..<60 { cloth.step(deltaTime: 3) }
        XCTAssertEqual(cloth.target.x, 100_000)
        XCTAssertEqual(cloth.target.y, -100_000)
        XCTAssertLessThanOrEqual(cloth.target.z, 416 * 0.65 + 0.001)
        XCTAssertTrue(cloth.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        XCTAssertTrue(cloth.triangleIndices.allSatisfy { Int($0) < cloth.positions.count })
    }
    func testOutwardPullCrossesEveryOriginalEdgeAndStillSettles() {
        for direction: SIMD2<Float> in [SIMD2(1, 0), SIMD2(-1, 0), SIMD2(0, 1), SIMD2(0, -1)] {
            var cloth = cloth()
            let i = cloth.grab(at: direction * SIMD2(220, 140))
            let point = direction * SIMD2(570, 430)
            cloth.drag(to: point, lift: 160)
            for _ in 0..<65 { cloth.step(deltaTime: 1 / 60) }
            XCTAssertLessThan(simd_distance(SIMD2(cloth.positions[i].x, cloth.positions[i].y), point), 12)
            XCTAssertGreaterThan(simd_dot(SIMD2(cloth.positions[i].x, cloth.positions[i].y), direction),
                                 abs(direction.x) * cloth.size.x / 2 + abs(direction.y) * cloth.size.y / 2 + 100)
            cloth.release()
            for _ in 0..<900 where !cloth.isSettled { cloth.step(deltaTime: 1 / 60) }
            XCTAssertTrue(cloth.isSettled)
        }
    }
    func testInvalidPointerDoesNotCorruptTheGrip() {
        var cloth = cloth(); cloth.grab(at: .zero)
        let previous = cloth.target
        cloth.drag(to: SIMD2(.nan, 0), lift: 50)
        cloth.drag(to: SIMD2(0, .infinity), lift: 50)
        cloth.drag(to: .zero, lift: .nan)
        XCTAssertEqual(cloth.target, previous)
    }
    func testExistingPreferencesKeepTheirValuesWhenClothFieldsAreMissing() throws {
        let old = Data(#"{"opacity":0.63,"isLocked":true,"isVisible":false,"palette":"indigo","joinsFullScreen":false,"frame":{"x":30,"y":50,"width":600,"height":400}}"#.utf8)
        let settings = try JSONDecoder().decode(RugSettings.self, from: old)
        XCTAssertEqual(settings.opacity, 0.63); XCTAssertTrue(settings.isLocked)
        XCTAssertFalse(settings.isVisible); XCTAssertEqual(settings.palette, .indigo)
        XCTAssertEqual(settings.frame?.width, 600); XCTAssertTrue(settings.clothEnabled)
        XCTAssertEqual(settings.flexibility, 1)
    }
}
