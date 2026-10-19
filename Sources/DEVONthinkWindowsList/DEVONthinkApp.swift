import AppKit

/// Locates and launches the installed DEVONthink application.
/// Both DEVONthink 4 (`com.devon-technologies.think`) and DEVONthink 3
/// (`com.devon-technologies.think3`) are supported.
enum DEVONthinkApp {
    static let bundleIdentifiers = [
        "com.devon-technologies.think",
        "com.devon-technologies.think3"
    ]

    /// Bundle identifier of the installed DEVONthink, `nil` when it cannot be found.
    static var bundleIdentifier: String? {
        bundleIdentifiers.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    static var applicationURL: URL? {
        guard let bundleIdentifier else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static var installed: Bool {
        applicationURL != nil
    }

    static var runningApplication: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            guard let identifier = app.bundleIdentifier else { return false }
            return bundleIdentifiers.contains(identifier)
        }
    }

    static var isRunning: Bool {
        runningApplication != nil
    }

    static var displayName: String {
        guard let url = applicationURL else { return "DEVONthink" }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func open() {
        guard let url = applicationURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    static func isDEVONthink(bundleIdentifier identifier: String?) -> Bool {
        guard let identifier else { return false }
        return bundleIdentifiers.contains(identifier)
    }
}
