import XCTest
@testable import TapeteDesktop

final class RugRotationTests: XCTestCase {
    private let size = CGSize(width: 640, height: 440)
    private func assertPoint(_ a: CGPoint, _ b: CGPoint, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: 0.000001, file: file, line: line)
    }
    func testAngleWrapsInBothDirectionsAndRejectsNonfiniteValues() {
        XCTAssertEqual(RugRotation.normalized(360), 0)
        XCTAssertEqual(RugRotation.normalized(725), 5)
        XCTAssertEqual(RugRotation.normalized(-15), 345)
        XCTAssertEqual(RugRotation.normalized(-720), 0)
        XCTAssertEqual(RugRotation.normalized(.nan), 0)
        XCTAssertEqual(RugRotation.normalized(.infinity), 0)
    }
    func testClockwiseQuarterTurnAndFullTurnKeepPhysicalDimensions() {
        assertPoint(RugRotation.rotate(CGPoint(x: 10, y: 0), degrees: 90), CGPoint(x: 0, y: -10))
        XCTAssertEqual(RugRotation.canvasSize(baseSize: size, degrees: 90), CGSize(width: 440, height: 640))
        XCTAssertEqual(RugRotation.canvasSize(baseSize: size, degrees: 360), size)
        assertPoint(RugRotation.rotate(CGPoint(x: 111, y: -73), degrees: 360), CGPoint(x: 111, y: -73))
    }
    func testCanvasContainsEveryTextileCornerThroughAnEntireTurn() {
        for angle in stride(from: 0.0, through: 360.0, by: 5) {
            let canvas = RugRotation.canvasSize(baseSize: size, degrees: angle)
            for x: CGFloat in [-308, 308] { for y: CGFloat in [-208, 208] {
                let point = RugRotation.rotate(CGPoint(x: x, y: y), degrees: angle)
                XCTAssertLessThanOrEqual(abs(point.x), canvas.width / 2 - 12 + 0.00001)
                XCTAssertLessThanOrEqual(abs(point.y), canvas.height / 2 - 12 + 0.00001)
            } }
        }
    }
    func testMouseCoordinatesAndPullDirectionsReturnToClothAxes() {
        let point = CGPoint(x: 200, y: -100)
        for angle in [0.0, 17, 45, 90, 180, 270, 359, 360] {
            let canvas = RugRotation.canvasSize(baseSize: size, degrees: angle)
            let rotated = RugRotation.rotate(point, degrees: angle)
            let onScreen = CGPoint(x: rotated.x + canvas.width / 2, y: rotated.y + canvas.height / 2)
            assertPoint(RugRotation.localPoint(onScreen, in: CGRect(origin: .zero, size: canvas), degrees: angle), point)
            assertPoint(RugRotation.rotate(RugRotation.rotate(point, degrees: angle), degrees: -angle), point)
        }
    }
    func testAllEightResizeRegionsPreserveTheOppositeAnchorWhenRotated() {
        let base = CGRect(x: -400, y: 100, width: 640, height: 440)
        let regions: [ResizeEdges] = [.left, .right, .bottom, .top, [.left, .bottom], [.left, .top], [.right, .bottom], [.right, .top]]
        for angle in [0.0, 17, 45, 90, 180, 270, 359] { for edges in regions {
            let screenDelta = RugRotation.rotate(CGPoint(x: 35, y: 23), degrees: angle)
            let result = RugRotation.resizing(baseFrame: base, delta: CGSize(width: screenDelta.x, height: screenDelta.y), edges: edges, degrees: angle)
            func anchor(_ frame: CGRect) -> CGPoint {
                let x: CGFloat = edges.contains(.left) ? frame.width / 2 : (edges.contains(.right) ? -frame.width / 2 : 0)
                let y: CGFloat = edges.contains(.bottom) ? frame.height / 2 : (edges.contains(.top) ? -frame.height / 2 : 0)
                let vector = RugRotation.rotate(CGPoint(x: x, y: y), degrees: angle)
                return CGPoint(x: frame.midX + vector.x, y: frame.midY + vector.y)
            }
            assertPoint(anchor(base), anchor(result))
            let expected = RugGeometry.resizing(CGRect(origin: .zero, size: size), delta: CGSize(width: 35, height: 23), edges: edges)
            XCTAssertEqual(result.width, expected.width, accuracy: 0.000001)
            XCTAssertEqual(result.height, expected.height, accuracy: 0.000001)
        } }
    }
    func testMinimumSizeAndWindowCenterAreIndependentOfRotation() {
        let base = CGRect(x: -500, y: -100, width: 640, height: 440)
        let delta = RugRotation.rotate(CGPoint(x: 2000, y: 2000), degrees: 53)
        let result = RugRotation.resizing(baseFrame: base, delta: CGSize(width: delta.x, height: delta.y), edges: [.left, .bottom], degrees: 53)
        XCTAssertEqual(result.size, RugGeometry.minimumSize)
        let display = RugRotation.displayFrame(baseFrame: base, degrees: 53)
        XCTAssertEqual(display.midX, base.midX, accuracy: 0.5)
        XCTAssertEqual(display.midY, base.midY, accuracy: 0.5)
        XCTAssertEqual(display.minX, display.minX.rounded())
        XCTAssertEqual(display.minY, display.minY.rounded())
    }
    func testLegacyPreferencesDefaultToZeroAndRotationRoundTrips() throws {
        let legacy = try JSONDecoder().decode(RugSettings.self, from: Data(#"{"opacity":0.63,"isLocked":false}"#.utf8))
        XCTAssertEqual(legacy.rotationDegrees, 0); XCTAssertEqual(legacy.opacity, 0.63)
        let name = "com.tapetedesktop.rotation-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var value = legacy; value.rotationDegrees = 725
        value.frame = SavedFrame(CGRect(x: 30, y: 50, width: 640, height: 440))
        defaults.set(try JSONEncoder().encode(value), forKey: RugSettings.key)
        let restored = RugSettings.load(from: defaults)
        XCTAssertEqual(restored.rotationDegrees, 0)
        XCTAssertEqual(restored.frame?.rect.size, size)
        XCTAssertFalse(restored.isLocked)
    }
    func testRotationSnapsToOnlyTheFourSides() {
        for (input, expected) in [(20.0, 0.0), (45, 90), (100, 90), (170, 180), (260, 270), (359, 0), (-90, 270)] {
            XCTAssertEqual(RugRotation.quarterTurn(input), expected)
            XCTAssertTrue([0.0, 90, 180, 270].contains(RugRotation.quarterTurn(input)))
        }
        XCTAssertEqual(RugRotation.quarterTurn(.nan), 0)
        XCTAssertEqual(RugRotation.quarterTurn(.infinity), 0)
    }
    func testFourArrowClicksReturnToTheInitialSideInEitherDirection() {
        var angle = 0.0
        for expected in [90.0, 180, 270, 0] {
            angle = RugRotation.quarterTurn(angle + 90)
            XCTAssertEqual(angle, expected)
        }
        for expected in [270.0, 180, 90, 0] {
            angle = RugRotation.quarterTurn(angle - 90)
            XCTAssertEqual(angle, expected)
        }
    }
}
