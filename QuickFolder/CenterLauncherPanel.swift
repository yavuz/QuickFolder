import AppKit
import SwiftUI

@MainActor
private final class CenterLauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class CenterLauncherPanelController: NSObject, NSWindowDelegate {
    private var panel: CenterLauncherPanel?
    private var onCloseHandler: (() -> Void)?

    var isShown: Bool {
        panel?.isVisible == true
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func show(
        store: FolderStore,
        presentationOverride: LauncherMode?,
        onClose: @escaping () -> Void
    ) {
        close()
        onCloseHandler = onClose

        let size = LauncherMode.compact.contentSize
        let panel = CenterLauncherPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: size.width, height: size.height)),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false

        panel.contentViewController = NSHostingController(
            rootView: LauncherRootView(presentationOverride: presentationOverride)
                .environmentObject(store)
        )

        if let screen = NSScreen.screenWithMouse() ?? NSScreen.main {
            panel.setFrame(centeredFrame(size: size, on: screen), display: false)
        }

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .quickFolderLauncherDidShow, object: nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let panel, panel.isVisible else { return }
        close()
        onCloseHandler?()
        onCloseHandler = nil
    }

    private func centeredFrame(size: CGSize, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - (size.width / 2),
            y: visible.midY - (size.height / 2)
        )
        return NSRect(origin: origin, size: NSSize(width: size.width, height: size.height))
    }
}

private extension NSScreen {
    static func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }
}
