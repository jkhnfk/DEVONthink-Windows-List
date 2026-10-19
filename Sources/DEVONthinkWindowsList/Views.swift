import AppKit

/// A view with a flipped coordinate system, used as the document view of the
/// panel's scroll view so content starts at the top.
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Frame based, vertically stacked container used as the scroll view's document
/// view. Every item has a fixed height, which keeps the list measurable without
/// relying on Auto Layout inside the scroll view.
final class ItemListView: NSView {
    override var isFlipped: Bool { true }

    private struct Item {
        let view: NSView
        let height: CGFloat
        var spacingAfter: CGFloat
    }

    private var items: [Item] = []

    var itemSpacing: CGFloat = 2
    var contentInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    var lastItem: NSView? { items.last?.view }

    /// Height the list needs for all of its items, including the insets.
    var contentHeight: CGFloat {
        guard !items.isEmpty else { return contentInsets.top + contentInsets.bottom }
        var height = contentInsets.top + contentInsets.bottom
        for item in items {
            height += item.height
        }
        for item in items.dropLast() {
            height += item.spacingAfter
        }
        return height
    }

    private var itemWidth: CGFloat {
        max(bounds.width - contentInsets.left - contentInsets.right, 1)
    }

    func removeAllItems() {
        for item in items {
            item.view.removeFromSuperview()
        }
        items.removeAll()
        needsLayout = true
    }

    func addItem(_ view: NSView, height: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = true
        view.frame = NSRect(x: contentInsets.left, y: contentHeight, width: itemWidth, height: height)
        addSubview(view)
        items.append(Item(view: view, height: height, spacingAfter: itemSpacing))
        needsLayout = true
    }

    /// Adds extra space between `view` and the item that follows it.
    func setSpacing(_ spacing: CGFloat, after view: NSView) {
        guard let index = items.firstIndex(where: { $0.view === view }) else { return }
        items[index].spacingAfter = spacing
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let width = itemWidth
        var y = contentInsets.top
        for item in items {
            let frame = NSRect(x: contentInsets.left, y: y, width: width, height: item.height)
            if item.view.frame != frame {
                item.view.frame = frame
            }
            y += item.height + item.spacingAfter
        }
    }
}

/// A hairline separator that follows light/dark appearance changes.
final class DividerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        heightAnchor.constraint(equalToConstant: 1).isActive = true
        updateColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColor()
    }

    private func updateColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        }
    }
}

/// A button that runs a closure instead of using target/action in the caller.
final class ClosureButton: NSButton {
    private var handler: (() -> Void)?

    static func icon(_ symbolName: String, toolTip: String) -> ClosureButton {
        let button = ClosureButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)
        button.image?.isTemplate = true
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = toolTip
        button.setAccessibilityLabel(toolTip)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 22),
            button.heightAnchor.constraint(equalToConstant: 22)
        ])
        button.target = button
        button.action = #selector(ClosureButton.fire)
        return button
    }

    static func text(_ title: String) -> ClosureButton {
        let button = ClosureButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = button
        button.action = #selector(ClosureButton.fire)
        return button
    }

    func onClick(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc private func fire() {
        handler?()
    }
}

/// Rounded hover/pressed highlight for a window row.
final class HighlightView: NSView {
    var fillColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard fillColor.alphaComponent > 0 else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        fillColor.setFill()
        path.fill()
    }
}

/// Hairline border drawn just inside a rounded outline.
///
/// `layer.borderWidth` is clipped by the layer mask, so half of it disappears
/// and the rounded arcs end up lighter than the straight edges. Stroking an
/// inset path keeps the line evenly visible all the way around.
final class BorderOverlayView: NSView {
    var strokeColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    var cornerRadius: CGFloat = 13 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard strokeColor.alphaComponent > 0 else { return }
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        path.lineWidth = 1
        strokeColor.setStroke()
        path.stroke()
    }
}

/// Shown when there are no windows, DEVONthink is not running or scripting failed.
final class EmptyStateView: NSView {
    init(symbol: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = .tertiaryLabelColor
        addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)

        let messageLabel = NSTextField(wrappingLabelWithString: message)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 11)
        messageLabel.textColor = .tertiaryLabelColor
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 4
        addSubview(messageLabel)

        var bottomAnchorView: NSView = messageLabel

        if let actionTitle, let action {
            let button = ClosureButton.text(actionTitle)
            button.onClick(action)
            addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 10),
                button.centerXAnchor.constraint(equalTo: centerXAnchor)
            ])
            bottomAnchorView = button
        }

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),

            bottomAnchorView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

