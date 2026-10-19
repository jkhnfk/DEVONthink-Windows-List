import AppKit

enum DEVONthinkScriptError: LocalizedError {
    case notInstalled
    case notRunning
    case scriptFailed(message: String, number: Int)
    case malformedOutput

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "没有找到 DEVONthink，请先安装 DEVONthink 4（或 3）。"
        case .notRunning:
            return "DEVONthink 当前没有运行。"
        case .scriptFailed(let message, _):
            return message
        case .malformedOutput:
            return "无法解析 DEVONthink 返回的窗口信息。"
        }
    }

    /// Apple Event error codes used by macOS when automation is not allowed.
    var isPermissionIssue: Bool {
        if case .scriptFailed(_, let number) = self {
            return number == -1743 || number == -1744
        }
        return false
    }
}

/// Talks to DEVONthink through AppleScript.
/// Every Apple Event is sent on a private serial queue so the UI never blocks on
/// DEVONthink (or on the system automation permission prompt).
final class DEVONthinkScripting {
    static let shared = DEVONthinkScripting()

    private let queue = DispatchQueue(label: "com.jkhnfk.DEVONthinkWindowsList.applescript", qos: .userInitiated)

    private init() {}

    // MARK: - Public API

    func fetchWindows(completion: @escaping (Result<[DTWindowInfo], Error>) -> Void) {
        guard DEVONthinkApp.installed else {
            completion(.failure(DEVONthinkScriptError.notInstalled))
            return
        }
        guard DEVONthinkApp.isRunning else {
            completion(.failure(DEVONthinkScriptError.notRunning))
            return
        }
        guard let bundleIdentifier = DEVONthinkApp.bundleIdentifier else {
            completion(.failure(DEVONthinkScriptError.notInstalled))
            return
        }

        let source = Self.fetchScriptTemplate.replacingOccurrences(of: "<<BUNDLE_ID>>", with: bundleIdentifier)
        execute(source) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let output):
                completion(Self.parse(output))
            }
        }
    }

    /// Brings the given window (or tab) to the front and activates DEVONthink.
    func activate(_ window: DTWindowInfo, completion: ((Error?) -> Void)? = nil) {
        guard let bundleIdentifier = DEVONthinkApp.bundleIdentifier else {
            completion?(DEVONthinkScriptError.notInstalled)
            return
        }

        var source = Self.activationScriptTemplate
            .replacingOccurrences(of: "<<BUNDLE_ID>>", with: bundleIdentifier)
            .replacingOccurrences(of: "<<WINDOW_ID>>", with: String(window.windowID))
            
        if let tabID = window.tabID {
            source = source.replacingOccurrences(of: "<<TAB_ACTIVATION>>", with: "set current tab of targetWindow to tab id \(tabID) of targetWindow")
        } else {
            source = source.replacingOccurrences(of: "<<TAB_ACTIVATION>>", with: "")
        }

        execute(source) { result in
            switch result {
            case .success:
                completion?(nil)
            case .failure(let error):
                completion?(error)
            }
        }
    }

    /// Closes the given window (or tab).
    func close(_ window: DTWindowInfo, completion: ((Error?) -> Void)? = nil) {
        guard let bundleIdentifier = DEVONthinkApp.bundleIdentifier else {
            completion?(DEVONthinkScriptError.notInstalled)
            return
        }

        var source = Self.closeScriptTemplate
            .replacingOccurrences(of: "<<BUNDLE_ID>>", with: bundleIdentifier)
            .replacingOccurrences(of: "<<WINDOW_ID>>", with: String(window.windowID))
            
        if let tabID = window.tabID {
            source = source.replacingOccurrences(of: "<<TARGET>>", with: "tab id \(tabID) of targetWindow")
        } else {
            source = source.replacingOccurrences(of: "<<TARGET>>", with: "targetWindow")
        }

        execute(source) { result in
            switch result {
            case .success:
                completion?(nil)
            case .failure(let error):
                completion?(error)
            }
        }
    }

    /// Opens the Automation pane of System Settings so the user can grant consent.
    func openAutomationSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
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
                    ?? "与 DEVONthink 通信失败。"
                completion(.failure(DEVONthinkScriptError.scriptFailed(message: message, number: number)))
            } else {
                completion(.success(descriptor.stringValue ?? ""))
            }
        }
    }

    // MARK: - Parsing

    /// Records are separated by U+0002 and fields by U+0001 to avoid problems
    /// with document titles that contain commas, quotes or newlines.
    private static func parse(_ output: String) -> Result<[DTWindowInfo], Error> {
        var windows: [DTWindowInfo] = []

        for record in output.components(separatedBy: "\u{02}") where !record.isEmpty {
            let fields = record.components(separatedBy: "\u{01}")
            guard fields.count >= 6,
                  let kind = DTWindowInfo.Kind(rawValue: fields[0]),
                  let windowID = Int(fields[1]) else {
                continue
            }

            let tabID = Int(fields[5])

            windows.append(
                DTWindowInfo(
                    kind: kind,
                    windowID: windowID,
                    tabID: tabID,
                    title: fields[2],
                    databaseName: fields[4],
                    isMiniaturized: fields[3] == "true"
                )
            )
        }

        return .success(windows)
    }

    // MARK: - Script sources

    private static let fetchScriptTemplate = #"""
    with timeout of 10 seconds
        tell application id "<<BUNDLE_ID>>"
            set fld to ASCII character 1
            set rec to ASCII character 2
            set outText to ""
            
            repeat with w in main windows
                try
                    set winName to ""
                    try
                        set winName to name of w
                    end try
                    set dbName to ""
                    try
                        set dbName to name of database of w
                    end try
                    set isMini to false
                    try
                        if miniaturized of w then set isMini to true
                    end try
                    set wID to id of w as text
                    set outText to outText & "main" & fld & wID & fld & winName & fld & (isMini as text) & fld & dbName & fld & "" & rec
                    
                    try
                        set tbs to tabs of w
                        if (count of tbs) > 1 then
                            set curID to id of current tab of w
                            repeat with t in tbs
                                set tabNumID to id of t
                                if tabNumID is not equal to curID then
                                    set tID to tabNumID as text
                                    set tName to winName
                                    set tDbName to dbName
                                    try
                                        set rURL to reference URL of t
                                        if rURL is not missing value then
                                            set u1 to (characters 21 thru -1 of (rURL as string)) as string
                                            set AppleScript's text item delimiters to "?"
                                            set u to text item 1 of u1
                                            set AppleScript's text item delimiters to ""
                                            set recd to get record with uuid u
                                            if recd is not missing value then
                                                set tName to name of recd
                                                try
                                                    set tDbName to name of database of recd
                                                end try
                                            end if
                                        end if
                                    end try
                                    set outText to outText & "tab" & fld & wID & fld & tName & fld & "false" & fld & tDbName & fld & tID & rec
                                end if
                            end repeat
                        end if
                    end try
                end try
            end repeat
            
            repeat with w in document windows
                try
                    set winName to ""
                    try
                        set winName to name of w
                    end try
                    set dbName to ""
                    try
                        set dbName to name of database of w
                    end try
                    set isMini to false
                    try
                        if miniaturized of w then set isMini to true
                    end try
                    set wID to id of w as text
                    set outText to outText & "document" & fld & wID & fld & winName & fld & (isMini as text) & fld & dbName & fld & "" & rec
                    
                    try
                        set tbs to tabs of w
                        if (count of tbs) > 1 then
                            set curID to id of current tab of w
                            repeat with t in tbs
                                set tabNumID to id of t
                                if tabNumID is not equal to curID then
                                    set tID to tabNumID as text
                                    set tName to winName
                                    set tDbName to dbName
                                    try
                                        set rURL to reference URL of t
                                        if rURL is not missing value then
                                            set u1 to (characters 21 thru -1 of (rURL as string)) as string
                                            set AppleScript's text item delimiters to "?"
                                            set u to text item 1 of u1
                                            set AppleScript's text item delimiters to ""
                                            set recd to get record with uuid u
                                            if recd is not missing value then
                                                set tName to name of recd
                                                try
                                                    set tDbName to name of database of recd
                                                end try
                                            end if
                                        end if
                                    end try
                                    set outText to outText & "tab" & fld & wID & fld & tName & fld & "false" & fld & tDbName & fld & tID & rec
                                end if
                            end repeat
                        end if
                    end try
                end try
            end repeat
            
            return outText
        end tell
    end timeout
    """#

    private static let activationScriptTemplate = #"""
    with timeout of 10 seconds
        tell application id "<<BUNDLE_ID>>"
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
            try
                <<TAB_ACTIVATION>>
            end try
            set index of targetWindow to 1
            activate
        end tell
    end timeout
    """#

    private static let closeScriptTemplate = #"""
    with timeout of 10 seconds
        tell application id "<<BUNDLE_ID>>"
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
                close <<TARGET>>
            end try
        end tell
    end timeout
    """#
}
