import AppKit
import SwiftUI

/// Manages the main dashboard window (a menu-bar app has no window by default). Lazily created,
/// reused, and never released so its frame autosaves across opens.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: DashboardView(store: .shared, settings: .shared))
            // Bridge the SwiftUI `.toolbar` (countdown + refresh) onto the window's titlebar —
            // the titlebar IS the dashboard's header.
            hosting.sceneBridgingOptions = [.toolbars]
            let window = NSWindow(contentViewController: hosting)
            window.title = "Tally"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.toolbarStyle = .unified
            // Two ~300pt card columns side by side — the multi-account glance this app exists for.
            window.setContentSize(NSSize(width: 660, height: 360))
            window.isReleasedWhenClosed = false
            // v2: the old autosave frame (440×640 single column) would override the new default.
            window.setFrameAutosaveName("TallyMainWindow.v2")
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
