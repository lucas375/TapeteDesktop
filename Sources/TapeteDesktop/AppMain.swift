import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var rug: RugController?
    private var statusBar: StatusBarController?
    private var instanceObserver: NSObjectProtocol?
    private let notification = Notification.Name("com.tapetedesktop.app.reveal")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            DistributedNotificationCenter.default().post(name: self.notification, object: nil)
            NSApp.terminate(nil)
            return
        }
        let controller = RugController()
        rug = controller; statusBar = StatusBarController(rug: controller)
        if CommandLine.arguments.contains("--show-size-editor") {
            DispatchQueue.main.async { controller.showSizeEditor() }
        }
        if CommandLine.arguments.contains("--show-rotation-editor") {
            DispatchQueue.main.async { controller.showRotationEditor() }
        }
        instanceObserver = DistributedNotificationCenter.default().addObserver(forName: self.notification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rug?.setVisible(true) }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        rug?.setVisible(true); return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        rug?.shutdown()
        if let instanceObserver { DistributedNotificationCenter.default().removeObserver(instanceObserver) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
@MainActor
struct TapeteDesktopMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--smoke-test") {
            do { try SmokeCheck.run(); exit(0) }
            catch { fputs("Smoke check failed: \(error)\n", stderr); exit(1) }
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
