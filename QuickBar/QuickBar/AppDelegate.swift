import AppKit
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var state: QuickBarState!
    var passwordCompletion: ((String?) -> Void)?
    var isAnyDialogOpen = false
    var eventMonitor: Any?
    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: "launchAtLogin") }
        set {
            UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to update login item: \(error)")
                }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        state = QuickBarState()

        if UserDefaults.standard.object(forKey: "launchAtLogin") == nil {
            launchAtLogin = true
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "QuickBar")
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 540)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: QuickBarView(state: state, delegate: self))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidShow(_:)),
            name: NSPopover.didShowNotification,
            object: popover
        )

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown, !self.isAnyDialogOpen else { return }
            if let popoverWindow = self.popover.contentViewController?.view.window,
               !popoverWindow.frame.contains(event.locationInWindow) {
                self.popover.performClose(nil)
            }
        }
    }

    @objc private func popoverDidShow(_ notification: Notification) {
        if let window = popover.contentViewController?.view.window {
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
        }
    }

    @objc private func appDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier,
           app.activationPolicy == .regular {
            state.frontmostAppBundleID = app.bundleIdentifier
            if popover.isShown && !isAnyDialogOpen {
                popover.performClose(nil)
            }
        }
    }

    private var contextMenu: NSMenu {
        let menu = NSMenu()
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = launchAtLogin ? .on : .off
        menu.addItem(launchItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit QuickBar", action: #selector(quitApp), keyEquivalent: "q"))
        return menu
    }

    @objc func handleStatusItemClick(_ sender: AnyObject?) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Dialogs

    private func showDialog(width: CGFloat, height: CGFloat, resizable: Bool = false, content: @escaping (@escaping () -> Void) -> AnyView) {
        var styleMask: NSWindow.StyleMask = [.titled, .closable]
        if resizable { styleMask.insert(.resizable) }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: styleMask,
                              backing: .buffered,
                              defer: false)
        window.title = ""
        window.level = .floating
        window.center()
        window.isReleasedWhenClosed = false

        let dismiss: () -> Void = { [weak self, weak window] in
            self?.isAnyDialogOpen = false
            window?.close()
        }

        let hostingView = NSHostingView(rootView: content(dismiss))
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        isAnyDialogOpen = true
        NSApp.activate(ignoringOtherApps: true)
    }

    func showPasswordPrompt(completion: @escaping (String?) -> Void) {
        passwordCompletion = completion

        showDialog(width: 280, height: 220) { [weak self] dismiss in
            AnyView(PasswordPromptView(
                onConfirm: { password in
                    self?.passwordCompletion?(password)
                    self?.passwordCompletion = nil
                    dismiss()
                },
                onCancel: {
                    self?.passwordCompletion?(nil)
                    self?.passwordCompletion = nil
                    dismiss()
                }
            ))
        }
    }

    func showKillFrozenAppDialog() {
        let apps = QuickBarServices.shared.getRunningApps()

        showDialog(width: 300, height: 400) { dismiss in
            AnyView(KillAppPickerView(
                apps: apps,
                onQuit: { app in
                    QuickBarServices.shared.forceQuitApp(app)
                    dismiss()
                },
                onCancel: { dismiss() }
            ))
        }
    }

    func showLargeFilesDialog(files: [LargeFile]) {
        showDialog(width: 480, height: 450, resizable: true) { dismiss in
            AnyView(LargeFilesView(
                files: files,
                onDismiss: { dismiss() }
            ))
        }
    }

    func showProcessMonitorDialog() {
        showDialog(width: 520, height: 520, resizable: true) { dismiss in
            AnyView(ProcessMonitorView(
                onDismiss: { dismiss() }
            ))
        }
    }

    func showScheduledShutdownDialog() {
        showDialog(width: 280, height: 380) { [weak self] dismiss in
            AnyView(ScheduledShutdownView(
                onSchedule: { date in
                    dismiss()
                    self?.handleScheduledShutdown(date: date)
                },
                onDismiss: { dismiss() }
            ))
        }
    }

    func showCancelShutdownDialog() {
        guard let scheduledTime = state.scheduledShutdownTime else { return }

        showDialog(width: 280, height: 260) { [weak self] dismiss in
            AnyView(CancelShutdownView(
                scheduledTime: scheduledTime,
                onCancel: {
                    dismiss()
                    self?.handleCancelShutdown()
                },
                onDismiss: { dismiss() }
            ))
        }
    }

    private func handleScheduledShutdown(date: Date) {
        guard let password = state.adminPassword else {
            showPasswordPrompt { [weak self] password in
                guard let password, let self else { return }
                state.adminPassword = password
                executeScheduledShutdown(date: date, password: password)
            }
            return
        }
        executeScheduledShutdown(date: date, password: password)
    }

    private func executeScheduledShutdown(date: Date, password: String) {
        DispatchQueue.main.async {
            self.state.setStatus(.inProgress, message: "Scheduling shutdown...")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = QuickBarServices.shared.scheduledShutdown(date: date, adminPassword: password)

            DispatchQueue.main.async {
                switch result {
                case .success(let pid):
                    let formatter = DateFormatter()
                    formatter.dateFormat = "h:mm a"
                    self.state.isShutdownScheduled = true
                    self.state.scheduledShutdownTime = date
                    self.state.shutdownPID = pid
                    self.state.setStatus(.success, message: "Shutdown scheduled for \(formatter.string(from: date))")
                case .failure(let error):
                    self.state.adminPassword = nil
                    self.state.setStatus(.failure, message: error.localizedDescription)
                }
            }
        }
    }

    private func handleCancelShutdown() {
        guard let password = state.adminPassword else {
            showPasswordPrompt { [weak self] password in
                guard let password, let self else { return }
                state.adminPassword = password
                executeCancelShutdown(password: password)
            }
            return
        }
        executeCancelShutdown(password: password)
    }

    private func executeCancelShutdown(password: String) {
        guard let pid = state.shutdownPID else {
            state.isShutdownScheduled = false
            state.scheduledShutdownTime = nil
            state.shutdownPID = nil
            state.setStatus(.success, message: "Scheduled shutdown canceled")
            return
        }

        DispatchQueue.main.async {
            self.state.setStatus(.inProgress, message: "Canceling shutdown...")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = QuickBarServices.shared.cancelScheduledShutdown(pid: pid, adminPassword: password)

            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.state.isShutdownScheduled = false
                    self.state.scheduledShutdownTime = nil
                    self.state.shutdownPID = nil
                    self.state.setStatus(.success, message: "Scheduled shutdown canceled")
                case .failure(let error):
                    self.state.adminPassword = nil
                    self.state.setStatus(.failure, message: error.localizedDescription)
                }
            }
        }
    }
}
