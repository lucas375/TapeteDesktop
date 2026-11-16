import AppKit
import SwiftUI

/// Exercises the actual panel in an isolated preferences domain; exits without running the app.
@MainActor
enum SmokeCheck {
    struct Failure: Error, CustomStringConvertible { let description: String }
    static func run() throws {
        func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
            guard value() else { throw Failure(description: message) }
        }
        let domain = "com.tapetedesktop.smoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        let rug = RugController(defaults: defaults)
        defer { rug.shutdown(); defaults.removePersistentDomain(forName: domain) }
        try check(rug.panel.level.rawValue > Int(CGWindowLevelForKey(.desktopIconWindow)), "panel must cover desktop icons")
        try check(rug.panel.level.rawValue < NSWindow.Level.normal.rawValue, "panel must stay below normal apps")
        try check(rug.panel.collectionBehavior.contains(.canJoinAllSpaces), "all Spaces")
        try check(!rug.panel.canBecomeKey && !rug.panel.canBecomeMain, "must not steal focus")
        try check(NSApp.activationPolicy() == .accessory, "no Dock icon")
        rug.setLocked(true)
        try check(rug.panel.ignoresMouseEvents && rug.rugView.isLocked, "locked click-through")
        rug.setLocked(false)
        try check(!rug.panel.ignoresMouseEvents && !rug.rugView.isLocked, "unlocked interaction")
        rug.setOpacity(0.63)
        try check(abs(rug.panel.alphaValue - 0.63) < 0.001, "opacity")
        rug.setOpacity(-1)
        try check(rug.opacity == 0.15, "opacity minimum")
        rug.setOpacity(1)
        rug.resize(width: 760, height: 510)
        try check(rug.panel.frame.size == CGSize(width: 760, height: 510), "resize")
        rug.resize(width: 1, height: 1)
        try check(rug.panel.frame.size == RugGeometry.minimumSize, "minimum size")
        rug.resize(width: 640, height: 440)
        rug.center()
        try check(NSScreen.screens.contains { $0.visibleFrame.intersects(rug.panel.frame) }, "center")
        rug.setVisible(false)
        try check(!rug.panel.isVisible, "hide")
        rug.setVisible(true)
        try check(rug.panel.isVisible, "show")
        rug.setFullScreen(false)
        try check(rug.panel.collectionBehavior.contains(.fullScreenNone), "full screen opt-out")
        rug.setFullScreen(true)
        try check(rug.panel.collectionBehavior.contains(.fullScreenAuxiliary), "full screen auxiliary")
        rug.setPalette(.indigo); rug.setLocked(true); rug.saveNow()
        let persisted = RugSettings.load(from: defaults)
        try check(persisted.isLocked && persisted.palette == .indigo && persisted.frame?.rect == rug.settings.frame?.rect, "canonical size and position persistence")
        rug.setPalette(.wine); rug.setLocked(false)
        try check(RugTexture.hasPhotographicTexture, "bundled photographic texture")
        try check(rug.rugView.renderingError == nil, "Metal shader compilation: " + (rug.rugView.renderingError ?? ""))
        rug.setClothEnabled(false)
        try check(!rug.rugView.clothEnabled, "cloth opt-out")
        rug.setClothEnabled(true); rug.setFlexibility(1.3); rug.saveNow()
        try check(RugSettings.load(from: defaults).flexibility == 1.3, "cloth settings persistence")
        rug.flatten(); rug.setLocked(true)
        try check(!rug.rugView.isAnimating, "locking must stop animation")
        rug.setLocked(false)

