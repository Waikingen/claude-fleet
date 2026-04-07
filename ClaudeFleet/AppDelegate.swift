import AppKit
import ApplicationServices
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var panel: NSPanel?

    let webVC = WebViewController()
    let daemonBridge = DaemonBridge()

    private var localMonitor: Any?
    private var globalMonitor: Any?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance enforcement
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
        if running.count > 1 {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.regular)

        setupPanel()
        setupStatusItem()
        setupKeyMonitor()
        setupDarwinToggle()
        requestAccessibilityIfNeeded()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Wire bridges
        daemonBridge.onStateUpdate = { [weak self] (stateJSON: String) -> Void in
            self?.webVC.pushState(stateJSON)
        }
        daemonBridge.onConnectionChange = { [weak self] (connected: Bool) -> Void in
            self?.webVC.pushDaemonStatus(connected)
        }
        daemonBridge.onAttentionCountChange = { [weak self] (count: Int) -> Void in
            guard let button = self?.statusItem?.button else { return }
            self?.updateButtonAppearance(button: button, count: count)
        }
        webVC.onCommand = { [weak self] (cmd: [String: Any]) -> Void in
            self?.daemonBridge.mapAndSend(cmd)
        }

        daemonBridge.startWatching()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        togglePanel()
        return false
    }

    // MARK: - Panel

    private func setupPanel() {
        _ = webVC.view // force loadView

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel?.contentViewController = webVC
        panel?.title = ""
        panel?.titlebarAppearsTransparent = true
        panel?.backgroundColor = .clear
        panel?.isOpaque = false
        panel?.level = .floating
        panel?.isMovableByWindowBackground = true
        panel?.center()
        panel?.setFrameAutosaveName("ClaudeFleetPanel")
        panel?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel?.becomesKeyOnlyIfNeeded = true
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        updateButtonAppearance(button: button, count: 0)

        button.action = #selector(handleStatusClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleStatusClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "Claude Fleet", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let showItem = NSMenuItem(title: "Show / Hide", action: #selector(togglePanel), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Claude Fleet", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func updateButtonAppearance(button: NSStatusBarButton, count: Int) {
        if count > 0 {
            button.image = nil
            button.title = "⚡ \(count)"
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Claude Fleet")
            button.image?.isTemplate = true
        }
    }

    // MARK: - Key monitor

    private func setupKeyMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Global hotkey: toggle panel
            if Self.isFleetHotkey(event) {
                DispatchQueue.main.async { self.togglePanel() }
                return nil
            }

            guard let panel = self.panel, panel.isVisible else { return event }

            let cmd = event.modifierFlags.contains(.command)

            // Cmd+W → close panel
            if cmd && event.keyCode == 13 { panel.orderOut(nil); return nil }
            // Esc → close panel
            if event.keyCode == 53 { panel.orderOut(nil); return nil }

            // Forward all other keyDown events to the web view
            self.forwardKeyToWebView(event)
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, Self.isFleetHotkey(event) else { return }
            DispatchQueue.main.async { self.togglePanel() }
        }
    }

    private func forwardKeyToWebView(_ event: NSEvent) {
        guard let chars = event.characters else { return }

        let mods = event.modifierFlags
        let ctrl = mods.contains(.control)
        let alt = mods.contains(.option)
        let shift = mods.contains(.shift)
        let meta = mods.contains(.command)

        // Escape special chars for JS string
        let escaped = chars
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        let js = """
        (function() {
            var e = new KeyboardEvent('keydown', {
                key: '\(escaped)',
                keyCode: \(event.keyCode),
                ctrlKey: \(ctrl),
                altKey: \(alt),
                shiftKey: \(shift),
                metaKey: \(meta),
                bubbles: true
            });
            document.dispatchEvent(e);
        })();
        """
        webVC.webView?.evaluateJavaScript(js) { _, _ in }
    }

    private static func isFleetHotkey(_ event: NSEvent) -> Bool {
        guard event.keyCode == 49 else { return false } // Space
        let flags = event.modifierFlags
        let hasOption  = flags.contains(.option)
        let hasShift   = flags.contains(.shift)
        let hasCommand = flags.contains(.command)
        let hasControl = flags.contains(.control)
        guard hasOption && !hasControl else { return false }
        // ⇧⌥Space or ⌘⌥Space
        return (hasShift && !hasCommand) || (hasCommand && !hasShift)
    }

    // MARK: - Toggle / Quit

    @objc func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
        }
    }

    @objc private func quit() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        daemonBridge.stopWatching()
        NSApp.terminate(nil)
    }

    // MARK: - Darwin notification

    private func setupDarwinToggle() {
        let name = "com.wiking.claude-fleet.toggle" as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { delegate.togglePanel() }
            },
            name, nil, .deliverImmediately
        )
    }

    // MARK: - Accessibility

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
