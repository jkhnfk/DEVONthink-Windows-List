import XCTest
@testable import DEVONthinkWindowsListCore

final class WindowParserTests: XCTestCase {

    /// Builds one U+0001-separated record terminated by U+0002, mirroring the
    /// exact wire format the AppleScript bridges emit.
    private func record(_ fields: [String]) -> String {
        fields.joined(separator: "\u{01}") + "\u{02}"
    }

    // MARK: - Adversarial: field-contract fragility

    func testIsMiniaturizedAcceptsCaseVariant() {
        // DEVONthink/Skim may return boolean text in forms other than lowercase
        // "true" (e.g. after a localization change). This must not silently flip
        // a window to "not minimized".
        let out = record(["document", "1", "Title", "True", "DB", ""])
        let windows = WindowParser.parse(out, app: .devonthink)
        XCTAssertEqual(windows.count, 1)
        XCTAssertTrue(windows[0].isMiniaturized, "\"True\" 应被识别为已最小化，而非静默判为未最小化")
    }

    func testIsMiniaturizedAcceptsNumericOne() {
        let out = record(["document", "1", "Title", "1", "DB", ""])
        let windows = WindowParser.parse(out, app: .devonthink)
        XCTAssertEqual(windows.count, 1)
        XCTAssertTrue(windows[0].isMiniaturized, "\"1\" 应被识别为已最小化")
    }

    func testTabIDZeroDoesNotCollideWithMissingTabID() {
        // id is used by Identifiable to dedupe list rows. A tab whose id happens
        // to be 0 must never collapse onto a window that has no tab at all.
        let window = DTWindowInfo(app: .devonthink, kind: .document, windowID: 42, tabID: nil, title: "W", databaseName: "", isMiniaturized: false)
        let tab = DTWindowInfo(app: .devonthink, kind: .tab, windowID: 42, tabID: 0, title: "T", databaseName: "", isMiniaturized: false)
        XCTAssertNotEqual(window.id, tab.id, "tabID 为 0 的标签页与无标签页的窗口不应共享同一个 id")
    }

    // MARK: - Regression: current behaviour that must keep working

    func testWhitespaceTitleFallsBackToPlaceholder() {
        let info = DTWindowInfo(app: .devonthink, kind: .document, windowID: 1, tabID: nil, title: "   \n", databaseName: "", isMiniaturized: false)
        XCTAssertEqual(info.displayTitle, "未命名窗口")
    }

    func testMalformedWindowIDIsSkippedWithoutCrash() {
        let out = record(["document", "not-a-number", "Title", "true", "DB", ""])
        let windows = WindowParser.parse(out, app: .devonthink)
        XCTAssertTrue(windows.isEmpty)
    }

    // MARK: - Adversarial: silent-failure detection (regression after hardening)

    func testAllInvalidPayloadIsDetectable() {
        // A payload with real records but nothing parseable must be flagged as
        // "all invalid", not silently reported as an empty window list.
        let out = record(["main", "oops", "Title", "true", "DB", ""])
        let result = WindowParser.parseDetailed(out, app: .devonthink)
        XCTAssertTrue(result.allInvalid, "全部无效的输出应被识别为解析失败，而非静默返回空列表")
        XCTAssertEqual(result.totalRecords, 1)
        XCTAssertEqual(result.invalidRecords, 1)
    }

    func testIsMiniaturizedRejectsNonTruthyValues() {
        // Lenient parsing must not over-match: "false"/"0"/"no"/"" stay false.
        for raw in ["false", "0", "no", "off", ""] {
            XCTAssertFalse(WindowParser.isMiniaturized(raw), "\"\(raw)\" 不应被识别为已最小化")
        }
    }
}
