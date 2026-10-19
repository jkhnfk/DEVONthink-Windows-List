import AppKit

/// The content of the side panel: header, scrollable window list and footer.
///
/// The vibrancy lives in a separate `NSVisualEffectView` that is clipped with a
/// rounded mask image, and the hairline is stroked by `BorderOverlayView` one
/// point inside the edge so the rounded corners keep an even outline.
final class PanelContentView: NSView {
    var onRefresh: (() -> Void)?
    var onSelectWindow: ((DTWindowInfo) -> Void)?
    var onCloseWindow: ((DTWindowInfo) -> Void)?
    var onLaunchDEVONthink: (() -> Void)?
    var onOpenAutomationSettings: (() -> Void)?
    var onShowSettingsMenu: ((NSButton) -> Void)?
    var onContentHeightChanged: (() -> Void)?

    private static let cornerRadius: CGFloat = 14
    private let effectView = NSVisualEffectView()
    private let borderView = BorderOverlayView()
    private let countLabel = NSTextField(labelWithString: "")
    private let refreshButton = ClosureButton.icon("arrow.clockwise", toolTip: "刷新窗口列表")
    private let settingsButton = ClosureButton.icon("slider.horizontal.3", toolTip: "设置")
    private let spinner = NSProgressIndicator()
    private let scrollView = NSScrollView()
    private let listView = ItemListView()
    private let footerLabel = NSTextField(labelWithString: "点击窗口名称切换")
    private let updateLabel = NSTextField(labelWithString: "")
    private var renderedState: PanelState = .idle

    private let headerHeight: CGFloat = 44
    private let footerHeight: CGFloat = 26

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = Self.cornerRadius
        layer?.masksToBounds = true

        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.maskImage = Self.cornerMaskImage()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        setupHeader()
        setupScrollView()
        setupFooter()

