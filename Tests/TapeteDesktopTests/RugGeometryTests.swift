import XCTest
@testable import TapeteDesktop

final class RugGeometryTests: XCTestCase {
    private let frame = CGRect(x: 100, y: 200, width: 640, height: 440)

    func testEveryEdgeAndCornerResizesWithOppositeAnchor() {
        let d = CGSize(width: 45, height: 30)
        let cases: [(ResizeEdges, CGRect)] = [
            (.left, CGRect(x: 145, y: 200, width: 595, height: 440)),
            (.right, CGRect(x: 100, y: 200, width: 685, height: 440)),
            (.bottom, CGRect(x: 100, y: 230, width: 640, height: 410)),
            (.top, CGRect(x: 100, y: 200, width: 640, height: 470)),
            ([.left, .bottom], CGRect(x: 145, y: 230, width: 595, height: 410)),
            ([.left, .top], CGRect(x: 145, y: 200, width: 595, height: 470)),
            ([.right, .bottom], CGRect(x: 100, y: 230, width: 685, height: 410)),
            ([.right, .top], CGRect(x: 100, y: 200, width: 685, height: 470))
        ]
        for (edges, expected) in cases {
            XCTAssertEqual(RugGeometry.resizing(frame, delta: d, edges: edges), expected)
        }
    }
    func testCrossingOppositeEdgePreservesAnchorAtMinimumSize() {
        let result = RugGeometry.resizing(frame, delta: CGSize(width: 2_000, height: 2_000), edges: [.left, .bottom])
        XCTAssertEqual(result.size, RugGeometry.minimumSize)
        XCTAssertEqual(result.maxX, frame.maxX); XCTAssertEqual(result.maxY, frame.maxY)
    }
    func testNegativeResizeAndNoEdges() {
        let result = RugGeometry.resizing(frame, delta: CGSize(width: -2_000, height: -2_000), edges: [.right, .top])
        XCTAssertEqual(result.size, RugGeometry.minimumSize)
        XCTAssertEqual(result.origin, frame.origin)
        XCTAssertEqual(RugGeometry.resizing(frame, delta: CGSize(width: 50, height: 50), edges: []), frame)
    }
    func testHitRegionsForEdgesCornersAndCenter() {
        let bounds = CGRect(origin: .zero, size: frame.size)
        XCTAssertEqual(RugGeometry.edges(at: CGPoint(x: 0, y: 0), in: bounds), [.left, .bottom])
        XCTAssertEqual(RugGeometry.edges(at: CGPoint(x: 640, y: 440), in: bounds), [.right, .top])
        XCTAssertEqual(RugGeometry.edges(at: CGPoint(x: 0, y: 200), in: bounds), .left)
        XCTAssertEqual(RugGeometry.edges(at: CGPoint(x: 320, y: 440), in: bounds), .top)
        XCTAssertTrue(RugGeometry.edges(at: CGPoint(x: 320, y: 220), in: bounds).isEmpty)
    }
    func testDisconnectedMonitorRecoversOnVisibleScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let lost = frame.offsetBy(dx: -5_000, dy: 2_000)
        XCTAssertEqual(RugGeometry.recovered(lost, screens: [screen]), RugGeometry.centered(size: frame.size, on: screen))
    }
    func testNegativeMonitorOriginAndSpanningDisplaysArePreserved() {
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: -1920, y: -200, width: 1920, height: 1080)]
        let left = CGRect(x: -1_500, y: -100, width: 640, height: 440)
        XCTAssertEqual(RugGeometry.recovered(left, screens: screens), left)
        let spanning = CGRect(x: -200, y: 100, width: 640, height: 440)
        XCTAssertEqual(RugGeometry.recovered(spanning, screens: screens), spanning)
    }
    func testCenterFitsSmallDisplay() {
        let screen = CGRect(x: -800, y: 50, width: 800, height: 600)
        XCTAssertEqual(RugGeometry.centered(size: CGSize(width: 4_000, height: 3_000), on: screen), screen)
    }
    func testInvalidAndCorruptPreferencesRecover() throws {
        let name = "com.tapetedesktop.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("invalid json".utf8), forKey: RugSettings.key)
        XCTAssertEqual(RugSettings.load(from: defaults).opacity, 1)
        var saved = RugSettings(); saved.opacity = -3; saved.frame = SavedFrame(CGRect(x: 0, y: 0, width: -1, height: 400))
        defaults.set(try JSONEncoder().encode(saved), forKey: RugSettings.key)
        let restored = RugSettings.load(from: defaults)
        XCTAssertEqual(restored.opacity, 0.15); XCTAssertNil(restored.frame)
        XCTAssertFalse(RugGeometry.isValid(CGRect(x: Double.infinity, y: 0, width: 500, height: 400)))
    }
}