        let menu = rug.rugView.makeContextMenu()
        guard let sizeMenu = menu.items.first(where: { $0.identifier?.rawValue == "tapete.size" })?.submenu,
              let small = sizeMenu.items.firstIndex(where: { $0.identifier?.rawValue == "size.small" }),
              let grow = sizeMenu.items.firstIndex(where: { $0.identifier?.rawValue == "size.grow" }),
              let custom = sizeMenu.items.firstIndex(where: { $0.identifier?.rawValue == "size.custom" }) else {
            throw Failure(description: "right-click size menu")
        }
        let originalCenter = CGPoint(x: rug.panel.frame.midX, y: rug.panel.frame.midY)
        sizeMenu.performActionForItem(at: small)
        try check(rug.panel.frame.size == CGSize(width: 480, height: 330), "right-click preset action")
        try check(CGPoint(x: rug.panel.frame.midX, y: rug.panel.frame.midY) == originalCenter, "resize must preserve center")
        sizeMenu.performActionForItem(at: grow)
        try check(abs(rug.panel.frame.width - 704) < 0.1, "right-click relative size action")
        sizeMenu.performActionForItem(at: custom)
        try check(rug.sizeEditorWindow?.isVisible == true && rug.sizeEditorWindow?.canBecomeKey == true, "custom size editor")
        try check(rug.panel.canBecomeKey == false && rug.panel.level.rawValue < 0, "editor must not change rug window behavior")
        rug.sizeEditorWindow?.orderOut(nil)
        rug.resize(width: 640, height: 440)

        let rotationCenter = CGPoint(x: rug.panel.frame.midX, y: rug.panel.frame.midY)
        let rotationMenu = rug.rugView.makeContextMenu().items.first(where: { $0.identifier?.rawValue == "tapete.rotation" })?.submenu
        guard let rotationMenu,
              let quarter = rotationMenu.items.firstIndex(where: { $0.identifier?.rawValue == "rotation.90" }),
              let editAngle = rotationMenu.items.firstIndex(where: { $0.identifier?.rawValue == "rotation.custom" }) else {
            throw Failure(description: "rotation context menu")
        }
        rotationMenu.performActionForItem(at: quarter)
        try check(rug.rotationDegrees == 90 && rug.panel.frame.size == CGSize(width: 440, height: 640), "90-degree rotation without shrinking")
        try check(rug.size == CGSize(width: 640, height: 440), "rotation preserves physical size")
        let quarterFrame = rug.panel.frame
        for expected in [180.0, 270, 0, 90] {
            rug.turnClockwise()
            try check(rug.rotationDegrees == expected, "clockwise arrow cycles the four sides")
        }
        try check(rug.panel.frame == quarterFrame, "four arrow clicks restore the same display frame")
        for expected in [0.0, 270, 180, 90] {
            rug.turnCounterclockwise()
            try check(rug.rotationDegrees == expected, "counterclockwise arrow cycles the four sides")
        }
        rug.setRotation(47)
        try check(rug.rotationDegrees == 90, "intermediate angles snap to a side")
        try check(abs(rug.panel.frame.midX - rotationCenter.x) <= 0.5 && abs(rug.panel.frame.midY - rotationCenter.y) <= 0.5, "rotation preserves center within display alignment")
        let centerPoint = rug.rugView.convert(CGPoint(x: rug.rugView.bounds.midX, y: rug.rugView.bounds.midY), to: rug.rugView.superview)
        try check(rug.rugView.hitTest(centerPoint) === rug.rugView, "rotated textile remains interactive")
        rug.saveNow()
        let restored = RugController(defaults: defaults)
        try check(restored.rotationDegrees == 90 && restored.size == rug.size && restored.panel.frame == rug.panel.frame,
                  "rotation restore: saved=\(String(describing: rug.settings.frame?.rect)) original=\(rug.panel.frame) restored=\(restored.panel.frame)")
        restored.shutdown()
        rotationMenu.performActionForItem(at: editAngle)
        try check(rug.rotationEditorWindow?.isVisible == true && rug.rotationEditorWindow?.canBecomeKey == true, "rotation editor")
        rug.rotationEditorWindow?.orderOut(nil)
        rug.setRotation(360)
        try check(rug.rotationDegrees == 0 && rug.panel.frame.size == rug.size, "full turn returns to original")

        // The default gesture only deforms cloth; moving the desktop window
        // requires Option, even if cloth animation has been disabled.
        let beforeFold = rug.panel.frame
        let beforeFoldSettings = rug.settings.frame!.rect
        let pointerStart = CGPoint(x: beforeFold.midX, y: beforeFold.midY)
        let gripPoint = CGPoint(x: rug.size.width / 2 + 120, y: rug.size.height / 2 + 60)
        rug.rugView.beginDrag(at: gripPoint, screenPoint: pointerStart)
        rug.rugView.continueDrag(at: CGPoint(x: pointerStart.x - 90, y: pointerStart.y - 40))
        for _ in 0..<24 { rug.rugView.advanceAnimation(deltaTime: 1 / 60) }
        try check(rug.panel.frame.midX == beforeFold.midX && rug.panel.frame.midY == beforeFold.midY && rug.settings.frame!.rect == beforeFoldSettings,
                  "bare mouse dragging must keep the desktop position fixed")
        try check(rug.rugView.maximumClothHeight > 20, "bare mouse dragging must deform the cloth")
        rug.rugView.endDrag()
        for _ in 0..<480 where rug.rugView.isAnimating { rug.rugView.advanceAnimation(deltaTime: 1 / 60) }
        try check(!rug.rugView.isAnimating && rug.panel.frame == beforeFold, "cloth settles without moving the window")

