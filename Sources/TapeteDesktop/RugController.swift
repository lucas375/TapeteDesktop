import AppKit
import Combine
import SwiftUI

@MainActor
final class RugPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor
final class RugController: ObservableObject {
    @Published private(set) var settings: RugSettings
    @Published private(set) var size: CGSize
    let panel: RugPanel
    let rugView = RugView()
    private(set) var sizeEditorWindow: NSPanel?
    private(set) var rotationEditorWindow: NSPanel?
    private let defaults: UserDefaults
    private var pendingSave: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?

    var opacity: Double { settings.opacity }
    var isLocked: Bool { settings.isLocked }
    var isVisible: Bool { settings.isVisible }
    var palette: RugPalette { settings.palette }
    var rotationDegrees: Double { settings.rotationDegrees }
    var orientation: RugOrientation { RugOrientation.current(degrees: rotationDegrees) }
    private var baseFrame: CGRect {
        settings.frame?.rect ?? RugRotation.baseFrame(center: CGPoint(x: panel.frame.midX, y: panel.frame.midY), size: size)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = RugSettings.load(from: defaults)
        settings = saved
        let screens = NSScreen.screens.map(\.visibleFrame)
        let primary = screens.first ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let initial = saved.frame?.rect ?? RugGeometry.centered(size: CGSize(width: 640, height: 440), on: primary)
        let frame = RugGeometry.recovered(initial, screens: screens)
        size = frame.size
        let display = RugRotation.displayFrame(baseFrame: frame, degrees: saved.rotationDegrees)
        panel = RugPanel(contentRect: display, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "TapeteDesktop"
        panel.identifier = NSUserInterfaceItemIdentifier("TapeteDesktop.rug")
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false; panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false; panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.minSize = RugRotation.canvasSize(baseSize: RugGeometry.minimumSize, degrees: saved.rotationDegrees)
        rugView.baseSize = frame.size
        rugView.rotationDegrees = saved.rotationDegrees
        rugView.frame = CGRect(origin: .zero, size: display.size)
        rugView.autoresizingMask = [.width, .height]
        rugView.setAccessibilityElement(true)
        rugView.setAccessibilityLabel("Tapete decorativo. Arraste sem teclado para dobrar o tecido no lugar. Option e arrastar para mover pela Mesa. Shift e Option e arrastar para girar. Botão direito para tamanho e rotação. Bordas para redimensionar. Dois cliques para alisar.")
        panel.contentView = rugView
        rugView.onFrameChanged = { [weak self] frame in self?.applyBaseFrame(frame) }
        rugView.onCanvasChanged = { [weak self] in self?.updateCanvas() }
        rugView.onDragEnded = { [weak self] in self?.recoverPosition() }
        rugView.onLock = { [weak self] in self?.setLocked(true) }
        rugView.onResize = { [weak self] size in self?.resize(width: size.width, height: size.height) }
        rugView.onEditSize = { [weak self] in self?.showSizeEditor() }
        rugView.onRotate = { [weak self] in self?.setRotation($0) }
        rugView.onEditRotation = { [weak self] in self?.showRotationEditor() }
        configureLayer()
        applyAppearance()
        record(frame)
        if saved.isVisible { panel.orderFrontRegardless() }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.recoverPosition() }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                                         object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isVisible else { return }
                self.configureLayer()
                self.panel.orderFrontRegardless()
            }
        }
    }

    private func configureLayer() {
        // Dynamically derive the level: above Finder's icons, below normal app windows.
        let desktopIcons = CGWindowLevelForKey(.desktopIconWindow)
        panel.level = NSWindow.Level(rawValue: Int(desktopIcons) + 1)
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if settings.joinsFullScreen { behavior.insert(.fullScreenAuxiliary) }
        else { behavior.insert(.fullScreenNone) }
        panel.collectionBehavior = behavior
    }

    private func applyAppearance() {
        panel.alphaValue = settings.opacity
        panel.ignoresMouseEvents = settings.isLocked
        rugView.palette = settings.palette
        rugView.isLocked = settings.isLocked
        rugView.clothEnabled = settings.clothEnabled
        rugView.flexibility = Float(settings.flexibility)
        rugView.rotationDegrees = settings.rotationDegrees
    }

    func setOpacity(_ value: Double) {
        guard value.isFinite else { return }
        settings.opacity = min(1, max(0.15, value))
        panel.alphaValue = settings.opacity; scheduleSave()
    }
    func setLocked(_ value: Bool) {
        settings.isLocked = value; applyAppearance(); scheduleSave()
    }
    func setClothEnabled(_ value: Bool) {
        settings.clothEnabled = value; rugView.clothEnabled = value; scheduleSave()
    }
    func setFlexibility(_ value: Double) {
        guard value.isFinite else { return }
        settings.flexibility = min(1.6, max(0.5, value))
        rugView.flexibility = Float(settings.flexibility); scheduleSave()
    }
    func flatten() { rugView.flatten() }
    func setRotation(_ degrees: Double) {
        guard degrees.isFinite else { return }
        let frame = baseFrame
        settings.rotationDegrees = RugRotation.quarterTurn(degrees)
        applyBaseFrame(frame)
    }
    func turnClockwise() { setRotation(rotationDegrees + 90) }
    func turnCounterclockwise() { setRotation(rotationDegrees - 90) }
    func setPalette(_ value: RugPalette) {
        settings.palette = value; rugView.palette = value; scheduleSave()
    }
    func setVisible(_ value: Bool) {
        settings.isVisible = value
        if value { recoverPosition(); configureLayer(); panel.orderFrontRegardless() }
        else { rugView.suspendAnimation(); panel.orderOut(nil) }
        scheduleSave()
    }
    func setFullScreen(_ value: Bool) {
        settings.joinsFullScreen = value; configureLayer(); scheduleSave()
    }
    func center() {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? panel.screen ?? NSScreen.main
        guard let screen else { return }
        let frame = RugRotation.baseFrame(center: CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY), size: size)
        applyBaseFrame(frame)
    }
    func resize(width: Double? = nil, height: Double? = nil) {
        rugView.flatten()
        var frame = baseFrame
        let newWidth = width.flatMap { $0.isFinite ? $0 : nil } ?? frame.width
        let newHeight = height.flatMap { $0.isFinite ? $0 : nil } ?? frame.height
        let newSize = CGSize(width: min(16_000, max(RugGeometry.minimumSize.width, newWidth)),
                             height: min(16_000, max(RugGeometry.minimumSize.height, newHeight)))
        frame.origin.x += (frame.width - newSize.width) / 2
        frame.origin.y += (frame.height - newSize.height) / 2
        frame.size = newSize
        applyBaseFrame(frame); recoverPosition()
    }
    func showSizeEditor() {
        rugView.flatten()
        let editor = sizeEditorWindow ?? NSPanel(contentRect: CGRect(x: 0, y: 0, width: 360, height: 230),
                                                styleMask: [.titled, .closable, .utilityWindow],
                                                backing: .buffered, defer: false)
        editor.title = "Alterar tamanho do tapete"
        editor.appearance = NSAppearance(named: .aqua)
        editor.identifier = NSUserInterfaceItemIdentifier("TapeteDesktop.sizeEditor")
        editor.isReleasedWhenClosed = false
        editor.hidesOnDeactivate = false
        editor.level = .floating
        editor.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let view = SizeEditorView(size: size, apply: { [weak self] size in
            self?.resize(width: size.width, height: size.height)
            self?.sizeEditorWindow?.orderOut(nil)
        }, cancel: { [weak self] in self?.sizeEditorWindow?.orderOut(nil) })
        let host = NSHostingController(rootView: view)
        editor.contentViewController = host
        editor.setContentSize(host.view.fittingSize)
        sizeEditorWindow = editor
        editor.center()
        NSApp.activate(ignoringOtherApps: true)
        editor.makeKeyAndOrderFront(nil)
    }
    func showRotationEditor() {
        let editor = rotationEditorWindow ?? NSPanel(contentRect: CGRect(x: 0, y: 0, width: 370, height: 250),
                                                    styleMask: [.titled, .closable, .utilityWindow],
                                                    backing: .buffered, defer: false)
        editor.title = "Rotação do tapete"
        editor.identifier = NSUserInterfaceItemIdentifier("TapeteDesktop.rotationEditor")
        editor.appearance = NSAppearance(named: .aqua)
        editor.isReleasedWhenClosed = false; editor.hidesOnDeactivate = false
        editor.level = .floating
        editor.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingController(rootView: RotationEditorView(rug: self, close: { [weak self] in
            self?.rotationEditorWindow?.orderOut(nil)
        }))
        editor.contentViewController = host; editor.setContentSize(host.view.fittingSize)
        rotationEditorWindow = editor; editor.center()
        NSApp.activate(ignoringOtherApps: true); editor.makeKeyAndOrderFront(nil)
    }
    func move(dx: CGFloat, dy: CGFloat) {
        let frame = baseFrame.offsetBy(dx: dx, dy: dy)
        applyBaseFrame(frame); recoverPosition()
    }
    func recoverPosition() {
        let frame = RugGeometry.recovered(baseFrame, screens: NSScreen.screens.map(\.visibleFrame))
        applyBaseFrame(frame)
    }
    private func applyBaseFrame(_ frame: CGRect) {
        rugView.baseSize = frame.size
        rugView.rotationDegrees = settings.rotationDegrees
        panel.minSize = RugRotation.canvasSize(baseSize: RugGeometry.minimumSize, degrees: settings.rotationDegrees)
        let display = RugRotation.displayFrame(baseFrame: frame, degrees: settings.rotationDegrees, expandedCanvas: rugView.canvasSize)
        panel.setFrame(display, display: true)
        panel.invalidateCursorRects(for: rugView)
        record(frame)
    }
    private func updateCanvas() {
        let display = RugRotation.displayFrame(baseFrame: baseFrame, degrees: settings.rotationDegrees, expandedCanvas: rugView.canvasSize)
        guard panel.frame != display else { return }
        panel.setFrame(display, display: true)
        rugView.layoutSubtreeIfNeeded()
        panel.invalidateCursorRects(for: rugView)
    }
    private func record(_ frame: CGRect) {
        settings.frame = SavedFrame(frame); size = frame.size; scheduleSave()
    }
    private func scheduleSave() {
        pendingSave?.cancel()
        let job = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = job
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: job)
    }
    func saveNow() {
        pendingSave?.cancel(); pendingSave = nil
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: RugSettings.key) }
    }
    func shutdown() {
        rotationEditorWindow?.close(); rotationEditorWindow = nil
        sizeEditorWindow?.close(); sizeEditorWindow = nil
        rugView.suspendAnimation()
        saveNow()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        panel.orderOut(nil)
    }
}
