import AppKit
import SwiftUI

@MainActor final class MenuBarController: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let popover = NSPopover()
    let panel = PalettePanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 500), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
    var willPresent: () -> Void = {}
    var didDismiss: () -> Void = {}
    private var keyboard: PaletteKeyboard?
    init(model: PaletteModel) {
        super.init()
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Flycut clipboard history")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 520, height: 500)
        popover.contentViewController = NSHostingController(rootView: PaletteView(model: model))
        panel.contentViewController = NSHostingController(rootView: PaletteView(model: model))
        panel.title = "Flycut History"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        keyboard = PaletteKeyboard(model: model) { [weak self] window in
            guard let self, let window else { return false }
            return window === self.panel || window === self.popover.contentViewController?.view.window
        }
    }
    @objc private func toggle() {
        if popover.isShown || panel.isVisible { dismiss(); return }
        guard let button = item.button else { return }
        willPresent()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    func showPanel() {
        willPresent()
        popover.performClose(nil)
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    /// Keep a sticky panel visible while PasteService activates the destination.
    /// orderFrontRegardless does not make the panel key or activate Flycut.
    func prepareForPaste(sticky: Bool) {
        guard sticky else { dismiss(); return }
        if popover.isShown {
            if let frame = popover.contentViewController?.view.window?.frame {
                panel.setFrameOrigin(frame.origin)
            }
            popover.performClose(nil)
        }
        panel.orderFrontRegardless()
    }

    func dismiss() { popover.performClose(nil); panel.orderOut(nil); didDismiss() }
}
