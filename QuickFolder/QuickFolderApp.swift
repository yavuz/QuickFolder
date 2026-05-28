import AppKit
import SwiftUI

@main
struct QuickFolderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        UserDefaults.standard.register(defaults: [
            PreferenceKeys.recentLimit: 25,
            PreferenceKeys.finderHistoryEnabled: true,
            PreferenceKeys.hotKeyKey: HotKeyConfig.defaultKey,
            PreferenceKeys.hotKeyModifiers: HotKeyConfig.defaultModifiers,
            PreferenceKeys.selectedTerminal: TerminalApp.terminal.rawValue,
            PreferenceKeys.pinnedSectionExpanded: true,
            PreferenceKeys.recentSectionExpanded: true
        ])
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = FolderStore()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let hotKeyManager = GlobalHotKeyManager()
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        installPopover()
        installHotKey()
        observePreferenceChanges()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    private func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "QuickFolder") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "QF"
        }
        button.toolTip = "QuickFolder"
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func installPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 396, height: 540)
        popover.contentViewController = NSHostingController(
            rootView: QuickFolderMenuView()
                .environmentObject(store)
        )
        self.popover = popover
    }

    private func installHotKey() {
        hotKeyManager.onHotKey = { [weak self] in
            self?.togglePopover(nil)
        }
        registerHotKey()
    }

    private func observePreferenceChanges() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.registerHotKey()
            }
        }
    }

    private func registerHotKey() {
        let config = HotKeyConfig.current
        let status = hotKeyManager.register(config)
        if status == noErr {
            if store.errorMessage?.hasPrefix("Could not register shortcut") == true {
                store.errorMessage = nil
            }
        } else {
            store.errorMessage = "Could not register shortcut \(config.displayString). Try another shortcut."
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            store.refreshFinderRecents()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

enum PreferenceKeys {
    static let recentLimit = "recentLimit"
    static let finderHistoryEnabled = "finderHistoryEnabled"
    static let hotKeyKey = "hotKeyKey"
    static let hotKeyModifiers = "hotKeyModifiers"
    static let selectedTerminal = "selectedTerminal"
    static let pinnedSectionExpanded = "pinnedSectionExpanded"
    static let recentSectionExpanded = "recentSectionExpanded"
}
