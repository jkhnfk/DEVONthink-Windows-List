import Foundation

/// One window of DEVONthink, either a main window (browser) or a document window.
struct DTWindowInfo: Identifiable, Equatable {
    enum Kind: String {
        case main
        case document
        case tab
    }

    let kind: Kind
    let windowID: Int
    let tabID: Int?
    let title: String
    let databaseName: String
    let isMiniaturized: Bool

    var id: String {
        if let tabID {
            return "\(windowID)-\(tabID)"
        }
        return "\(windowID)"
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (kind == .tab ? "未命名标签页" : "未命名窗口") : trimmed
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
            switch kind {
            case .main: parts.append("主窗口")
            case .document: parts.append("文档窗口")
            case .tab: parts.append("标签页")
            }
        }
        return parts.joined(separator: " · ")
    }

    var symbolName: String {
        switch kind {
        case .main: return "macwindow.on.rectangle"
        case .document: return "doc.text"
        case .tab: return "macwindow.badge.plus"
        }
    }

    var kindTitle: String {
        switch kind {
        case .main: return "主窗口"
        case .document: return "文档窗口"
        case .tab: return "标签页"
        }
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
