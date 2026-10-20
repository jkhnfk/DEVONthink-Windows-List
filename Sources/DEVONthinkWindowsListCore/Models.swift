import Foundation

/// One window of DEVONthink or Skim. DEVONthink windows are main windows
/// (browser) or document windows and may carry nested tabs; Skim windows are
/// plain document (PDF) windows listed flat.
public struct DTWindowInfo: Identifiable, Equatable {
    public enum App: String {
        case devonthink
        case skim
    }

    public enum Kind: String {
        case main
        case document
        case tab
    }

    public let app: App
    public let kind: Kind
    public let windowID: Int
    public let tabID: Int?
    public let title: String
    public let databaseName: String
    public let isMiniaturized: Bool

    public init(app: App, kind: Kind, windowID: Int, tabID: Int?, title: String, databaseName: String, isMiniaturized: Bool) {
        self.app = app
        self.kind = kind
        self.windowID = windowID
        self.tabID = tabID
        self.title = title
        self.databaseName = databaseName
        self.isMiniaturized = isMiniaturized
    }

    public var id: String {
        if let tabID {
            return "\(app.rawValue)-w\(windowID)-t\(tabID)"
        }
        return "\(app.rawValue)-w\(windowID)"
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (kind == .tab ? "未命名标签页" : "未命名窗口") : trimmed
    }

    public var subtitle: String {
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
            case .document: parts.append(app == .skim ? "Skim PDF" : "文档窗口")
            case .tab: parts.append("标签页")
            }
        }
        return parts.joined(separator: " · ")
    }

    public var symbolName: String {
        switch kind {
        case .main: return "macwindow.on.rectangle"
        case .document: return "doc.text"
        case .tab: return "macwindow.badge.plus"
        }
    }

    public var kindTitle: String {
        switch kind {
        case .main: return "主窗口"
        case .document: return app == .skim ? "Skim 文档" : "文档窗口"
        case .tab: return "标签页"
        }
    }
}

/// What the panel is currently showing.
public enum PanelState: Equatable {
    case idle
    case loading
    case ready([DTWindowInfo])
    case devonthinkNotRunning
    case devonthinkNotInstalled
    case failure(message: String, isPermissionIssue: Bool)

    public var windows: [DTWindowInfo] {
        if case .ready(let windows) = self { return windows }
        return []
    }
}