        for degrees in [0.0, 90, 180, 270] {
            rug.setRotation(degrees)
            let restFrame = rug.panel.frame
            let savedFrame = rug.settings.frame!.rect
            let start = CGPoint(x: restFrame.midX + 120, y: restFrame.midY + 60)
            rug.rugView.beginDrag(at: gripPoint, screenPoint: start)
            rug.rugView.continueDrag(at: CGPoint(x: start.x + 450, y: start.y + 320))
            for _ in 0..<40 { rug.rugView.advanceAnimation(deltaTime: 1 / 60) }
            try check(rug.panel.frame.width > restFrame.width || rug.panel.frame.height > restFrame.height,
                      "outward fold must expand the transparent canvas")
            try check(rug.settings.frame!.rect == savedFrame && rug.size == savedFrame.size,
                      "canvas growth must not move or resize the saved rug")
            try check(rug.panel.frame.midX == restFrame.midX && rug.panel.frame.midY == restFrame.midY,
                      "canvas growth must preserve the cloth center: rest=\(restFrame), expanded=\(rug.panel.frame), canvas=\(rug.rugView.canvasSize), rotation=\(degrees)")
            for point in rug.rugView.projectedClothPoints {
                try check(abs(point.x) < rug.panel.frame.width / 2 && abs(point.y) < rug.panel.frame.height / 2,
                          "cloth must remain inside its expanded render surface")
            }
            try check(rug.rugView.hitTest(CGPoint(x: 1, y: 1)) == nil,
                      "expanded transparent corner must not receive interactions")
            rug.rugView.endDrag()
            for _ in 0..<900 where rug.rugView.isAnimating { rug.rugView.advanceAnimation(deltaTime: 1 / 60) }
            try check(!rug.rugView.isAnimating && rug.panel.frame == restFrame,
                      "release must restore the compact canvas")
        }
        rug.setRotation(0)

        let beforeMove = rug.settings.frame!.rect
        let moveStart = CGPoint(x: rug.panel.frame.midX, y: rug.panel.frame.midY)
        rug.rugView.beginDrag(at: gripPoint, screenPoint: moveStart, modifiers: [.option])
        rug.rugView.continueDrag(at: CGPoint(x: moveStart.x + 120, y: moveStart.y + 70))
        rug.rugView.endDrag()
        let afterMove = rug.settings.frame!.rect
        try check(abs(afterMove.minX - beforeMove.minX - 120) <= 0.6 && abs(afterMove.minY - beforeMove.minY - 70) <= 0.6,
                  "Option dragging must move the window with the pointer")
        try check(!rug.rugView.isAnimating && rug.rugView.maximumClothHeight == 0, "Option moves without deforming cloth")
        rug.saveNow()
        try check(RugSettings.load(from: defaults).frame?.rect == afterMove, "Option movement persistence")

        rug.setClothEnabled(false)
        let beforeDisabled = rug.panel.frame
        rug.rugView.beginDrag(at: gripPoint, screenPoint: moveStart)
        rug.rugView.continueDrag(at: CGPoint(x: moveStart.x + 50, y: moveStart.y + 50))
        rug.rugView.endDrag()
        try check(rug.panel.frame == beforeDisabled, "disabling cloth must not enable movement without Option")
        rug.setClothEnabled(true)

        let edgeStart = CGPoint(x: rug.panel.frame.midX, y: rug.panel.frame.midY)
        rug.rugView.beginDrag(at: CGPoint(x: rug.size.width - 2, y: rug.size.height / 2), screenPoint: edgeStart)
        rug.rugView.continueDrag(at: CGPoint(x: edgeStart.x + 60, y: edgeStart.y))
        rug.rugView.endDrag()
        try check(rug.size == CGSize(width: 700, height: 440), "ordinary edge dragging still resizes")
        rug.resize(width: 640, height: 440); rug.center()

