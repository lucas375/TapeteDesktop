import AppKit

@MainActor
enum RugSizeMenu {
    static func item(currentSize: CGSize, resize: @escaping (CGSize) -> Void,
                     custom: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: "Tamanho do tapete", action: nil, keyEquivalent: "")
        item.identifier = NSUserInterfaceItemIdentifier("tapete.size")
        let menu = NSMenu(title: item.title)
        let presets: [(String, String, CGSize)] = [
            ("small", "Pequeno · 480 × 330", CGSize(width: 480, height: 330)),
            ("medium", "Médio · 640 × 440", CGSize(width: 640, height: 440)),
            ("large", "Grande · 880 × 605", CGSize(width: 880, height: 605))
        ]
        for (id, title, size) in presets {
            let command = SizeMenuCommand(title: title, id: "size." + id) { resize(size) }
            if abs(currentSize.width - size.width) < 0.5 && abs(currentSize.height - size.height) < 0.5 {
                command.state = .on
            }
            menu.addItem(command)
        }
        menu.addItem(.separator())
        menu.addItem(SizeMenuCommand(title: "Aumentar 10%", id: "size.grow") {
            resize(CGSize(width: currentSize.width * 1.1, height: currentSize.height * 1.1))
        })
        menu.addItem(SizeMenuCommand(title: "Diminuir 10%", id: "size.shrink") {
            resize(CGSize(width: currentSize.width / 1.1, height: currentSize.height / 1.1))
        })
        menu.addItem(.separator())
        menu.addItem(SizeMenuCommand(title: "Definir medidas…", id: "size.custom", command: custom))
        item.submenu = menu
        return item
    }
}

@MainActor
private final class SizeMenuCommand: NSMenuItem {
    private let command: () -> Void
    init(title: String, id: String, command: @escaping () -> Void) {
        self.command = command
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        identifier = NSUserInterfaceItemIdentifier(id)
        target = self
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func invoke() { command() }
}
