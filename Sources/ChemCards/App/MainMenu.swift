import AppKit

enum GameCommand: String {
    case newGame = "ChemCards.newGame"
    case surrender = "ChemCards.surrender"
    case toggleLog = "ChemCards.toggleLog"
}

private final class MenuTarget: NSObject {
    @objc func newGame(_ sender: Any?) { NotificationCenter.default.post(name: .chemCards, object: GameCommand.newGame) }
    @objc func surrender(_ sender: Any?) { NotificationCenter.default.post(name: .chemCards, object: GameCommand.surrender) }
    @objc func toggleLog(_ sender: Any?) { NotificationCenter.default.post(name: .chemCards, object: GameCommand.toggleLog) }
}

extension Notification.Name {
    static let chemCards = Notification.Name("ChemCardsCommand")
}

enum MainMenu {
    private static let target = MenuTarget()

    static func install() {
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem())
        mainMenu.addItem(gameMenuItem())
        mainMenu.addItem(windowMenuItem())
        NSApp.mainMenu = mainMenu
    }

    private static func appMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "化学扑克牌")
        menu.addItem(withTitle: "关于 化学扑克牌", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let servicesItem = menu.addItem(withTitle: "服务", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        NSApp.servicesMenu = servicesMenu
        servicesItem.submenu = servicesMenu
        menu.addItem(.separator())
        menu.addItem(withTitle: "隐藏 化学扑克牌", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "全部显示", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 化学扑克牌", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = menu
        return item
    }

    private static func gameMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "对局")
        menu.addItem(withTitle: "新对局", action: #selector(MenuTarget.newGame(_:)), keyEquivalent: "n").target = target
        menu.addItem(withTitle: "反应手册", action: #selector(MenuTarget.toggleLog(_:)), keyEquivalent: "l").target = target
        menu.addItem(withTitle: "结束当前对局", action: #selector(MenuTarget.surrender(_:)), keyEquivalent: ".").target = target
        item.submenu = menu
        return item
    }

    private static func windowMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "窗口")
        menu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        item.submenu = menu
        NSApp.windowsMenu = menu
        return item
    }
}
