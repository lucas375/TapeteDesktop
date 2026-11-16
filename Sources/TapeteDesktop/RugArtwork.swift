import AppKit

/// Original vector ornament: no external image, download, or file access.
enum RugPalette: String, Codable, CaseIterable, Identifiable {
    case wine, indigo, moss
    var id: String { rawValue }
    var title: String {
        switch self { case .wine: return "Vinho"; case .indigo: return "Índigo"; case .moss: return "Oliva" }
    }
    var colors: RugColors {
        switch self {
        case .wine: return RugColors(field: 0x7A2634, dark: 0x202E3E, light: 0xDCC89C, accent: 0xB96F51, muted: 0x577573)
        case .indigo: return RugColors(field: 0x253E58, dark: 0x182731, light: 0xDDCDA9, accent: 0xAF6758, muted: 0x688D91)
        case .moss: return RugColors(field: 0x4B5B48, dark: 0x273632, light: 0xDED0AD, accent: 0xAF7658, muted: 0x8A9B7A)
        }
    }
}

struct RugColors {
    let field: Int
    let dark: Int
    let light: Int
    let accent: Int
    let muted: Int
    func color(_ rgb: Int, alpha: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255, alpha: alpha)
    }
}

@MainActor
enum RugArtwork {
    static func draw(in context: CGContext, bounds: CGRect, palette: RugPalette) {
        let c = palette.colors
        context.saveGState()
        context.translateBy(x: bounds.minX, y: bounds.minY)
        context.scaleBy(x: bounds.width / 720, y: bounds.height / 500)
        context.setAllowsAntialiasing(true)
        let body = CGRect(x: 11, y: 17, width: 698, height: 466)

        // Fringe is inset inside the hit area, with individually drawn cotton threads.
        for i in 0..<147 {
            let x = CGFloat(i) * 4.65 + 20
            let variation = CGFloat((i * 17) % 9) / 2
            context.setStrokeColor(c.color(c.light, alpha: 0.88))
            context.setLineWidth(i.isMultiple(of: 3) ? 2.1 : 1.35)
            context.move(to: CGPoint(x: x, y: 18))
            context.addLine(to: CGPoint(x: x - 1.5, y: 3 + variation))
            context.move(to: CGPoint(x: x, y: 482))
            context.addLine(to: CGPoint(x: x + 1.5, y: 497 - variation))
            context.strokePath()
        }
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 5, color: CGColor(gray: 0, alpha: 0.26))
        fill(body, c.color(c.dark), context)
        context.restoreGState()
        context.saveGState()
        context.clip(to: body)

        fill(body.insetBy(dx: 4, dy: 4), c.color(c.light), context)
        fill(body.insetBy(dx: 8, dy: 8), c.color(c.field), context)
        fill(body.insetBy(dx: 13, dy: 13), c.color(c.light), context)
        fill(body.insetBy(dx: 19, dy: 19), c.color(c.dark), context)
        fill(body.insetBy(dx: 49, dy: 49), c.color(c.light), context)
        fill(body.insetBy(dx: 54, dy: 54), c.color(c.accent), context)
        fill(body.insetBy(dx: 59, dy: 59), c.color(c.dark), context)
        let field = body.insetBy(dx: 66, dy: 66)
        fill(field, c.color(c.field), context)

        // Continuous floral guard border on all four sides.
        for index in 0..<20 {
            let x = 42 + CGFloat(index) * 33.5
            flower(at: CGPoint(x: x, y: 52), radius: 9, colors: c, context: context)
            flower(at: CGPoint(x: x, y: 448), radius: 9, colors: c, context: context)
            if index < 11 {
                let y = 84 + CGFloat(index) * 33
                flower(at: CGPoint(x: 46, y: y), radius: 9, colors: c, context: context)
                flower(at: CGPoint(x: 674, y: y), radius: 9, colors: c, context: context)
            }
        }
        context.setLineWidth(1)
        context.setStrokeColor(c.color(c.light, alpha: 0.42))
        for i in 0..<36 {
            let x = 25 + CGFloat(i) * 19
            context.stroke(CGRect(x: x, y: 27, width: 9, height: 4))
            context.stroke(CGRect(x: x, y: 469, width: 9, height: 4))
        }

        // Mirrored corner spandrels.
        for sx: CGFloat in [-1, 1] {
            for sy: CGFloat in [-1, 1] {
                context.saveGState()
                context.translateBy(x: 360, y: 250)
                context.scaleBy(x: sx, y: sy)
                polygon([CGPoint(x: 283, y: 167), CGPoint(x: 283, y: 72),
                         CGPoint(x: 250, y: 85), CGPoint(x: 234, y: 110),
                         CGPoint(x: 200, y: 122), CGPoint(x: 187, y: 167)],
                        fill: c.color(c.dark), stroke: c.color(c.light), width: 2, context: context)
                flower(at: CGPoint(x: 254, y: 141), radius: 15, colors: c, context: context)
                leaf(from: CGPoint(x: 231, y: 145), to: CGPoint(x: 216, y: 157), color: c.color(c.muted), context: context)
                context.restoreGState()
            }
        }

