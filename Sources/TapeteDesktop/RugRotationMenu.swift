import AppKit

@MainActor
enum RugRotationMenu {
    static func item(degrees: Double, rotate: @escaping (Double) -> Void, custom: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: "Girar tapete", action: nil, keyEquivalent: "")
        item.identifier = NSUserInterfaceItemIdentifier("tapete.rotation")
        let menu = NSMenu(title: item.title)
        for side in RugOrientation.allCases {
            let command = RotationMenuCommand(title: side.arrow + "  " + side.title, id: "rotation.\(Int(side.degrees))") { rotate(side.degrees) }
            if RugOrientation.current(degrees: degrees) == side { command.state = .on }
            menu.addItem(command)
        }
        menu.addItem(.separator())
        menu.addItem(RotationMenuCommand(title: "↶  Girar para a esquerda", id: "rotation.left") { rotate(RugRotation.quarterTurn(degrees) - 90) })
        menu.addItem(RotationMenuCommand(title: "↷  Girar para a direita", id: "rotation.right") { rotate(RugRotation.quarterTurn(degrees) + 90) })
        menu.addItem(.separator())
        menu.addItem(RotationMenuCommand(title: "Abrir setas de giro…", id: "rotation.custom", command: custom))
        item.submenu = menu
        return item
    }
}

@MainActor
private final class RotationMenuCommand: NSMenuItem {
    private let command: () -> Void
    init(title: String, id: String, command: @escaping () -> Void) {
        self.command = command
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        identifier = NSUserInterfaceItemIdentifier(id); target = self
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func invoke() { command() }
}
