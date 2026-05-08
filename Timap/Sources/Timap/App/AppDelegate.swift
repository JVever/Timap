import AppKit
import SwiftUI
import TimapCore

/// IPC notification names — used by the `TimapShot` CLI to drive headless
/// screenshots. Distributed notifications cross process boundaries without
/// needing accessibility permissions.
enum TimapNotification {
    static let screenshotRequest = Notification.Name("com.timap.screenshot.request")
    static let screenshotDone    = Notification.Name("com.timap.screenshot.done")
    static let screenshotFailed  = Notification.Name("com.timap.screenshot.failed")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let state = AppState.load()
    private var screenshotObserver: Any?
    private var tickTimer: Timer?
    /// Global mouse-down monitor: closes the popover when the user clicks
    /// anywhere outside this app. We can't rely on the system's transient
    /// behavior because:
    ///   1. `.transient` only auto-closes if the popover's window is key,
    ///      and `.accessory` (LSUIElement) apps never make their popover
    ///      key, so the system never sees "focus lost".
    ///   2. macOS 15+ (Sequoia / Tahoe) tightened `.transient` further:
    ///      it started closing on *any* mouse-down, including clicks on
    ///      the popover's own buttons — clicking "Next" in the onboarding
    ///      flow dismissed the whole popover before the button's action
    ///      could fire. We use `.applicationDefined` and run our own
    ///      dismiss logic via these monitors.
    private var outsideClickMonitor: Any?
    /// Local key-down monitor for Esc inside the popover, since
    /// `.applicationDefined` popovers don't auto-close on Esc.
    private var escKeyMonitor: Any?

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in self.setUp() }
    }

    /// Called by AppKit whenever the user re-launches an already-running
    /// instance — e.g., double-clicks `/Applications/Timap.app` while
    /// the menu-bar process is alive. For an `LSUIElement` app there's
    /// no Dock icon and no window to re-focus, so by default the system
    /// does nothing visible: looks broken. Pop the popover instead, so
    /// the user gets immediate feedback that the app is alive.
    nonisolated func applicationShouldHandleReopen(
        _ sender: NSApplication, hasVisibleWindows flag: Bool
    ) -> Bool {
        Task { @MainActor in self.openPopoverIfNeeded() }
        return false
    }

    private func setUp() {
        // Status item — Timap brand mark (framed three-bar icon) in the
        // menu bar. The image is drawn programmatically as a template so
        // AppKit auto-tints for light/dark menubar.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = BrandIcon.makeMenubarTemplate()
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Popover — embeds the SwiftUI ContentView via NSHostingController.
        // We DON'T set a fixed contentSize. Instead, the hosting controller
        // forwards SwiftUI's intrinsic content size to NSPopover via
        // `preferredContentSize`, so the popover grows/shrinks as the team
        // list changes, capped by TeamRowsView's screen-aware max height.
        popover = NSPopover()
        // .applicationDefined means: don't auto-dismiss on user interaction.
        // We manage opening/closing ourselves via the status-item click
        // (togglePopover), the global outside-click monitor, and the local
        // Esc-key monitor. See the property comments above for why
        // .transient breaks for LSUIElement + macOS 15+.
        popover.behavior = .applicationDefined
        let host = NSHostingController(
            rootView: ContentView().environmentObject(state)
        )
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host

        // 1-min auto-tick for live mode.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.state.tick() }
        }

        // Listen for screenshot requests from the TimapShot CLI.
        screenshotObserver = DistributedNotificationCenter.default().addObserver(
            forName: TimapNotification.screenshotRequest,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleScreenshotRequest(notification) }
        }

        // First-launch nudge: on a fresh install the user has no Dock
        // icon and no obvious sign that double-clicking Timap.app did
        // anything. The menu-bar icon is easy to miss on a crowded
        // bar. Auto-open the onboarding popover so they see the
        // welcome screen immediately. Once they've onboarded, this
        // condition stays false and subsequent launches don't pop
        // unsolicited.
        //
        // 300ms delay: the status-bar layout pipeline isn't done by
        // the time we return from `setUp()`. If we call `popover.show`
        // immediately the button's window-relative bounds can still be
        // zero, causing the show to silently no-op or position the
        // popover off-screen. Waiting one frame is unreliable; ~300ms
        // is what NSStatusItem needs to settle in practice.
        if !state.hasOnboarded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openPopoverIfNeeded()
            }
        }
    }

    private func openPopoverIfNeeded() {
        guard !popover.isShown, let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startDismissMonitors()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startDismissMonitors()
        }
    }

    private func closePopover() {
        stopDismissMonitors()
        popover.performClose(nil)
    }

    private func startDismissMonitors() {
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    // Defensive geometry check: macOS 15+ (Sequoia /
                    // Tahoe) was observed to route mouse-down events
                    // intended for the popover's own buttons through
                    // this global monitor too — an artifact of the
                    // LSUIElement + non-key-window combination. Without
                    // this check, clicking "Next" inside the welcome
                    // popover triggers self.closePopover before the
                    // SwiftUI button action runs, and onboarding gets
                    // stuck on the first step.
                    if let popoverWindow = self.popover.contentViewController?.view.window,
                       popoverWindow.frame.contains(NSEvent.mouseLocation) {
                        return
                    }
                    self.closePopover()
                }
            }
        }
        if escKeyMonitor == nil {
            escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // Esc
                    Task { @MainActor in self?.closePopover() }
                    return nil
                }
                return event
            }
        }
    }

    private func stopDismissMonitors() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escKeyMonitor = nil
        }
    }

    // MARK: - Screenshot

    private func handleScreenshotRequest(_ notification: Notification) {
        guard let path = notification.userInfo?["path"] as? String else {
            postFailed(reason: "missing path")
            return
        }

        guard let button = statusItem.button else {
            postFailed(reason: "no status item button")
            return
        }
        let wasShown = popover.isShown
        if !wasShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        // Give SwiftUI a moment to render the first frame before we capture.
        // 0.4s is enough for the dotGrid map (~5000 dots) on M-series.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            let success = self.capture(to: path)
            if !wasShown {
                self.closePopover()
            }
            if success {
                self.postDone(path: path)
            } else {
                self.postFailed(reason: "capture failed")
            }
        }
    }

    private func capture(to path: String) -> Bool {
        // Render the popover's content view directly into a bitmap. This
        // path doesn't require Screen Recording permission, unlike
        // CGWindowListCreateImage (which started returning transparent
        // pixels on macOS Sonoma+ when the calling app isn't whitelisted).
        guard let view = popover.contentViewController?.view else {
            return false
        }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return false }
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            return false
        }
        view.cacheDisplay(in: bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }

    private func postDone(path: String) {
        DistributedNotificationCenter.default().postNotificationName(
            TimapNotification.screenshotDone,
            object: nil,
            userInfo: ["path": path],
            deliverImmediately: true
        )
    }

    private func postFailed(reason: String) {
        DistributedNotificationCenter.default().postNotificationName(
            TimapNotification.screenshotFailed,
            object: nil,
            userInfo: ["reason": reason],
            deliverImmediately: true
        )
    }
}
