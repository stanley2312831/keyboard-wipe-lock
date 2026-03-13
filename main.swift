import Cocoa

private let passwordKey = "wipe_mode_password"

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    private var passwordField: NSSecureTextField!
    private var lockButton: NSButton!

    private var lockWindows: [NSWindow] = []
    private var unlockPanel: NSPanel?
    private var unlockField: NSSecureTextField?
    private var unlockHint: NSTextField?

    private var isLocked = false
    private var globalEventMonitors: [Any] = []
    private var localEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        showSettings()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🧽"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open", action: #selector(showSettingsAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Enter Wipe Mode", action: #selector(enterWipeModeAction), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showSettingsAction() {
        showSettings()
    }

    @objc private func enterWipeModeAction() {
        enterWipeMode()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = buildSettingsWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func buildSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyboard Wipe Lock"
        window.center()

        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        window.contentView = content

        let title = NSTextField(labelWithString: "Set unlock password")
        title.frame = NSRect(x: 24, y: 160, width: 300, height: 24)
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        content.addSubview(title)

        passwordField = NSSecureTextField(frame: NSRect(x: 24, y: 120, width: 372, height: 28))
        passwordField.placeholderString = "Enter password (required)"
        passwordField.stringValue = UserDefaults.standard.string(forKey: passwordKey) ?? ""
        content.addSubview(passwordField)

        let desc = NSTextField(wrappingLabelWithString: "When wipe mode is ON, a black overlay blocks the screen and keyboard/mouse input stays in this app until password unlock.")
        desc.frame = NSRect(x: 24, y: 64, width: 372, height: 44)
        desc.font = NSFont.systemFont(ofSize: 12)
        desc.textColor = .secondaryLabelColor
        content.addSubview(desc)

        lockButton = NSButton(title: "Enter Wipe Mode", target: self, action: #selector(enterWipeModeAction))
        lockButton.frame = NSRect(x: 260, y: 20, width: 136, height: 30)
        lockButton.bezelStyle = .rounded
        content.addSubview(lockButton)

        let saveButton = NSButton(title: "Save Password", target: self, action: #selector(savePassword))
        saveButton.frame = NSRect(x: 140, y: 20, width: 110, height: 30)
        saveButton.bezelStyle = .rounded
        content.addSubview(saveButton)

        return window
    }

    @objc private func savePassword() {
        let value = passwordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            showAlert(text: "Password cannot be empty")
            return
        }
        UserDefaults.standard.set(value, forKey: passwordKey)
        showAlert(text: "Password saved")
    }

    private func showAlert(text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.runModal()
    }

    private func currentPassword() -> String? {
        let pwd = UserDefaults.standard.string(forKey: passwordKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pwd, !pwd.isEmpty { return pwd }
        return nil
    }

    private func enterWipeMode() {
        guard !isLocked else { return }
        guard currentPassword() != nil else {
            showSettings()
            showAlert(text: "Please set and save a password first.")
            return
        }

        isLocked = true
        settingsWindow?.orderOut(nil)

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false
            window.makeKeyAndOrderFront(nil)
            lockWindows.append(window)
        }

        let mainFrame = NSScreen.main?.frame ?? NSScreen.screens.first?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let panel = NSPanel(
            contentRect: NSRect(x: mainFrame.midX - 180, y: mainFrame.midY - 85, width: 360, height: 170),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.title = "Wipe Mode"
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let content = NSView(frame: panel.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content

        let hint = NSTextField(labelWithString: "Keyboard cleaning mode is active")
        hint.frame = NSRect(x: 20, y: 120, width: 320, height: 20)
        hint.alignment = .center
        hint.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        content.addSubview(hint)

        let subHint = NSTextField(labelWithString: "Enter password to unlock")
        subHint.frame = NSRect(x: 20, y: 98, width: 320, height: 16)
        subHint.alignment = .center
        subHint.textColor = .secondaryLabelColor
        content.addSubview(subHint)

        let field = NSSecureTextField(frame: NSRect(x: 40, y: 56, width: 280, height: 28))
        field.placeholderString = "Password"
        field.target = self
        field.action = #selector(unlockFromField)
        content.addSubview(field)

        let unlock = NSButton(title: "Unlock", target: self, action: #selector(unlockAction))
        unlock.frame = NSRect(x: 140, y: 18, width: 80, height: 30)
        content.addSubview(unlock)

        unlockPanel = panel
        unlockField = field
        unlockHint = subHint

        installEventInterception()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        field.becomeFirstResponder()
    }

    private func installEventInterception() {
        removeEventInterception()

        let mask: NSEvent.EventTypeMask = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            .systemDefined,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel,
            .gesture,
            .magnify,
            .swipe,
            .rotate,
            .smartMagnify,
            .quickLook,
            .pressure,
            .directTouch
        ]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            guard self.isLocked else { return event }

            if let panel = self.unlockPanel, let field = self.unlockField {
                if event.type == .keyDown || event.type == .keyUp || event.type == .flagsChanged {
                    if NSApp.keyWindow !== panel {
                        panel.makeKeyAndOrderFront(nil)
                        field.becomeFirstResponder()
                    }
                    return event
                }

                if event.window !== panel {
                    panel.makeKeyAndOrderFront(nil)
                    field.becomeFirstResponder()
                    return nil
                }
            }
            return event
        }

        globalEventMonitors.append(
            NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                guard let self, self.isLocked else { return }
                if let panel = self.unlockPanel, let field = self.unlockField {
                    NSApp.activate(ignoringOtherApps: true)
                    panel.makeKeyAndOrderFront(nil)
                    field.becomeFirstResponder()
                }
            }
        )
    }

    private func removeEventInterception() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        for monitor in globalEventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalEventMonitors.removeAll()
    }

    @objc private func unlockFromField() {
        unlockAction()
    }

    @objc private func unlockAction() {
        guard isLocked else { return }
        guard let expected = currentPassword() else { return }
        let input = unlockField?.stringValue ?? ""
        if input == expected {
            exitWipeMode()
        } else {
            unlockHint?.stringValue = "Wrong password"
            unlockHint?.textColor = .systemRed
            unlockField?.stringValue = ""
        }
    }

    private func exitWipeMode() {
        isLocked = false
        removeEventInterception()
        lockWindows.forEach { $0.orderOut(nil) }
        lockWindows.removeAll()
        unlockPanel?.orderOut(nil)
        unlockPanel = nil
        unlockField = nil
        unlockHint = nil
        showSettings()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