        if let i = CommandLine.arguments.firstIndex(of: "--previews"), CommandLine.arguments.count > i + 1 {
            let directory = URL(fileURLWithPath: CommandLine.arguments[i + 1], isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for palette in RugPalette.allCases {
                let image = RugArtwork.image(size: CGSize(width: 1440, height: 1000), palette: palette)
                guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else { throw Failure(description: "rug render") }
                try png.write(to: directory.appendingPathComponent("tapete-\(palette.rawValue).png"))
            }
            let surface = ClothSurface()
            var cloth = ClothSimulation(size: CGSize(width: 616, height: 416))
            func save(_ image: NSImage, _ name: String) throws {
                guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else { throw Failure(description: "cloth render") }
                try png.write(to: directory.appendingPathComponent(name))
            }
            let flat = try surface.snapshotImage(simulation: cloth, size: CGSize(width: 1280, height: 880))
            guard let tiff = flat.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else {
                throw Failure(description: "transparent rug render")
            }
            for point in [(0, 0), (bitmap.pixelsWide - 1, 0), (0, bitmap.pixelsHigh - 1), (bitmap.pixelsWide - 1, bitmap.pixelsHigh - 1)] {
                try check((bitmap.colorAt(x: point.0, y: point.1)?.alphaComponent ?? 1) < 0.01, "no opaque rectangular area")
            }
            try save(flat, "tecido-liso.png")
            surface.rotationDegrees = 45
            try save(surface.snapshotImage(simulation: cloth, size: CGSize(width: 1024, height: 1024)), "tapete-girado-45.png")
            surface.rotationDegrees = 90
            try save(surface.snapshotImage(simulation: cloth, size: CGSize(width: 880, height: 1280)), "tapete-girado-90.png")
            surface.rotationDegrees = 360
            let fullTurn = try surface.snapshotImage(simulation: cloth, size: CGSize(width: 1280, height: 880))
            try check(fullTurn.tiffRepresentation == flat.tiffRepresentation, "GPU render after 360 degrees must match original")
            surface.rotationDegrees = 0
            cloth.grab(at: SIMD2(287, 187)); cloth.drag(to: SIMD2(95, 35), lift: 145)
            for _ in 0..<90 { cloth.step(deltaTime: 1 / 60) }
            try check(cloth.maximumHeight > 100, "live cloth deformation")
            try save(surface.snapshotImage(simulation: cloth, size: CGSize(width: 1280, height: 880)), "tecido-dobrado.png")
            surface.rotationDegrees = 45
            try save(surface.snapshotImage(simulation: cloth, size: CGSize(width: 1024, height: 1024)), "tapete-dobrado-girado.png")
            surface.rotationDegrees = 0
            cloth.flatten(); cloth.grab(at: SIMD2(120, 60)); cloth.drag(to: SIMD2(570, 380), lift: 260)
            for _ in 0..<65 { cloth.step(deltaTime: 1 / 60) }
            try save(surface.snapshotImage(simulation: cloth, size: CGSize(width: 1280, height: 880)), "tecido-fora-da-area-original.png")
            print("Cloth: \(cloth.positions.count) vertices; height \(cloth.maximumHeight); reversed normals \(cloth.normals().filter { $0.z < 0 }.count).")
            let host = NSHostingView(rootView: ControlsView(rug: rug))
            host.frame = CGRect(origin: .zero, size: host.fittingSize)
            host.layoutSubtreeIfNeeded()
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try png.write(to: directory.appendingPathComponent("controles.png"))
                }
            }
            if let view = rug.sizeEditorWindow?.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try png.write(to: directory.appendingPathComponent("alterar-tamanho.png"))
                }
            }
            if let view = rug.rotationEditorWindow?.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try png.write(to: directory.appendingPathComponent("rotacao.png"))
                }
            }
        }
        print("PASS: desktop layer, Spaces, Dock, click-through, size, persistence, Metal cloth, four-side rotation, unrestricted outward folds, adaptive transparent canvas, Option-only movement, settling, disabled-cloth behavior and edge resizing.")
    }
}
