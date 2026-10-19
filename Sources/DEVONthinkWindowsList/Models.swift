import Foundation

/// One window of DEVONthink, either a main window (browser) or a document window.
struct DTWindowInfo: Identifiable, Equatable {
    enum Kind: String {
        case main
        case document
    }

    let kind: Kind
    let windowID: Int
    let title: String
    let databaseName: String
    let isMiniaturized: Bool

    var id: Int { windowID }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名窗口" : trimmed
    }

    var subtitle: String {
        var parts: [String] = []
        if !databaseName.isEmpty {
            parts.append(databaseName)
        }
        if isMiniaturized {
            parts.append("已最小化")
        }
        if parts.isEmpty {
            parts.append(kind == .main ? "主窗口" : "文档窗口")
        }
        return parts.joined(separator: " · ")
    }

    var symbolName: String {
        kind == .main ? "macwindow.on.rectangle" : "doc.text"
    }

    var kindTitle: String {
        kind == .main ? "主窗口" : "文档窗口"
    }
}

/// What the panel is currently showing.
enum PanelState: Equatable {
    case idle
    case loading
    case ready([DTWindowInfo])
    case devonthinkNotRunning
    case devonthinkNotInstalled
    case failure(message: String, isPermissionIssue: Bool)

    var windows: [DTWindowInfo] {
        if case .ready(let windows) = self { return windows }
        return []
    }
}
