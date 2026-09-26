import AppKit
import FlycutCore
import FlycutPlatform

@MainActor final class AppCoordinator: NSObject, NSApplicationDelegate {
    let model = PaletteModel()
    private(set) var settings: FlycutSettings
    private let settingsStore: SettingsStore
    private let repository: SQLiteHistoryRepository
    private var disk: SQLiteHistoryRepository?
    private var history: HistoryService
    private var monitor: ClipboardMonitor!
    private var hotkey: HotkeyService!
    private var paste: PasteService!
    private var shell: MenuBarController!
    private var previousApp: pid_t?
    private var pasteTask: Task<Void, Never>?
    private var mutationTask: Task<Void, Never>?
    private var snapshot = HistorySnapshot(recent: [], favorites: [])
    private var registeredHotkey: FlycutHotkey?
    private let accessibility = AccessibilityService()
    private var terminating = false
    /// Task 8 replaces this entry point with the grouped settings window.
    var showSettings: (() -> Void)?

    override init() {
        let defaults = Bundle.main.bundleIdentifier == nil ? (UserDefaults(suiteName: "com.edynamics.flycut.preview") ?? .standard) : .standard
        settingsStore = SettingsStore(defaults: defaults)
        settings = settingsStore.load()
        do { repository = try SQLiteHistoryRepository() }
        catch { fatalError("Unable to initialize private history storage") }
        history = HistoryService(repository: repository, recentCapacity: settings.recentCapacity, favoriteCapacity: settings.favoriteCapacity)
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = ClipboardMonitor(settings: { [weak self] in self?.settings ?? FlycutSettings() },
                                   topText: { [weak self] in self?.snapshot.recent.first?.text },
                                   onClip: { [weak self] clip in
            self?.enqueue { coordinator in
                _ = try await coordinator.history.capture(clip, removeDuplicates: coordinator.settings.removeDuplicates)
            }
        }, onAccessDenied: { [weak self] in self?.model.message = "Clipboard access was denied. Check macOS Privacy settings." })
        paste = PasteService { [weak self] count in self?.monitor.recordSelfWrite(changeCount: count) }
        shell = MenuBarController(model: model)
        shell.willPresent = { [weak self] in self?.preparePresentation() }
        shell.didDismiss = { [weak self] in self?.pasteTask?.cancel() }
        hotkey = HotkeyService { [weak self] in self?.shell.showPanel() }
        wireActions()
        configure(settings)
        // The monitor has already recorded the launch count without reading clipboard text.
        enqueue { coordinator in
            if coordinator.settings.saveMode != .never {
                let identity = Bundle.main.bundleIdentifier ?? "com.edynamics.flycut.preview"
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(identity, isDirectory: true)
                let disk = try SQLiteHistoryRepository(url: directory.appendingPathComponent("history.sqlite"))
                coordinator.disk = disk
                try await coordinator.repository.replaceAll(disk.snapshot())
            }
            coordinator.monitor.start()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        shell?.showPanel()
        return false
    }

    func configure(_ proposed: FlycutSettings) {
        var value = proposed; value.validate()
        let old = registeredHotkey
        if old != value.hotkey {
            do { try hotkey.register(value.hotkey); registeredHotkey = value.hotkey }
            catch {
                if let old, (try? hotkey.register(old)) != nil {
                    value.hotkey = old
                    model.message = "Shortcut unavailable. Your previous shortcut is still active."
                } else {
                    registeredHotkey = nil
                    model.message = "Global shortcut disabled because it could not be registered. Use the menu bar icon."
                }
            }
        }
        settings = value
        settingsStore.save(value)
        model.selection.wraparound = value.wraparoundPalette
        model.showSource = value.displayClippingSource
        model.previewLength = value.previewCharacterCount
        history = HistoryService(repository: repository, recentCapacity: value.recentCapacity, favoriteCapacity: value.favoriteCapacity)
    }
    private func wireActions() {
        model.perform = { [weak self] in self?.perform($0) }
        model.copy = { [weak self] in self?.copyOrPaste(.copy) }
        model.pause = { [weak self] in
            guard let self else { return }
            model.isPaused.toggle(); monitor.isPaused = model.isPaused
        }
        model.clear = { [weak self] in self?.enqueue { _ = try await $0.history.clearRecents() } }
        model.merge = { [weak self] in self?.enqueue { _ = try await $0.history.mergeAll() } }
        model.settings = { [weak self] in
            guard let self else { return }
            if let showSettings { showSettings() } else {
                let alert = NSAlert()
                alert.messageText = "Flycut Settings"
                alert.informativeText = "The grouped settings editor is coming in the next preview task. Capture pause, favorites, export and keyboard help are available in the palette."
                alert.runModal()
            }
        }
        model.about = {
            NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Flycut", .applicationVersion: FlycutVersion.current,
                .credits: NSAttributedString(string: "Maintained by Emerging Dynamics\nFork of TermiT/Flycut and Jumpcut\nFree and open source · MIT license")])
            NSApp.activate(ignoringOtherApps: true)
        }
        model.accessibility = { [weak self] in self?.accessibility.openSettings() }
        model.quit = { NSApp.terminate(nil) }
    }
    private func preparePresentation() {
        pasteTask?.cancel()
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = app.processIdentifier
        }
        model.needsAccessibility = !accessibility.isTrusted
        model.presentation = UUID()
    }
    private func perform(_ command: PaletteCommand) {
        switch command {
        case .next: model.selection.move(1)
        case .previous: model.selection.move(-1)
        case .digit(let value): model.selection.selectDigit(value)
        case .dismiss: shell.dismiss()
        case .paste: copyOrPaste(.paste)
        case .favorite:
            guard let clip = model.selection.selected, clip.collection == .recent else { return }
            enqueue { _ = try await $0.history.favorite(id: clip.id) }
        case .switchCollection: model.selection.collection = model.selection.collection == .recent ? .favorite : .recent
        case .delete:
            guard let clip = model.selection.selected else { return }
            enqueue { _ = try await $0.history.delete(id: clip.id) }
        case .exportSelected: if let clip = model.selection.selected { export([clip]) }
        case .exportAll: export(model.selection.collection == .recent ? snapshot.recent : snapshot.favorites)
        }
    }
    private func copyOrPaste(_ mode: PasteMode) {
        guard let clip = model.selection.selected else { return }
        pasteTask?.cancel()
        let target = previousApp
        if mode == .paste || !settings.stickyPalette { shell.dismiss() }
        pasteTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            let result = await paste.copyOrPaste(clip.text, mode: mode, previousApp: target)
            guard !Task.isCancelled else { return }
            switch result {
            case .copied: model.message = "Copied."
            case .pasted: model.message = nil
            case .copiedNeedsAccessibility:
                model.message = "Copied. Allow Accessibility access to paste automatically."
                model.needsAccessibility = true
                shell.showPanel()
            case .copiedPasteUnavailable:
                model.message = "Copied. Paste manually in the destination app."
                shell.showPanel()
            case .writeFailed:
                model.message = "Could not write to the clipboard."
                shell.showPanel()
            }
            if settings.pasteMovesToTop, result != .writeFailed {
                enqueue { _ = try await $0.history.moveToTop(id: clip.id) }
            }
        }
    }
    private func export(_ clips: [Clip]) {
        guard !clips.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Flycut.txt"
        panel.directoryURL = settings.saveToLocation
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try clips.reversed().map(\.text).joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            model.message = "Export saved."
        } catch { model.message = "Unable to save the export. Choose another location." }
    }
    /// Serialize capture and UI writes; shutdown waits for the same queue before persisting.
    private func enqueue(_ operation: @escaping @MainActor (AppCoordinator) async throws -> Void) {
        let previous = mutationTask
        mutationTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                try await operation(self)
                snapshot = try await repository.snapshot()
                model.selection.update(snapshot)
                if settings.saveMode == .afterEachClip { try await persist(snapshot) }
            } catch { model.message = "History could not be updated or saved. Please try again." }
        }
    }
    private func persist(_ snapshot: HistorySnapshot) async throws {
        guard settings.saveMode != .never else { return }
        if disk == nil {
            let identity = Bundle.main.bundleIdentifier ?? "com.edynamics.flycut.preview"
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(identity, isDirectory: true)
            disk = try SQLiteHistoryRepository(url: directory.appendingPathComponent("history.sqlite"))
        }
        try await disk?.replaceAll(snapshot)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        monitor?.stop(); hotkey?.unregister(); pasteTask?.cancel()
        let pending = mutationTask
        Task {
            await pending?.value
            do {
                if settings.saveMode != .never { try await persist(repository.snapshot()) }
                sender.reply(toApplicationShouldTerminate: true)
            } catch {
                terminating = false
                model.message = "History could not be saved. Quit cancelled."
                shell.showPanel()
                sender.reply(toApplicationShouldTerminate: false)
                monitor.start()
                if let registeredHotkey { try? hotkey.register(registeredHotkey) }
            }
        }
        return .terminateLater
    }
}
