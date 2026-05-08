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
    /// anywhere outside this app. `.transient` behavior alone is unreliable
    /// in `.accessory` (LSUIElement) apps because the popover never becomes
    /// the key window, so the system never detects "focus lost".
    private var outsideClickMonitor: Any?

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
        popover.behavior = .transient
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
        startOutsideClickMonitor()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startOutsideClickMonitor()
        }
    }

    private func closePopover() {
        stopOutsideClickMonitor()
        popover.performClose(nil)
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
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
