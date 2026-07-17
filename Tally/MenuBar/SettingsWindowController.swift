import AppKit
import SwiftUI

/// Hosts the settings UI in a plain custom NSWindow (mirroring MainWindowController) instead of the
/// SwiftUI `Settings` scene. The scene's `showSettingsWindow:` action is unreliable for an LSUIElement
/// accessory app (and the selector name is OS-version-sensitive), which made the gear appear to hang.
///
/// Panes follow the macOS Settings convention: a fixed, non-customizable toolbar of selectable panes
/// (Accounts / General), with the window title naming the current pane. The toolbar is plain AppKit —
/// SwiftUI has no selectable-pane toolbar outside the `Settings` scene we can't use.
@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private static let accountsItem = NSToolbarItem.Identifier("pane.accounts")
    private static let generalItem = NSToolbarItem.Identifier("pane.general")

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(store: .shared, settings: .shared))
            let window = NSWindow(contentViewController: hosting)
            // Settings windows are conventionally fixed-size and not minimizable (macOS HIG).
            // No manual setContentSize: the hosting controller sizes the window to SettingsView's
            // fixed frame — a second (smaller) size authority here clipped the form's right/bottom.
            window.styleMask = [.titled, .closable]
            window.toolbarStyle = .preference
            let toolbar = NSToolbar(identifier: "TallySettingsToolbar")
            toolbar.delegate = self
            toolbar.allowsUserCustomization = false
            toolbar.displayMode = .iconAndLabel
            window.toolbar = toolbar
            toolbar.selectedItemIdentifier = SettingsPaneState.shared.pane == .accounts
                ? Self.accountsItem : Self.generalItem
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("TallySettingsWindow")
            window.center()
            self.window = window
        }
        window?.title = Self.paneTitle(SettingsPaneState.shared.pane)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // Nothing should start focused: an auto-focused rename field opens the window with a loud
        // blue focus ring on a random account.
        window?.makeFirstResponder(nil)
    }

    private static func paneTitle(_ pane: SettingsPaneState.Pane) -> String {
        pane == .accounts
            ? String(localized: "Accounts", bundle: AppLocale.bundle)
            : String(localized: "General", bundle: AppLocale.bundle)
    }

    @objc private func selectPane(_ sender: NSToolbarItem) {
        let pane: SettingsPaneState.Pane = sender.itemIdentifier == Self.accountsItem
            ? .accounts : .general
        SettingsPaneState.shared.select(pane)
        window?.title = Self.paneTitle(pane)
        window?.makeFirstResponder(nil)
    }
}

extension SettingsWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        if itemIdentifier == Self.accountsItem {
            item.label = String(localized: "Accounts", bundle: AppLocale.bundle)
            item.image = NSImage(systemSymbolName: "person.2", accessibilityDescription: item.label)
        } else {
            item.label = String(localized: "General", bundle: AppLocale.bundle)
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: item.label)
        }
        item.target = self
        item.action = #selector(selectPane(_:))
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.accountsItem, Self.generalItem]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.accountsItem, Self.generalItem]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.accountsItem, Self.generalItem]
    }
}

/// Which settings pane is showing — set by the AppKit toolbar, read by the SwiftUI form.
/// Persisted so the window reopens on the pane you last used (Settings HIG).
@MainActor
@Observable
final class SettingsPaneState {
    static let shared = SettingsPaneState()

    enum Pane: String { case accounts, general }

    var pane: Pane

    private init() {
        pane = Pane(rawValue: UserDefaults.standard.string(forKey: "settingsPane") ?? "") ?? .accounts
    }

    func select(_ newPane: Pane) {
        pane = newPane
        UserDefaults.standard.set(newPane.rawValue, forKey: "settingsPane")
    }
}
