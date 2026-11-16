import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let rug: RugController
    private let item: NSStatusItem
    private let popover = NSPopover()

    init(rug: RugController) {
        self.rug = rug
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = item.button {
            button.image = Self.menuImage()
            button.toolTip = "TapeteDesktop — controlar tapete"
            button.setAccessibilityLabel("TapeteDesktop")
            button.target = self; button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: ControlsView(rug: rug, close: { [weak self] in self?.popover.performClose(nil) }))
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu(); return }
        if popover.isShown { popover.performClose(nil); return }
        guard let button = item.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(RugSizeMenu.item(currentSize: rug.size, resize: { [weak self] size in
            self?.rug.resize(width: size.width, height: size.height)
        }, custom: { [weak self] in self?.rug.showSizeEditor() }))
        menu.addItem(RugRotationMenu.item(degrees: rug.rotationDegrees, rotate: { [weak self] in
            self?.rug.setRotation($0)
        }, custom: { [weak self] in self?.rug.showRotationEditor() }))
        menu.addItem(.separator())
        let entries: [(String, Selector, String)] = [
            (rug.isVisible ? "Ocultar tapete" : "Mostrar tapete", #selector(toggleVisible), ""),
            (rug.isLocked ? "Destravar tapete" : "Travar tapete", #selector(toggleLock), ""),
            ("Centralizar", #selector(center), ""),
            ("Alisar tapete", #selector(flatten), "")
        ]
        for (title, action, key) in entries {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
            entry.target = self; menu.addItem(entry)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Encerrar TapeteDesktop", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        item.menu = menu; item.button?.performClick(nil); item.menu = nil
    }
    @objc private func toggleVisible() { rug.setVisible(!rug.isVisible) }
    @objc private func toggleLock() { rug.setLocked(!rug.isLocked) }
    @objc private func flatten() { rug.flatten() }
    @objc private func center() { rug.center() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    private static func menuImage() -> NSImage {
        let image = NSImage(size: CGSize(width: 22, height: 22), flipped: false) { _ in
            NSColor.black.setStroke()
            let outline = NSBezierPath(roundedRect: NSRect(x: 4, y: 5, width: 14, height: 12), xRadius: 0.7, yRadius: 0.7)
            outline.lineWidth = 1.2; outline.stroke()
            let detail = NSBezierPath()
            detail.move(to: NSPoint(x: 11, y: 7)); detail.line(to: NSPoint(x: 15, y: 11))
            detail.line(to: NSPoint(x: 11, y: 15)); detail.line(to: NSPoint(x: 7, y: 11)); detail.close()
            for x in stride(from: CGFloat(5), through: CGFloat(17), by: 3) {
                detail.move(to: NSPoint(x: x, y: 2.5)); detail.line(to: NSPoint(x: x, y: 5))
                detail.move(to: NSPoint(x: x, y: 17)); detail.line(to: NSPoint(x: x, y: 19.5))
            }
            detail.lineWidth = 1; detail.stroke(); return true
        }
        image.isTemplate = true; return image
    }
}
