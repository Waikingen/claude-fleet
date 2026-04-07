import AppKit
import SwiftUI
import Combine
import ApplicationServices
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var panel: NSPanel?
    let viewModel = FleetViewModel()
    private var cancellables = Set<AnyCancellable>()

    private var localMonitor: Any?
    private var globalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single instance — quit if another copy is already running
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
        if running.count > 1 {
            NSApp.terminate(nil)
            return
        }

        // .regular = dock icon + menubar (so Cmd+Tab and window management work)
        NSApp.setActivationPolicy(.regular)

        // Build panel lazily — don't show it on launch
        setupPanel()
        setupStatusItem()
        viewModel.startWatching()
        setupKeyMonitor()
        requestAccessibilityIfNeeded()
        setupDarwinToggle()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Key monitor

    func setupKeyMonitor() {
        // Local monitor: handles keys when panel has focus
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // ⇧⌥Space — toggle regardless of panel state
            if Self.isFleetHotkey(event) {
                DispatchQueue.main.async { self.togglePanel() }
                return nil
            }
            guard let panel = self.panel, panel.isVisible else { return event }
            let cmd = event.modifierFlags.contains(.command)
            if cmd && event.keyCode == 13 { panel.orderOut(nil); return nil } // Cmd+W
            if event.keyCode == 53        { panel.orderOut(nil); return nil } // Esc
            if cmd && event.keyCode == 15 { self.viewModel.scan(); return nil } // Cmd+R → rescan
            // Enter → approve selected session
            if event.keyCode == 36 && !cmd {
                if let session = self.viewModel.selectedSession, session.needsAttention {
                    self.viewModel.continueSession(session)
                }
                return nil
            }
            // Backspace → deny selected session
            if event.keyCode == 51 && !cmd {
                if let session = self.viewModel.selectedSession, session.needsAttention {
                    self.viewModel.deny(session)
                }
                return nil
            }
            // Cmd+Enter → approve all safe
            if event.keyCode == 36 && cmd {
                self.viewModel.approveAllSafe()
                return nil
            }
            return event
        }

        // Global monitor: handles keys when any other app has focus
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, Self.isFleetHotkey(event) else { return }
            DispatchQueue.main.async { self.togglePanel() }
        }
    }

    private static func isFleetHotkey(_ event: NSEvent) -> Bool {
        guard event.keyCode == 49 else { return false } // Space
        let flags = event.modifierFlags
        let hasOption  = flags.contains(.option)
        let hasShift   = flags.contains(.shift)
        let hasCommand = flags.contains(.command)
        let hasControl = flags.contains(.control)
        guard hasOption && !hasControl else { return false }
        // Accept: ⇧⌥Space  or  ⌘⌥Space
        return (hasShift && !hasCommand) || (hasCommand && !hasShift)
    }

    // MARK: - Status item

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        updateButtonAppearance(button: button, count: 0)

        // Left-click → toggle panel
        button.action = #selector(handleStatusClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        viewModel.$attentionCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let button = self?.statusItem?.button else { return }
                self?.updateButtonAppearance(button: button, count: count)
            }
            .store(in: &cancellables)
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
        statusItem?.menu = nil  // remove after use so left-click still works normally
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        togglePanel()
        return false
    }

    @objc func togglePanel() {
        guard let panel = panel else { return }
        if panel.isVisible && panel.isKeyWindow {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quit() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor  { NSEvent.removeMonitor(m) }
        NSApp.terminate(nil)
    }

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

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
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

    // MARK: - Panel

    func setupPanel() {
        let hosting = NSHostingView(rootView: MainWindowView().environmentObject(viewModel))
        hosting.setFrameSize(NSSize(width: 1100, height: 700))

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel?.contentView = hosting
        panel?.title = "Claude Fleet"
        panel?.titlebarAppearsTransparent = true
        panel?.backgroundColor = .clear
        panel?.isOpaque = false
        panel?.isMovableByWindowBackground = true
        panel?.center()
        panel?.setFrameAutosaveName("ClaudeFleetPanel")
    }
}
