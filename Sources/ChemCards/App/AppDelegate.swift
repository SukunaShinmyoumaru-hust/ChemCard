import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        MainMenu.install()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1360, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "化学扑克牌 · Chemistry Cards"
        window.minSize = NSSize(width: 1100, height: 720)
        window.tabbingMode = .disallowed
        window.backgroundColor = Theme.AppKitColor.windowBackground
        window.setFrameAutosaveName("ChemCardsMainWindow")
        window.contentView = NSHostingView(rootView: GameRootView())
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        if Smoke.enabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self else { return }
                let scale = self.window.backingScaleFactor
                print("SMOKE windows=\(NSApp.windows.count) visible=\(self.window.isVisible) key=\(self.window.isKeyWindow) main=\(NSApp.mainWindow != nil) frame=\(NSStringFromRect(self.window.frame)) scale=\(scale) policy=\(NSApp.activationPolicy().rawValue) \(Smoke.report())")
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
