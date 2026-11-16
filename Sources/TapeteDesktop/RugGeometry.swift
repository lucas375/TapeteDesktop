import Foundation

struct ResizeEdges: OptionSet {
    let rawValue: Int
    static let left = ResizeEdges(rawValue: 1 << 0)
    static let right = ResizeEdges(rawValue: 1 << 1)
    static let bottom = ResizeEdges(rawValue: 1 << 2)
    static let top = ResizeEdges(rawValue: 1 << 3)
}

/// Screen coordinates are AppKit coordinates, including negative monitor origins.
enum RugGeometry {
    static let minimumSize = CGSize(width: 240, height: 180)
    static let handleWidth: CGFloat = 14

    static func edges(at point: CGPoint, in bounds: CGRect) -> ResizeEdges {
        var result: ResizeEdges = []
        if point.x <= bounds.minX + handleWidth { result.insert(.left) }
        else if point.x >= bounds.maxX - handleWidth { result.insert(.right) }
        if point.y <= bounds.minY + handleWidth { result.insert(.bottom) }
        else if point.y >= bounds.maxY - handleWidth { result.insert(.top) }
        return result
    }

    static func resizing(_ frame: CGRect, delta: CGSize, edges: ResizeEdges) -> CGRect {
        var result = frame
        if edges.contains(.left) {
            let width = max(minimumSize.width, frame.width - delta.width)
            result.origin.x = frame.maxX - width
            result.size.width = width
        } else if edges.contains(.right) {
            result.size.width = max(minimumSize.width, frame.width + delta.width)
        }
        if edges.contains(.bottom) {
            let height = max(minimumSize.height, frame.height - delta.height)
            result.origin.y = frame.maxY - height
            result.size.height = height
        } else if edges.contains(.top) {
            result.size.height = max(minimumSize.height, frame.height + delta.height)
        }
        return result
    }

    static func isValid(_ frame: CGRect) -> Bool {
        [frame.origin.x, frame.origin.y, frame.width, frame.height].allSatisfy { $0.isFinite }
            && frame.width >= minimumSize.width && frame.height >= minimumSize.height
            && frame.width < 30_000 && frame.height < 30_000
    }

    static func centered(size: CGSize, on screen: CGRect) -> CGRect {
        let size = CGSize(width: min(size.width, screen.width), height: min(size.height, screen.height))
        return CGRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// Keep intentional overlap between displays; recover a disconnected display's rug.
    static func recovered(_ frame: CGRect, screens: [CGRect]) -> CGRect {
        guard let fallback = screens.first else { return frame }
        let valid = isValid(frame) ? frame : centered(size: CGSize(width: 640, height: 440), on: fallback)
        if screens.contains(where: {
            let overlap = valid.intersection($0)
            return !overlap.isNull && overlap.width >= 80 && overlap.height >= 80
        }) { return valid }
        let target = screens.max {
            distance(from: valid, to: $0) > distance(from: valid, to: $1)
        } ?? fallback
        return centered(size: valid.size, on: target)
    }

    private static func distance(from frame: CGRect, to screen: CGRect) -> CGFloat {
        let dx = frame.midX - screen.midX
        let dy = frame.midY - screen.midY
        return dx * dx + dy * dy
    }
}

struct SavedFrame: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    init(_ frame: CGRect) {
        x = frame.minX; y = frame.minY; width = frame.width; height = frame.height
    }
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct RugSettings: Codable {
    var frame: SavedFrame?
    var opacity = 1.0
    var isLocked = false
    var isVisible = true
    var palette = RugPalette.wine
    var joinsFullScreen = true
    var clothEnabled = true
    var flexibility = 1.0
    var rotationDegrees = 0.0

    init() {}
    private enum CodingKeys: String, CodingKey {
        case frame, opacity, isLocked, isVisible, palette, joinsFullScreen, clothEnabled, flexibility, rotationDegrees
    }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        frame = try values.decodeIfPresent(SavedFrame.self, forKey: .frame)
        opacity = try values.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        isLocked = try values.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isVisible = try values.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        palette = try values.decodeIfPresent(RugPalette.self, forKey: .palette) ?? .wine
        joinsFullScreen = try values.decodeIfPresent(Bool.self, forKey: .joinsFullScreen) ?? true
        clothEnabled = try values.decodeIfPresent(Bool.self, forKey: .clothEnabled) ?? true
        flexibility = try values.decodeIfPresent(Double.self, forKey: .flexibility) ?? 1
        rotationDegrees = try values.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
    }

    static let key = "TapeteDesktop.settings.v1"
    static func load(from defaults: UserDefaults) -> RugSettings {
        guard let data = defaults.data(forKey: key),
              var value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        value.opacity = value.opacity.isFinite ? min(1, max(0.15, value.opacity)) : 1
        value.flexibility = value.flexibility.isFinite ? min(1.6, max(0.5, value.flexibility)) : 1
        value.rotationDegrees = RugRotation.quarterTurn(value.rotationDegrees)
        if let frame = value.frame, !RugGeometry.isValid(frame.rect) { value.frame = nil }
        return value
    }
}
