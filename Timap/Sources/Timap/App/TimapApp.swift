import AppKit
import SwiftUI
import TimapCore

/// We dropped `MenuBarExtra(.window)` because it doesn't expose any way to
/// programmatically open/close the popover, which we need for headless
/// screenshots. Hand-rolled `NSStatusItem + NSPopover` gives us that control.
@main
struct TimapAppEntry {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
