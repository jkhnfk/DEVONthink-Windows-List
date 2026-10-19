import AppKit
import QuartzCore

/// Borderless panel that never becomes key so DEVONthink keeps focus.
private final class SidePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Owns the side panel and all of its edge-hover behaviour.
final class PanelController {
    static let panelWidth: CGFloat = Settings.shared.panelWidth
    private static let hotZoneWidth: CGFloat = Settings.shared.hotZoneWidth
    private static let slideDistance: CGFloat = 16
    private static let pollInterval: TimeInterval = 0.07
    private static let hideDelay: TimeInterval = 0.45

    private let panel: SidePanel
    let contentView: PanelContentView

    var edge: DockEdge = .right
    private(set) var alwaysVisible = false

    /// True while the panel is slid in and visible on screen.
    private(set) var isSlidIn = false

    /// Called whenever the panel starts sliding in, e.g. to refresh its data
    /// before it becomes visible.
    var onShow: (() -> Void)?

    private var currentScreen: NSScreen?
    private var isAnimating = false
    private var autoHidePaused = false
    private var stickyUntilMouseEnters = false
    private var pollTimer: Timer?
    private var hideWorkItem: DispatchWorkItem?
    private var clickMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    init() {
        contentView = PanelContentView(frame: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 420))
        panel = SidePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.isRestorable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = contentView

        installObservers()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    // MARK: - Show and hide

    func show() {
        guard let screen = screenUnderMouse() ?? currentScreen ?? NSScreen.main else { return }
        currentScreen = screen
        cancelScheduledHide()

        let size = desiredSize(for: screen)
        let target = visibleFrame(size: size, on: screen)

        guard !isSlidIn else {
            if panel.frame != target, !isAnimating {
                panel.setFrame(target, display: true)
            }
            return
        }
        guard !isAnimating else { return }

        if !panel.isVisible {
            panel.setFrame(hiddenFrame(size: size, on: screen), display: false)
            panel.orderFrontRegardless()
        }
        isSlidIn = true
        onShow?()
        animate(to: target, duration: 0.2)
    }

    func hide() {
        cancelScheduledHide()
        stickyUntilMouseEnters = false
        guard isSlidIn else { return }
        isSlidIn = false

        guard let screen = currentScreen else {
            panel.orderOut(nil)
            return
        }
        let target = hiddenFrame(size: desiredSize(for: screen), on: screen)
        animate(to: target, duration: 0.16) { [weak self] in
            guard let self, !self.isSlidIn else { return }
            self.panel.orderOut(nil)
        }
    }

    func hideImmediately() {
        cancelScheduledHide()
        stickyUntilMouseEnters = false
        isSlidIn = false
        panel.orderOut(nil)
    }

    func toggle() {
        if isSlidIn {
            hide()
        } else {
            show()
        }
    }

    /// Shows the panel and keeps it open until the mouse enters it once, so
    /// showing it from the status bar menu does not immediately hide it again.
    func showSticky() {
        show()
        stickyUntilMouseEnters = true
    }

    /// Pauses automatic hiding, e.g. while a menu is open inside the panel.
    func setAutoHidePaused(_ paused: Bool) {
        autoHidePaused = paused
        if paused {
            cancelScheduledHide()
        }
    }

    /// Applies user settings and repositions the panel if needed.
    func apply(edge: DockEdge, autoHide: Bool) {
        let edgeChanged = self.edge != edge
        self.edge = edge
        self.alwaysVisible = !autoHide

        if alwaysVisible {
            show()
        } else if isSlidIn {
            if edgeChanged {
                refreshLayout(animated: true)
            } else {
                scheduleHide()
            }
        } else {
            refreshLayout(animated: false)
        }
    }

    /// Re-measures the content and keeps the panel anchored to the screen edge.
    func refreshLayout(animated: Bool = false) {
        guard !isAnimating else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.refreshLayout(animated: false)
            }
            return
        }
        guard let screen = currentScreen ?? NSScreen.main else { return }
        let size = desiredSize(for: screen)

        if isSlidIn {
            let target = visibleFrame(size: size, on: screen)
            guard panel.frame != target else { return }
            if animated && !isAnimating {
                animate(to: target, duration: 0.18)
            } else {
                panel.setFrame(target, display: true)
            }
        } else {
            panel.setFrame(hiddenFrame(size: size, on: screen), display: false)
        }
    }

    // MARK: - Geometry

    private func desiredSize(for screen: NSScreen) -> NSSize {
        let maxHeight = max(220, screen.visibleFrame.height - 120)
        let height = contentView.preferredHeight(maxHeight: maxHeight)
        return NSSize(width: Self.panelWidth, height: height.rounded())
    }

    private func visibleFrame(size: NSSize, on screen: NSScreen) -> NSRect {
        let area = screen.visibleFrame
        let inset = Settings.shared.edgeInset
        let y = area.midY - size.height / 2
        let x = edge == .right ? area.maxX - size.width - inset : area.minX + inset
        return NSRect(x: x, y: y, width: size.width, height: size.height).integral
    }

    private func hiddenFrame(size: NSSize, on screen: NSScreen) -> NSRect {
        let shown = visibleFrame(size: size, on: screen)
        let offset = size.width + Self.slideDistance
        let x = edge == .right ? shown.origin.x + offset : shown.origin.x - offset
        return NSRect(x: x, y: shown.origin.y, width: size.width, height: size.height).integral
    }

    private func screenUnderMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.visibleFrame.contains(location) } ?? NSScreen.main
    }

    private func isInHotZone(_ location: NSPoint) -> Bool {
        guard let screen = currentScreen ?? screenUnderMouse() else { return false }
        let area = screen.visibleFrame
        guard location.y >= area.minY, location.y <= area.maxY else { return false }

        switch edge {
        case .right:
            return location.x >= area.maxX - Self.hotZoneWidth
        case .left:
            return location.x <= area.minX + Self.hotZoneWidth
        }
    }

    // MARK: - Hover polling

    private func startPolling() {
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.pollMouseLocation()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func pollMouseLocation() {
        guard !isAnimating, !autoHidePaused else { return }
        let location = NSEvent.mouseLocation

        if stickyUntilMouseEnters {
            if panel.frame.contains(location) {
                stickyUntilMouseEnters = false
            } else {
                cancelScheduledHide()
                return
            }
        }

        if alwaysVisible {
            cancelScheduledHide()
            if !isSlidIn {
                show()
            }
            return
        }

        if !isSlidIn {
            if isInHotZone(location) {
                show()
            }
            return
        }

        if panel.frame.contains(location) || isInHotZone(location) {
            cancelScheduledHide()
        } else {
            scheduleHide()
        }
    }

    private func scheduleHide() {
        guard hideWorkItem == nil, !alwaysVisible else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hideWorkItem = nil
            self.hide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hideDelay, execute: item)
    }

    private func cancelScheduledHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    // MARK: - Observers

    private func installObservers() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self, self.isSlidIn, !self.alwaysVisible else { return }
            if !self.panel.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.currentScreen = self.screenUnderMouse()
            self.refreshLayout(animated: false)
        }
    }

    // MARK: - Animation

    private func animate(to frame: NSRect, duration: TimeInterval, completion: (() -> Void)? = nil) {
        isAnimating = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.panel.invalidateShadow()
            completion?()
        }
    }
}


