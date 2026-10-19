import AppKit

/// Entry point. The app has no windows of its own, so it runs as an accessory
/// application and lives entirely in the menu bar.
@main
enum Main {
    private static var appDelegate: AppDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
