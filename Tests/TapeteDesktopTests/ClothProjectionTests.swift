import XCTest
import simd
@testable import TapeteDesktop

final class ClothProjectionTests: XCTestCase {
    func testExpansionPreservesFractionalRestAnchorAcrossScreenZero() {
        let base = CGRect(x: 535, y: 353.5, width: 640, height: 440)
        let rest = RugRotation.displayFrame(baseFrame: base, degrees: 180)
        let expanded = RugRotation.displayFrame(baseFrame: base, degrees: 180, expandedCanvas: CGSize(width: 1216, height: 1208))
        XCTAssertLessThan(expanded.minY, 0)
        XCTAssertEqual(rest.midX, expanded.midX)
        XCTAssertEqual(rest.midY, expanded.midY)
    }
    func testExpandedCanvasContainsOutwardFoldsAndShadowsAtEverySide() {
        let base = CGSize(width: 640, height: 440)
        let points: [SIMD3<Float>] = [SIMD3(-600, -450, 270), SIMD3(650, 470, 240), SIMD3(-308, 208, 0)]
        for degrees in [0.0, 90, 180, 270] {
            let canvas = ClothProjection.canvasSize(positions: points, baseSize: base, degrees: degrees)
            let original = RugRotation.canvasSize(baseSize: base, degrees: degrees)
            XCTAssertGreaterThan(canvas.width, original.width)
            XCTAssertGreaterThan(canvas.height, original.height)
            for position in points {
                for point in [ClothProjection.textile(position, degrees: degrees), ClothProjection.shadow(position, degrees: degrees)] {
                    XCTAssertLessThan(abs(point.x) + 2, canvas.width / 2)
                    XCTAssertLessThan(abs(point.y) + 2, canvas.height / 2)
                }
            }
            let frame = CGRect(x: 100, y: 200, width: 640, height: 440)
            let rest = RugRotation.displayFrame(baseFrame: frame, degrees: degrees)
            let expanded = RugRotation.displayFrame(baseFrame: frame, degrees: degrees, expandedCanvas: canvas)
            XCTAssertEqual(rest.midX, expanded.midX)
            XCTAssertEqual(rest.midY, expanded.midY)
        }
        let cloth = ClothSimulation(size: CGSize(width: 616, height: 416))
        XCTAssertEqual(ClothProjection.canvasSize(positions: cloth.rest, baseSize: base, degrees: 0), base)
    }
}
