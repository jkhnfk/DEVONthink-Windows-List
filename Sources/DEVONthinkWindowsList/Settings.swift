import Foundation

enum DockEdge: String, CaseIterable {
    case left
    case right

    var localizedName: String {
        self == .left ? "屏幕左侧" : "屏幕右侧"
    }
}

/// Small wrapper around UserDefaults so the whole app shares one source of truth.
final class Settings {
    static let shared = Settings()
    static let didChangeNotification = Notification.Name("DEVONthinkWindowsList.settingsDidChange")

    private enum Key {
        static let edge = "panelEdge"
        static let autoHide = "autoHide"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.edge: DockEdge.right.rawValue,
            Key.autoHide: true
        ])
    }

    /// Which screen edge the panel is attached to.
    var edge: DockEdge {
        get { DockEdge(rawValue: defaults.string(forKey: Key.edge) ?? "") ?? .right }
        set {
            guard newValue != edge else { return }
            defaults.set(newValue.rawValue, forKey: Key.edge)
            notifyChange()
        }
    }

    /// `true`: the panel only appears while the mouse is near the screen edge.
    /// `false`: the panel stays visible all the time.
    var autoHide: Bool {
        get { defaults.bool(forKey: Key.autoHide) }
        set {
            guard newValue != autoHide else { return }
            defaults.set(newValue, forKey: Key.autoHide)
            notifyChange()
        }
    }

    /// Width of the panel in points.
    let panelWidth: CGFloat = 300

    /// Width of the invisible strip at the screen edge that triggers the panel.
    let hotZoneWidth: CGFloat = 4

    /// Gap between the panel and the screen edge.
    let edgeInset: CGFloat = 8

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
