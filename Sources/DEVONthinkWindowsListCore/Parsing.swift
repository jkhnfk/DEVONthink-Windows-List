import Foundation

/// Result of parsing one AppleScript bridge payload, including a count of
/// records that failed to parse so callers can tell "no windows" apart from
/// "the output made no sense at all".
public struct WindowParseResult {
    public let windows: [DTWindowInfo]
    public let totalRecords: Int
    public let invalidRecords: Int

    /// True when there was real input but nothing could be parsed from it —
    /// the signature of a changed/broken output contract rather than an
    /// actually-empty window list.
    public var allInvalid: Bool { totalRecords > 0 && windows.isEmpty }

    public init(windows: [DTWindowInfo], totalRecords: Int, invalidRecords: Int) {
        self.windows = windows
        self.totalRecords = totalRecords
        self.invalidRecords = invalidRecords
    }
}

/// Parses the U+0001 (field) / U+0002 (record) separated output produced by the
/// DEVONthink and Skim AppleScript bridges. `app` tags every parsed record with
/// its source application.
public enum WindowParser {
    /// Convenience: returns just the successfully-parsed windows.
    public static func parse(_ output: String, app: DTWindowInfo.App) -> [DTWindowInfo] {
        parseDetailed(output, app: app).windows
    }

    public static func parseDetailed(_ output: String, app: DTWindowInfo.App) -> WindowParseResult {
        var windows: [DTWindowInfo] = []
        let records = output.components(separatedBy: "\u{02}").filter { !$0.isEmpty }
        var invalid = 0

        for record in records {
            let fields = record.components(separatedBy: "\u{01}")
            guard fields.count >= 6,
                  let kind = DTWindowInfo.Kind(rawValue: fields[0]),
                  let windowID = Int(fields[1]) else {
                invalid += 1
                continue
            }

            let tabID = Int(fields[5])

            windows.append(
                DTWindowInfo(
                    app: app,
                    kind: kind,
                    windowID: windowID,
                    tabID: tabID,
                    title: fields[2],
                    databaseName: fields[4],
                    isMiniaturized: isMiniaturized(fields[3])
                )
            )
        }

        return WindowParseResult(windows: windows, totalRecords: records.count, invalidRecords: invalid)
    }

    /// Lenient boolean parsing: accepts the AppleScript `boolean as text`
    /// spellings ("true"/"false") plus case variants and "1"/"0"/"yes"/"no",
    /// so a formatting drift in a bridge can never silently flip a window's
    /// minimized state.
    static func isMiniaturized(_ raw: String) -> Bool {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes", "y", "on":
            return true
        default:
            return false
        }
    }
}

