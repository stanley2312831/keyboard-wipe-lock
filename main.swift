import Cocoa
import ApplicationServices

private let passwordKey = "wipe_mode_password"
private let optionTapThreshold = 5
private let optionTapWindow: TimeInterval = 2.0

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
    private var persistentGlobalMonitors: [Any] = []
    private var lockGlobalMonitors: [Any] = []
    private var localEventMonitor: Any?

    private var optionTapCount = 0
    private var lastOptionTapTime: TimeInterval = 0
    private var optionWasDown = false
    private var localOptionMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        requestAccessibilityPermissionIfNeeded()
        installOptionTapMonitor()
        showSettings()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🧽"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开设置", action: #selector(showSettingsAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "进入擦拭模式", action: #selector(enterWipeModeAction), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitAction), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func installOptionTapMonitor() {
        localOptionMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleOptionTap(event)
            return event
        }

        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleOptionTap(event)
        }
        if let monitor {
            persistentGlobalMonitors.append(monitor)
        }
    }

    private func handleOptionTap(_ event: NSEvent) {
        guard !isLocked else { return }

        let isOptionDown = event.modifierFlags.contains(.option)
        let now = Date().timeIntervalSince1970

        if isOptionDown && !optionWasDown {
            if now - lastOptionTapTime > optionTapWindow {
                optionTapCount = 1
            } else {
                optionTapCount += 1
            }
            lastOptionTapTime = now

            if optionTapCount >= optionTapThreshold {
                optionTapCount = 0
                DispatchQueue.main.async { [weak self] in
                    self?.enterWipeMode()
                }
            }
        }

        optionWasDown = isOptionDown
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

    func applicationWillTerminate(_ notification: Notification) {
        if let localOptionMonitor {
            NSEvent.removeMonitor(localOptionMonitor)
            self.localOptionMonitor = nil
        }
        for monitor in persistentGlobalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        persistentGlobalMonitors.removeAll()
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
        window.title = "键盘擦拭锁" 
        window.center()

        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        window.contentView = content

        let title = NSTextField(labelWithString: "设置解锁密码")
        title.frame = NSRect(x: 24, y: 160, width: 300, height: 24)
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        content.addSubview(title)

        passwordField = NSSecureTextField(frame: NSRect(x: 24, y: 120, width: 372, height: 28))
        passwordField.placeholderString = "输入密码（必填）"
        passwordField.stringValue = UserDefaults.standard.string(forKey: passwordKey) ?? ""
        content.addSubview(passwordField)

        let desc = NSTextField(wrappingLabelWithString: "进入擦拭模式后会全屏黑色遮罩，键盘/鼠标输入不会传给其他应用，直到输入密码解锁。快捷键：2 秒内连续按 5 下 Option。")
        desc.frame = NSRect(x: 24, y: 64, width: 372, height: 44)
        desc.font = NSFont.systemFont(ofSize: 12)
        desc.textColor = .secondaryLabelColor
        content.addSubview(desc)

        lockButton = NSButton(title: "进入擦拭模式", target: self, action: #selector(enterWipeModeAction))
        lockButton.frame = NSRect(x: 260, y: 20, width: 136, height: 30)
        lockButton.bezelStyle = .rounded
        content.addSubview(lockButton)

        let saveButton = NSButton(title: "保存密码", target: self, action: #selector(savePassword))
        saveButton.frame = NSRect(x: 140, y: 20, width: 110, height: 30)
        saveButton.bezelStyle = .rounded
        content.addSubview(saveButton)

        return window
    }

    @objc private func savePassword() {
        let value = passwordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            showAlert(text: "密码不能为空")
            return
        }
        UserDefaults.standard.set(value, forKey: passwordKey)
        showAlert(text: "密码已保存")
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
            showAlert(text: "请先设置并保存密码")
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
        panel.title = "擦拭模式"
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let content = NSView(frame: panel.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content

        let hint = NSTextField(labelWithString: "已进入键盘擦拭模式")
        hint.frame = NSRect(x: 20, y: 120, width: 320, height: 20)
        hint.alignment = .center
        hint.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        content.addSubview(hint)

        let subHint = NSTextField(labelWithString: "请输入密码解锁")
        subHint.frame = NSRect(x: 20, y: 98, width: 320, height: 16)
        subHint.alignment = .center
        subHint.textColor = .secondaryLabelColor
        content.addSubview(subHint)

        let field = NSSecureTextField(frame: NSRect(x: 40, y: 56, width: 280, height: 28))
        field.placeholderString = "密码"
        field.target = self
        field.action = #selector(unlockFromField)
        content.addSubview(field)

        let unlock = NSButton(title: "解锁", target: self, action: #selector(unlockAction))
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

        if let gm = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            guard let self, self.isLocked else { return }
            if let panel = self.unlockPanel, let field = self.unlockField {
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
                field.becomeFirstResponder()
            }
        } {
            lockGlobalMonitors.append(gm)
        }
    }

    private func removeEventInterception() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        for monitor in lockGlobalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        lockGlobalMonitors.removeAll()
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
            unlockHint?.stringValue = "密码错误"
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