        borderView.cornerRadius = Self.cornerRadius - 1
        borderView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(borderView)
        NSLayoutConstraint.activate([
            borderView.topAnchor.constraint(equalTo: topAnchor),
            borderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        updateBorderColor()
    }

    /// Rounded, stretchable mask used to clip the vibrancy material itself.
    private static func cornerMaskImage() -> NSImage {
        let radius = cornerRadius
        let size = NSSize(width: radius * 2 + 1, height: radius * 2 + 1)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func setupHeader() {
        let titleLabel = NSTextField(labelWithString: "DEVONthink 窗口")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.onClick { [weak self] in
            self?.onRefresh?()
        }
        settingsButton.onClick { [weak self] in
            guard let self else { return }
            self.onShowSettingsMenu?(self.settingsButton)
        }

        let header = NSStackView(views: [titleLabel, countLabel, spacer, spinner, refreshButton, settingsButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            header.heightAnchor.constraint(equalToConstant: 26),
            spinner.widthAnchor.constraint(equalToConstant: 14),
            spinner.heightAnchor.constraint(equalToConstant: 14)
        ])

        let divider = DividerView()
        addSubview(divider)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor, constant: headerHeight),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none
        addSubview(scrollView)

        listView.itemSpacing = 1
        listView.contentInsets = NSEdgeInsets(
            top: 4,
            left: 8,
            bottom: 6,
            right: 8
        )
        listView.frame = NSRect(x: 0, y: 0, width: Settings.shared.panelWidth, height: 100)
        scrollView.documentView = listView
    }

    override func layout() {
        super.layout()
        layoutList()
    }

    /// The list is frame based: every row has a fixed height, so the document
    /// view only has to grow to fit the items it currently holds.
    private func layoutList() {
        let width = max(scrollView.contentSize.width, 1)
        let height = max(listView.contentHeight, scrollView.contentSize.height)
        let frame = NSRect(x: 0, y: 0, width: width, height: height)
        if listView.frame != frame {
            listView.frame = frame
        }
    }

    private func setupFooter() {
        let divider = DividerView()
        addSubview(divider)

        footerLabel.font = .systemFont(ofSize: 10)
        footerLabel.textColor = .tertiaryLabelColor

        updateLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        updateLabel.textColor = .tertiaryLabelColor
        updateLabel.alignment = .right
        updateLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        let footer = NSStackView(views: [footerLabel, updateLabel])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8
        footer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(footer)

        NSLayoutConstraint.activate([
            footer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            footer.heightAnchor.constraint(equalToConstant: 16),

            divider.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -5),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: headerHeight + 1),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: divider.topAnchor)
        ])
    }

    // MARK: - Content

    func update(state: PanelState, isRefreshing: Bool, lastRefresh: Date?) {
        let contentChanged = state != renderedState
        renderedState = state

        refreshButton.isEnabled = !isRefreshing
        if isRefreshing {
            spinner.isHidden = false
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
            spinner.isHidden = true
        }

        if contentChanged {
            rebuild(with: state)
            DispatchQueue.main.async { [weak self] in
                self?.onContentHeightChanged?()
            }
        }

        updateFooter(lastRefresh: lastRefresh)
    }

    /// Height the panel would like to have, measured from the current content.
    func preferredHeight(maxHeight: CGFloat) -> CGFloat {
        layoutSubtreeIfNeeded()
        scrollView.layoutSubtreeIfNeeded()

        // header + divider above the list + divider below it + footer + paddings
        let chromeHeight: CGFloat = headerHeight + 1 + 1 + footerHeight
        let total = chromeHeight + listView.contentHeight
        return min(max(total, 160), maxHeight)
    }

    private func rebuild(with state: PanelState) {
        listView.removeAllItems()

        switch state {
        case .idle, .loading:
            countLabel.stringValue = ""
            addEmptyState(
                symbol: "hourglass",
                title: "正在读取窗口…",
                message: "正在与 DEVONthink 通信。"
            )

        case .ready(let windows):
            let mainWindows = windows.filter { $0.kind == .main }
            let documentWindows = windows.filter { $0.kind == .document }
            let tabs = windows.filter { $0.kind == .tab }

            let totalWindows = mainWindows.count + documentWindows.count
            countLabel.stringValue = totalWindows == 0 ? "" : "\(totalWindows)"

            if windows.isEmpty {
                addEmptyState(
                    symbol: "macwindow",
                    title: "没有打开的窗口",
                    message: "在 DEVONthink 中打开数据库或文档后，窗口会显示在这里。"
                )
            } else {
                if !mainWindows.isEmpty {
                    addSectionHeader(title: "主窗口", count: mainWindows.count)
                    for window in mainWindows {
                        addRow(window)
                        tabs.filter { $0.windowID == window.windowID }.forEach(addRow)
                    }
                }
                if !documentWindows.isEmpty {
                    addSectionHeader(title: "文档窗口", count: documentWindows.count)
                    for window in documentWindows {
                        addRow(window)
                        tabs.filter { $0.windowID == window.windowID }.forEach(addRow)
                    }
                }
            }

        case .devonthinkNotRunning:
            countLabel.stringValue = ""
            addEmptyState(
                symbol: "moon.zzz",
                title: "DEVONthink 未运行",
                message: "启动 DEVONthink 后，它的窗口会显示在这里。",
                actionTitle: "启动 DEVONthink"
            ) { [weak self] in
                self?.onLaunchDEVONthink?()
            }

        case .devonthinkNotInstalled:
            countLabel.stringValue = ""
            addEmptyState(
                symbol: "questionmark.folder",
                title: "未找到 DEVONthink",
                message: "请先安装 DEVONthink 4（或 3），然后再打开本 App。",
                actionTitle: "下载 DEVONthink"
            ) {
                if let url = URL(string: "https://www.devontechnologies.com/apps/devonthink") {
                    NSWorkspace.shared.open(url)
                }
            }

        case .failure(let message, let isPermissionIssue):
            countLabel.stringValue = ""
            if isPermissionIssue {
                addEmptyState(
                    symbol: "lock.shield",
                    title: "需要授权",
                    message: "本 App 需要控制 DEVONthink 的权限才能读取窗口。请在“系统设置 › 隐私与安全性 › 自动化”中允许本 App 控制 DEVONthink。",
                    actionTitle: "打开系统设置"
                ) { [weak self] in
                    self?.onOpenAutomationSettings?()
                }
            } else {
                addEmptyState(
                    symbol: "exclamationmark.triangle",
                    title: "读取窗口失败",
                    message: message,
                    actionTitle: "重试"
                ) { [weak self] in
                    self?.onRefresh?()
                }
            }
        }
    }

    private func addSectionHeader(title: String, count: Int) {
        if let last = listView.lastItem {
            listView.setSpacing(6, after: last)
        }

        let container = NSView()
        let label = NSTextField(labelWithString: "\(title) · \(count)")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1)
        ])

        listView.addItem(container, height: 18)
    }

    private func addRow(_ window: DTWindowInfo) {
        let row = WindowRowView(window: window)
        row.onClick = { [weak self] in
            self?.onSelectWindow?(window)
        }
        row.onClose = { [weak self] in
            self?.onCloseWindow?(window)
        }
        listView.addItem(row, height: 34)
    }

    private func addEmptyState(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        let emptyState = EmptyStateView(
            symbol: symbol,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
        listView.addItem(emptyState, height: 172)
    }

    private func updateFooter(lastRefresh: Date?) {
        if let lastRefresh {
            let time = timeFormatter.string(from: lastRefresh)
            updateLabel.stringValue = "更新于 \(time)"
            updateLabel.setAccessibilityLabel("最后更新于 \(time)")
        } else {
            updateLabel.stringValue = ""
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorderColor()
    }

    private func updateBorderColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self else { return }
            let isDark = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            self.borderView.strokeColor = isDark
                ? NSColor.white.withAlphaComponent(0.14)
                : NSColor.black.withAlphaComponent(0.08)
        }
    }
}

