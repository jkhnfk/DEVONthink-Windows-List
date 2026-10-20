import AppKit
import DEVONthinkWindowsListCore

/// One clickable DEVONthink window entry.
final class WindowRowView: NSView {
    let windowInfo: DTWindowInfo
    var onClick: (() -> Void)?
    var onClose: (() -> Void)?

    private let highlightView = HighlightView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let chevronView = NSImageView()
    private let closeButton = ClosureButton.icon("xmark", toolTip: "关闭")
    private var trackingArea: NSTrackingArea?

    private var isHovered = false {
        didSet { updateAppearance() }
    }
    private var isPressed = false {
        didSet { updateAppearance() }
    }

    init(window: DTWindowInfo) {
        self.windowInfo = window
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        highlightView.fillColor = .clear
        addSubview(highlightView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: windowInfo.symbolName, accessibilityDescription: windowInfo.kindTitle)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .secondaryLabelColor
        addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = windowInfo.displayTitle
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = windowInfo.isMiniaturized ? .secondaryLabelColor : .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.cell?.truncatesLastVisibleLine = true
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.stringValue = windowInfo.subtitle
        subtitleLabel.font = .systemFont(ofSize: 10)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.cell?.truncatesLastVisibleLine = true
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(subtitleLabel)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevronView.imageScaling = .scaleProportionallyDown
        chevronView.contentTintColor = .tertiaryLabelColor
        chevronView.alphaValue = 0
        addSubview(chevronView)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.alphaValue = 0
        closeButton.onClick { [weak self] in
            self?.onClose?()
        }
        addSubview(closeButton)

        let indent: CGFloat = windowInfo.kind == .tab ? 24 : 8

        NSLayoutConstraint.activate([
            highlightView.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: trailingAnchor),
            highlightView.topAnchor.constraint(equalTo: topAnchor, constant: 0.5),
            highlightView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -0.5),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: indent),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 7),
            chevronView.heightAnchor.constraint(equalToConstant: 11),
            
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0)
        ])

        toolTip = "\(windowInfo.displayTitle)\n\(windowInfo.kindTitle) · \(windowInfo.subtitle)"

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(windowInfo.displayTitle)
        setAccessibilityHelp("切换到\(windowInfo.kindTitle)")
    }

    // MARK: - Hover and click

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
    }

    override func mouseDown(with event: NSEvent) {
        // Only consider pressed if not clicking the close button
        let point = convert(event.locationInWindow, from: nil)
        if !closeButton.frame.contains(point) {
            isPressed = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if !bounds.contains(point) {
            isPressed = false
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if closeButton.frame.contains(point) && isHovered {
            // Close button handles its own click via onClick
            return
        }
        
        let shouldActivate = isPressed && bounds.contains(point)
        isPressed = false
        if shouldActivate {
            onClick?()
        }
    }

    private func updateAppearance() {
        if isPressed {
            highlightView.fillColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.32)
        } else if isHovered {
            highlightView.fillColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.16)
        } else {
            highlightView.fillColor = .clear
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            // Hide chevron, show close button on hover
            chevronView.animator().alphaValue = 0 
            closeButton.animator().alphaValue = isHovered ? 1 : 0
        }
    }
}