        // Repeating boteh and small blooms surround the central medallion.
        for row in 0..<7 {
            for col in 0..<12 {
                let x = 105 + CGFloat(col) * 46.5
                let y = 105 + CGFloat(row) * 48
                let dx = abs(x - 360) / 160
                let dy = abs(y - 250) / 136
                guard dx + dy > 1.22 else { continue }
                let cornerX = abs(x - 360), cornerY = abs(y - 250)
                guard cornerX < 208 || cornerY < 102 else { continue }
                context.saveGState()
                context.translateBy(x: x, y: y)
                if (row + col).isMultiple(of: 2) { context.scaleBy(x: -1, y: 1) }
                let stem = CGMutablePath()
                stem.move(to: CGPoint(x: -5, y: -12))
                stem.addCurve(to: CGPoint(x: 2, y: 12), control1: CGPoint(x: 11, y: -2), control2: CGPoint(x: -8, y: 7))
                context.addPath(stem)
                context.setStrokeColor(c.color(c.light, alpha: 0.78)); context.setLineWidth(1.3); context.strokePath()
                leaf(from: .zero, to: CGPoint(x: 12, y: 5), color: c.color(c.muted), context: context)
                flower(at: CGPoint(x: -1, y: 12), radius: 4.5, colors: c, context: context)
                context.restoreGState()
            }
        }

        // Layered, stepped Persian medallion and pendant palmettes.
        medallion(center: CGPoint(x: 360, y: 250), radius: CGSize(width: 157, height: 132),
                  fill: c.color(c.light), stroke: c.color(c.dark), context: context)
        medallion(center: CGPoint(x: 360, y: 250), radius: CGSize(width: 143, height: 120),
                  fill: c.color(c.dark), stroke: c.color(c.accent), context: context)
        medallion(center: CGPoint(x: 360, y: 250), radius: CGSize(width: 112, height: 94),
                  fill: c.color(c.muted), stroke: c.color(c.light), context: context)
        medallion(center: CGPoint(x: 360, y: 250), radius: CGSize(width: 94, height: 79),
                  fill: c.color(c.field), stroke: c.color(c.light), context: context)
        for direction: CGFloat in [-1, 1] {
            flower(at: CGPoint(x: 360 + direction * 179, y: 250), radius: 16, colors: c, context: context)
            flower(at: CGPoint(x: 360, y: 250 + direction * 146), radius: 12, colors: c, context: context)
            for offset: CGFloat in [-1, 1] {
                flower(at: CGPoint(x: 360 + direction * 62, y: 250 + offset * 34), radius: 9, colors: c, context: context)
            }
        }
        flower(at: CGPoint(x: 360, y: 250), radius: 29, colors: c, context: context)
        flower(at: CGPoint(x: 360, y: 250), radius: 13, colors: c, context: context)

        // Low contrast woven warp and weft, deterministic and inexpensive to redraw.
        context.setLineWidth(0.55)
        for i in 0..<310 {
            let y = 18 + CGFloat(i) * 1.5
            context.setStrokeColor(c.color(i.isMultiple(of: 3) ? c.light : c.dark, alpha: 0.105))
            context.move(to: CGPoint(x: 11, y: y)); context.addLine(to: CGPoint(x: 709, y: y)); context.strokePath()
        }
        for i in 0..<350 {
            let x = 12 + CGFloat(i) * 2
            context.setStrokeColor(c.color(c.light, alpha: i.isMultiple(of: 4) ? 0.065 : 0.025))
            context.move(to: CGPoint(x: x, y: 17)); context.addLine(to: CGPoint(x: x, y: 483)); context.strokePath()
        }
        context.restoreGState()
        context.restoreGState()
    }

    private static func fill(_ rect: CGRect, _ color: CGColor, _ context: CGContext) {
        context.setFillColor(color); context.fill(rect)
    }
    private static func polygon(_ points: [CGPoint], fill: CGColor, stroke: CGColor, width: CGFloat, context: CGContext) {
        guard let first = points.first else { return }
        context.beginPath(); context.move(to: first)
        for point in points.dropFirst() { context.addLine(to: point) }
        context.closePath(); context.setFillColor(fill); context.setStrokeColor(stroke)
        context.setLineWidth(width); context.drawPath(using: .fillStroke)
    }
    private static func medallion(center: CGPoint, radius: CGSize, fill: CGColor, stroke: CGColor, context: CGContext) {
        let points: [CGPoint] = (0..<32).map { i in
            let angle = CGFloat(i) * .pi / 16
            let length: CGFloat = i.isMultiple(of: 2) ? 1 : 0.84
            return CGPoint(x: center.x + cos(angle) * radius.width * length,
                           y: center.y + sin(angle) * radius.height * length)
        }
        polygon(points, fill: fill, stroke: stroke, width: 1.7, context: context)
    }
    private static func flower(at center: CGPoint, radius: CGFloat, colors c: RugColors, context: CGContext) {
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let x = center.x + cos(angle) * radius * 0.59
            let y = center.y + sin(angle) * radius * 0.59
            context.setFillColor(c.color(i.isMultiple(of: 2) ? c.light : c.accent))
            context.fillEllipse(in: CGRect(x: x - radius * 0.29, y: y - radius * 0.29,
                                          width: radius * 0.58, height: radius * 0.58))
        }
        context.setFillColor(c.color(c.dark))
        context.fillEllipse(in: CGRect(x: center.x - radius * 0.32, y: center.y - radius * 0.32,
                                      width: radius * 0.64, height: radius * 0.64))
        context.setFillColor(c.color(c.light))
        context.fillEllipse(in: CGRect(x: center.x - radius * 0.12, y: center.y - radius * 0.12,
                                      width: radius * 0.24, height: radius * 0.24))
    }
    private static func leaf(from a: CGPoint, to b: CGPoint, color: CGColor, context: CGContext) {
        let path = CGMutablePath(); path.move(to: a)
        path.addQuadCurve(to: b, control: CGPoint(x: b.x, y: a.y - 6))
        path.addQuadCurve(to: a, control: CGPoint(x: a.x, y: b.y + 6))
        context.addPath(path); context.setFillColor(color); context.fillPath()
    }

    static func image(size: CGSize, palette: RugPalette) -> NSImage {
        RugTexture.image(palette: palette)
    }
}
