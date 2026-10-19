import AppKit
import CoreGraphics
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let panelController = PanelController()
    private var statusItem: NSStatusItem!
    private var refreshTimers: [Timer] = []
    private var settingsObserver: NSObjectProtocol?

    private var currentState: PanelState = .idle
    private var isRefreshing = false
    private var needsRefresh = false
    private var lastRefreshDate: Date?
    private var lastWindowSignature: String?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        observeSettings()
        refresh()
        startRefreshTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimers.forEach { $0.invalidate() }
        refreshTimers.removeAll()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        panelController.hideImmediately()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "DEVONthink 窗口列表")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "DEVONthink 窗口列表"
            button.setAccessibilityLabel("DEVONthink 窗口列表")
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    private func setupPanel() {
        let content = panelController.contentView
        content.onRefresh = { [weak self] in
            self?.refresh()
        }
        content.onSelectWindow = { [weak self] window in
            self?.activate(window)
        }
        content.onCloseWindow = { [weak self] window in
            self?.close(window)
        }
        content.onLaunchDEVONthink = { [weak self] in
            DEVONthinkApp.open()
            self?.scheduleRefresh(after: 2)
        }
        content.onOpenAutomationSettings = { [weak self] in
            DEVONthinkScripting.shared.openAutomationSettings()
            self?.scheduleRefresh(after: 2)
        }
        content.onShowSettingsMenu = { [weak self] button in
            self?.showSettingsMenu(from: button)
        }
        content.onContentHeightChanged = { [weak self] in
            self?.panelController.refreshLayout(animated: true)
        }
        panelController.onShow = { [weak self] in
            self?.refresh()
        }

        applySettings()
        content.update(state: .loading, isRefreshing: true, lastRefresh: nil)
    }

    private func observeSettings() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: Settings.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }
    }

    private func applySettings() {
        panelController.apply(edge: settings.edge, autoHide: settings.autoHide)
    }

    // MARK: - Data

    func refresh() {
        guard !isRefreshing else {
            needsRefresh = true
            return
        }
        isRefreshing = true
        needsRefresh = false
        panelController.contentView.update(state: currentState, isRefreshing: true, lastRefresh: lastRefreshDate)

        DEVONthinkScripting.shared.fetchWindows { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                self.currentState = Self.panelState(for: result)
                self.lastRefreshDate = Date()
                self.panelController.contentView.update(
                    state: self.currentState,
                    isRefreshing: false,
                    lastRefresh: self.lastRefreshDate
                )
                self.updateStatusItem()

                if self.needsRefresh {
                    self.needsRefresh = false
                    self.scheduleRefresh(after: 0.25)
                }
            }
        }
    }

    func scheduleRefresh(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.refresh()
        }
    }

    private static func panelState(for result: Result<[DTWindowInfo], Error>) -> PanelState {
        switch result {
        case .success(let windows):
            return .ready(windows)
        case .failure(let error):
            guard let scriptError = error as? DEVONthinkScriptError else {
                return .failure(message: error.localizedDescription, isPermissionIssue: false)
            }
            switch scriptError {
            case .notRunning:
                return .devonthinkNotRunning
            case .notInstalled:
                return .devonthinkNotInstalled
            case .scriptFailed, .malformedOutput:
                return .failure(
                    message: scriptError.errorDescription ?? "发生未知错误。",
                    isPermissionIssue: scriptError.isPermissionIssue
                )
            }
        }
    }

    private func startRefreshTimer() {
        // Opening or closing a window changes DEVONthink's window IDs, which can
        // be read from CGWindowList without any extra permission. Polling that
        // signature twice a second keeps the list in sync within ~0.5 s, even
        // while the panel is hidden.
        let signatureTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkWindowSignature()
        }
        RunLoop.main.add(signatureTimer, forMode: .common)

        // Full AppleScript refresh while the panel is on screen: also catches
        // renames, reordering and minimize changes that the window IDs miss.
        let visibleTimer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, self.panelController.isSlidIn, !self.isRefreshing else { return }
            if let last = self.lastRefreshDate, Date().timeIntervalSince(last) < 1.2 { return }
            self.refresh()
        }
        RunLoop.main.add(visibleTimer, forMode: .common)

        // Slow background refresh keeps the status bar menu reasonably fresh.
        let backgroundTimer = Timer(timeInterval: 20, repeats: true) { [weak self] _ in
            guard let self, !self.panelController.isSlidIn else { return }
            self.refresh()
        }
        RunLoop.main.add(backgroundTimer, forMode: .common)

        refreshTimers = [signatureTimer, visibleTimer, backgroundTimer]
    }

    /// Sorted window IDs of DEVONthink's standard windows. Window IDs stay
    /// stable for the lifetime of a window, so a changed signature means that
    /// windows were opened, closed or recreated.
    private func windowSignature() -> String? {
        guard let pid = DEVONthinkApp.runningApplication?.processIdentifier else { return nil }
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let ids = list.compactMap { info -> Int? in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid else { return nil }
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0 else { return nil }
            return (info[kCGWindowNumber as String] as? NSNumber)?.intValue
        }
        return ids.sorted().map(String.init).joined(separator: ",")
    }

    private func checkWindowSignature() {
        let signature = windowSignature()
        guard signature != lastWindowSignature, !isRefreshing else { return }
        lastWindowSignature = signature
        refresh()
    }

    private func updateStatusItem() {
        let count = currentState.windows.count
        let toolTip: String
        switch currentState {
        case .ready:
            toolTip = count == 0 ? "DEVONthink 窗口列表（没有打开的窗口）" : "DEVONthink 窗口列表（\(count) 个窗口）"
        case .devonthinkNotRunning:
            toolTip = "DEVONthink 窗口列表（DEVONthink 未运行）"
        case .failure(_, let isPermissionIssue):
            toolTip = isPermissionIssue ? "DEVONthink 窗口列表（需要授权）" : "DEVONthink 窗口列表（读取失败）"
        case .devonthinkNotInstalled:
            toolTip = "DEVONthink 窗口列表（未安装 DEVONthink）"
        case .idle, .loading:
            toolTip = "DEVONthink 窗口列表"
        }
        statusItem.button?.toolTip = toolTip
    }

    // MARK: - Window activation

    private func activate(_ window: DTWindowInfo) {
        panelController.hideImmediately()
        DEVONthinkScripting.shared.activate(window) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.present(error: error)
                }
                self.scheduleRefresh(after: 0.8)
            }
        }
    }

    private func close(_ window: DTWindowInfo) {
        DEVONthinkScripting.shared.close(window) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.present(error: error)
                }
                self.scheduleRefresh(after: 0.5)
            }
        }
    }

    // MARK: - Launch at login

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            present(error: error)
        }
    }

    // MARK: - Alerts

    private func present(error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "操作失败"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Status bar menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildStatusMenu(menu)
    }

    private var emptyMenuTitle: String {
        switch currentState {
        case .ready:
            return "没有打开的窗口"
        case .devonthinkNotRunning:
            return "DEVONthink 未运行"
        case .devonthinkNotInstalled:
            return "未安装 DEVONthink"
        case .failure(_, let isPermissionIssue):
            return isPermissionIssue ? "需要授权才能读取窗口" : "读取窗口失败"
        case .idle, .loading:
            return "正在读取窗口…"
        }
    }

    private func rebuildStatusMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "DEVONthink 窗口", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let windows = currentState.windows
        if windows.isEmpty {
            let emptyItem = NSMenuItem(title: emptyMenuTitle, action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for window in windows.prefix(15) {
                let item = NSMenuItem(
                    title: window.displayTitle,
                    action: #selector(activateWindowFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = window
                item.toolTip = "\(window.kindTitle) · \(window.subtitle)"
                item.indentationLevel = 1
                if window.isMiniaturized {
                    item.image = NSImage(systemSymbolName: "minus.rectangle", accessibilityDescription: nil)
                } else if window.kind == .main {
                    item.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: panelController.isSlidIn ? "隐藏面板" : "显示面板",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let refreshItem = NSMenuItem(title: "刷新窗口列表", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let openItem = NSMenuItem(title: "打开 DEVONthink", action: #selector(openDEVONthink), keyEquivalent: "")
        openItem.target = self
        openItem.isEnabled = DEVONthinkApp.installed
        menu.addItem(openItem)

        menu.addItem(.separator())

        let autoHideItem = NSMenuItem(title: "自动隐藏面板", action: #selector(toggleAutoHide), keyEquivalent: "")
        autoHideItem.target = self
        autoHideItem.state = settings.autoHide ? .on : .off
        menu.addItem(autoHideItem)

        let edgeMenu = NSMenu()
        for edge in DockEdge.allCases {
            let item = NSMenuItem(title: edge.localizedName, action: #selector(selectEdge(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = edge.rawValue
            item.state = settings.edge == edge ? .on : .off
            edgeMenu.addItem(item)
        }
        let edgeItem = NSMenuItem(title: "面板位置", action: nil, keyEquivalent: "")
        edgeItem.submenu = edgeMenu
        menu.addItem(edgeItem)

        let loginItem = NSMenuItem(title: "登录时启动", action: #selector(toggleLaunchAtLoginAction), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Panel settings menu

    private func showSettingsMenu(from button: NSButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let autoHideItem = NSMenuItem(title: "自动隐藏面板", action: #selector(toggleAutoHide), keyEquivalent: "")
        autoHideItem.target = self
        autoHideItem.state = settings.autoHide ? .on : .off
        menu.addItem(autoHideItem)

        let edgeMenu = NSMenu()
        for edge in DockEdge.allCases {
            let item = NSMenuItem(title: edge.localizedName, action: #selector(selectEdge(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = edge.rawValue
            item.state = settings.edge == edge ? .on : .off
            edgeMenu.addItem(item)
        }
        let edgeItem = NSMenuItem(title: "面板位置", action: nil, keyEquivalent: "")
        edgeItem.submenu = edgeMenu
        menu.addItem(edgeItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "登录时启动", action: #selector(toggleLaunchAtLoginAction), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        panelController.setAutoHidePaused(true)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        panelController.setAutoHidePaused(false)
    }

    // MARK: - Actions

    @objc private func activateWindowFromMenu(_ sender: NSMenuItem) {
        guard let window = sender.representedObject as? DTWindowInfo else { return }
        activate(window)
    }

    @objc private func togglePanel() {
        if panelController.isSlidIn {
            panelController.hide()
        } else {
            panelController.showSticky()
            refresh()
        }
    }

    @objc private func refreshAction() {
        refresh()
    }

    @objc private func openDEVONthink() {
        DEVONthinkApp.open()
        scheduleRefresh(after: 2)
    }

    @objc private func toggleAutoHide() {
        settings.autoHide.toggle()
    }

    @objc private func selectEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let edge = DockEdge(rawValue: raw) else { return }
        settings.edge = edge
    }

    @objc private func toggleLaunchAtLoginAction() {
        toggleLaunchAtLogin()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
