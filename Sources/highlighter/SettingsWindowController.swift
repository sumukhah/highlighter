import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferencesStore: AppPreferencesStore

    private let hotKeyPopupButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let commandCheckbox = NSButton(checkboxWithTitle: "Command", target: nil, action: nil)
    private let shiftCheckbox = NSButton(checkboxWithTitle: "Shift", target: nil, action: nil)
    private let optionCheckbox = NSButton(checkboxWithTitle: "Option", target: nil, action: nil)
    private let controlCheckbox = NSButton(checkboxWithTitle: "Control", target: nil, action: nil)
    private let strokeWidthSlider = NSSlider(value: 8, minValue: 2, maxValue: 20, target: nil, action: nil)
    private let fadeDurationSlider = NSSlider(value: 4, minValue: 0.75, maxValue: 6, target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    private let hotKeyValueLabel = NSTextField(labelWithString: "")
    private let strokeWidthValueLabel = NSTextField(labelWithString: "")
    private let fadeDurationValueLabel = NSTextField(labelWithString: "")

    init(preferencesStore: AppPreferencesStore) {
        self.preferencesStore = preferencesStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        configureWindow()
        configureControls()
        refreshFromPreferences()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        refreshFromPreferences()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
    }

    @objc
    private func hotKeyChanged() {
        let selectedIndex = hotKeyPopupButton.indexOfSelectedItem
        guard HotKeyConfiguration.supportedKeys.indices.contains(selectedIndex) else { return }

        preferencesStore.updateHotKey(
            keyCode: HotKeyConfiguration.supportedKeys[selectedIndex].keyCode,
            modifiers: selectedModifiers
        )

        refreshFromPreferences()
    }

    @objc
    private func strokeWidthChanged() {
        preferencesStore.updateStrokeWidth(CGFloat(strokeWidthSlider.doubleValue))
        refreshFromPreferences()
    }

    @objc
    private func fadeDurationChanged() {
        preferencesStore.updateFadeDuration(fadeDurationSlider.doubleValue)
        refreshFromPreferences()
    }

    @objc
    private func launchAtLoginChanged() {
        preferencesStore.updateLaunchAtLogin(launchAtLoginCheckbox.state == .on)
        refreshFromPreferences()
    }

    private var selectedModifiers: NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []
        if commandCheckbox.state == .on { modifiers.insert(.command) }
        if shiftCheckbox.state == .on { modifiers.insert(.shift) }
        if optionCheckbox.state == .on { modifiers.insert(.option) }
        if controlCheckbox.state == .on { modifiers.insert(.control) }
        return modifiers
    }

    private func configureWindow() {
        window?.title = "Highlighter Settings"
        window?.isReleasedWhenClosed = false
        window?.contentView = makeContentView()
    }

    private func configureControls() {
        hotKeyPopupButton.removeAllItems()
        hotKeyPopupButton.addItems(withTitles: HotKeyConfiguration.supportedKeys.map(\.title))
        hotKeyPopupButton.target = self
        hotKeyPopupButton.action = #selector(hotKeyChanged)

        [commandCheckbox, shiftCheckbox, optionCheckbox, controlCheckbox].forEach {
            $0.target = self
            $0.action = #selector(hotKeyChanged)
        }

        strokeWidthSlider.target = self
        strokeWidthSlider.action = #selector(strokeWidthChanged)

        fadeDurationSlider.target = self
        fadeDurationSlider.action = #selector(fadeDurationChanged)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginChanged)
    }

    private func makeContentView() -> NSView {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 280))

        let hotKeyRow = rowStack(label: "Hotkey", control: hotKeyPopupButton, valueLabel: hotKeyValueLabel)

        let modifiersStack = NSStackView(views: [commandCheckbox, shiftCheckbox, optionCheckbox, controlCheckbox])
        modifiersStack.orientation = .horizontal
        modifiersStack.spacing = 12
        modifiersStack.alignment = .centerY

        let strokeRow = rowStack(label: "Stroke Width", control: strokeWidthSlider, valueLabel: strokeWidthValueLabel)
        let fadeRow = rowStack(label: "Fade Duration", control: fadeDurationSlider, valueLabel: fadeDurationValueLabel)

        let stack = NSStackView(views: [
            hotKeyRow,
            modifiersStack,
            strokeRow,
            fadeRow,
            launchAtLoginCheckbox
        ])
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])

        return contentView
    }

    private func rowStack(label: String, control: NSView, valueLabel: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        control.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [titleLabel, control, valueLabel])
        row.orientation = .horizontal
        row.spacing = 14
        row.alignment = .centerY
        row.distribution = .fill

        if let slider = control as? NSSlider {
            slider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        } else if let popup = control as? NSPopUpButton {
            popup.widthAnchor.constraint(equalToConstant: 120).isActive = true
        }

        return row
    }

    private func refreshFromPreferences() {
        let preferences = preferencesStore.preferences

        if let index = HotKeyConfiguration.supportedKeys.firstIndex(where: { $0.keyCode == preferences.hotKey.keyCode }) {
            hotKeyPopupButton.selectItem(at: index)
        }

        commandCheckbox.state = preferences.hotKey.modifiers.contains(.command) ? .on : .off
        shiftCheckbox.state = preferences.hotKey.modifiers.contains(.shift) ? .on : .off
        optionCheckbox.state = preferences.hotKey.modifiers.contains(.option) ? .on : .off
        controlCheckbox.state = preferences.hotKey.modifiers.contains(.control) ? .on : .off

        strokeWidthSlider.doubleValue = preferences.strokeWidth
        fadeDurationSlider.doubleValue = preferences.fadeDuration
        launchAtLoginCheckbox.state = preferences.launchAtLogin ? .on : .off

        hotKeyValueLabel.stringValue = preferences.hotKey.displayString
        strokeWidthValueLabel.stringValue = String(format: "%.1f pt", preferences.strokeWidth)
        fadeDurationValueLabel.stringValue = String(format: "%.2f s", preferences.fadeDuration)
    }
}
