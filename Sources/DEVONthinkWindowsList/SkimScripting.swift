import AppKit
import DEVONthinkWindowsListCore

/// Locates the Skim PDF reader and exposes its windows through AppleScript.
enum SkimApp {
    static let bundleIdentifier = "net.sourceforge.skim-app.skim"

    static var installed: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    static var applicationURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static var runningApplication: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleIdentifier }
    }

    static var isRunning: Bool {
        runningApplication != nil
    }

    static func open() {
        guard let url = applicationURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }
}

/// Talks to Skim through AppleScript.
///
/// Skim's scripting dictionary has no `tab` element — a window whose contents
/// are arranged as tabs is exposed as one flat `window` per tab, each with its
/// own id and name. That is exactly the list we show, so switching to a "tab"
/// is simply activating the matching window.
final class SkimScripting {
    static let shared = SkimScripting()

    private let queue = DispatchQueue(label: "com.jkhnfk.DEVONthinkWindowsList.skim", qos: .userInitiated)

    private init() {}

    // MARK: - Public API

    func fetchWindows(completion: @escaping (Result<[DTWindowInfo], Error>) -> Void) {
        guard SkimApp.isRunning else {
            completion(.success([]))
            return
        }

        execute(Self.fetchScriptTemplate) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let output):
                completion(.success(WindowParser.parse(output, app: .skim)))
            }
        }
    }

    /// Brings the given Skim window (or tab) to the front and activates Skim.
    func activate(_ window: DTWindowInfo, completion: ((Error?) -> Void)? = nil) {
        let source = Self.activationScriptTemplate
            .replacingOccurrences(of: "<<WINDOW_ID>>", with: String(window.windowID))

        execute(source) { result in
            switch result {
            case .success:
                completion?(nil)
            case .failure(let error):
                completion?(error)
            }
        }
    }

    /// Closes the given Skim window (or tab).
    func close(_ window: DTWindowInfo, completion: ((Error?) -> Void)? = nil) {
        let source = Self.closeScriptTemplate
            .replacingOccurrences(of: "<<WINDOW_ID>>", with: String(window.windowID))

        execute(source) { result in
            switch result {
            case .success:
                completion?(nil)
            case .failure(let error):
                completion?(error)
            }
        }
    }

    // MARK: - AppleScript execution

    private func execute(_ source: String, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            guard let script = NSAppleScript(source: source) else {
                completion(.failure(DEVONthinkScriptError.scriptFailed(message: "无法创建 AppleScript。", number: 0)))
                return
            }

            var errorInfo: NSDictionary?
            let descriptor = script.executeAndReturnError(&errorInfo)

            if let errorInfo {
                let number = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
                let message = (errorInfo[NSAppleScript.errorMessage] as? String)
                    ?? (errorInfo[NSAppleScript.errorBriefMessage] as? String)
                    ?? "与 Skim 通信失败。"
                completion(.failure(DEVONthinkScriptError.scriptFailed(message: message, number: number)))
            } else {
                completion(.success(descriptor.stringValue ?? ""))
            }
        }
    }

    // MARK: - Script sources

    private static let fetchScriptTemplate = #"""
    with timeout of 10 seconds
        tell application id "net.sourceforge.skim-app.skim"
            set fld to ASCII character 1
            set rec to ASCII character 2
            set outText to ""
            repeat with w in windows
                try
                    set winName to ""
                    try
                        set winName to name of w
                    end try
                    set isMini to false
                    try
                        if miniaturized of w then set isMini to true
                    end try
                    set outText to outText & "document" & fld & (id of w as text) & fld & winName & fld & (isMini as text) & fld & "" & fld & "" & rec
                end try
            end repeat
            return outText
        end tell
    end timeout
    """#

    private static let activationScriptTemplate = #"""
    with timeout of 10 seconds
        tell application id "net.sourceforge.skim-app.skim"
            set targetWindow to missing value
            repeat with w in windows
                try
                    if (id of w) is <<WINDOW_ID>> then
                        set targetWindow to w
                        exit repeat
                    end if
                end try
            end repeat
            if targetWindow is missing value then
                error "找不到该窗口，它可能已经被关闭。" number 1728
            end if
            try
                if miniaturized of targetWindow then set miniaturized of targetWindow to false
            end try
            set index of targetWindow to 1
            activate
        end tell
    end timeout
    """#

    private static let closeScriptTemplate = #"""
    with timeout of 10 seconds
        tell application id "net.sourceforge.skim-app.skim"
            set targetWindow to missing value
            repeat with w in windows
                try
                    if (id of w) is <<WINDOW_ID>> then
                        set targetWindow to w
                        exit repeat
                    end if
                end try
            end repeat
            if targetWindow is missing value then
                return ""
            end if
            try
                close targetWindow
            end try
        end tell
    end timeout
    """#
}
