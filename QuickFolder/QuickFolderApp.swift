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
            PreferenceKeys.recentSectionExpanded: true,
            PreferenceKeys.launcherMode: LauncherMode.full.rawValue,
            PreferenceKeys.launcherPosition: LauncherPosition.menuBar.rawValue,
            PreferenceKeys.hotKeyUsesCompact: false
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
    private let centerLauncher = CenterLauncherPanelController()
    private var presentationOverride: LauncherMode?
    private let hotKeyManager = GlobalHotKeyManager()
    private var defaultsObserver: NSObjectProtocol?
    private var launcherModeObserver: NSObjectProtocol?
    private var launcherPositionObserver: NSObjectProtocol?
    private var closePopoverObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        installPopover()
        installHotKey()
        observePreferenceChanges()
        observeLauncherModeChanges()
        observeLauncherPositionChanges()
        observePopoverCloseRequests()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        if let launcherModeObserver {
            NotificationCenter.default.removeObserver(launcherModeObserver)
        }
        if let launcherPositionObserver {
            NotificationCenter.default.removeObserver(launcherPositionObserver)
        }
        if let closePopoverObserver {
            NotificationCenter.default.removeObserver(closePopoverObserver)
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
        button.action = #selector(statusItemTapped(_:))
        button.target = self
    }

    @objc private func statusItemTapped(_ sender: Any?) {
        toggleLauncher(fromHotKey: false)
    }

    private func installPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        self.popover = popover
        applyLauncherPresentation(to: popover)
    }

    private func installHotKey() {
        hotKeyManager.onHotKey = { [weak self] in
            self?.toggleLauncher(fromHotKey: true)
        }
        registerHotKey()
    }

    private func activeLauncherMode() -> LauncherMode {
        presentationOverride ?? LauncherMode.current
    }

    private func shouldPresentCenteredCompact() -> Bool {
        activeLauncherMode() == .compact && LauncherPosition.current == .centerScreen
    }

    private var isLauncherVisible: Bool {
        (popover?.isShown == true) || centerLauncher.isShown
    }

    private func applyLauncherPresentation(to popover: NSPopover) {
        let mode = activeLauncherMode()
        popover.contentSize = NSSize(width: mode.contentSize.width, height: mode.contentSize.height)

        popover.contentViewController = NSHostingController(
            rootView: LauncherRootView(presentationOverride: presentationOverride)
                .environmentObject(store)
        )
    }

    private func observePopoverCloseRequests() {
        closePopoverObserver = NotificationCenter.default.addObserver(
            forName: .closeQuickFolderPopover,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closeLauncher()
            }
        }
    }

    private func observeLauncherModeChanges() {
        launcherModeObserver = NotificationCenter.default.addObserver(
            forName: .launcherModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isLauncherVisible {
                    self.closeLauncher()
                }
                if let popover = self.popover {
                    self.applyLauncherPresentation(to: popover)
                }
            }
        }
    }

    private func observeLauncherPositionChanges() {
        launcherPositionObserver = NotificationCenter.default.addObserver(
            forName: .launcherPositionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closeLauncher()
            }
        }
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

    private func closeLauncher() {
        popover?.performClose(nil)
        centerLauncher.close()
        presentationOverride = nil
    }

    private func toggleLauncher(fromHotKey: Bool) {
        if isLauncherVisible {
            closeLauncher()
            return
        }

        if fromHotKey, UserDefaults.standard.bool(forKey: PreferenceKeys.hotKeyUsesCompact) {
            presentationOverride = .compact
        } else {
            presentationOverride = nil
        }

        store.refreshFinderRecents()

        if shouldPresentCenteredCompact() {
            centerLauncher.show(
                store: store,
                presentationOverride: presentationOverride
            ) { [weak self] in
                self?.presentationOverride = nil
            }
            return
        }

        guard let button = statusItem?.button, let popover else { return }
        applyLauncherPresentation(to: popover)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .quickFolderLauncherDidShow, object: nil)
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
    static let launcherMode = "launcherMode"
    static let launcherPosition = "launcherPosition"
    static let hotKeyUsesCompact = "hotKeyUsesCompact"
}
