import AppKit

@main
enum GameMain {
    static func main() {
        if let status = CLI.run(arguments: Array(CommandLine.arguments.dropFirst())) {
            exit(status)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
