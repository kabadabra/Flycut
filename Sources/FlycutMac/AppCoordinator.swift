import AppKit
import SwiftUI
import FlycutCore
import FlycutPlatform

@MainActor final class AppCoordinator: NSObject, NSApplicationDelegate {
    let model = PaletteModel()
    private(set) var settings: FlycutSettings
    private let settingsStore: SettingsStore
    private let repository: SQLiteHistoryRepository
    private var persistence: HistoryPersistence?
    private(set) var history: HistoryService
    private var monitor: ClipboardMonitor!
    private var hotkey: HotkeyService!
    private var paste: PasteService!
    private var shell: MenuBarController!
    private var pasteTargets = PasteTargetHistory(ownProcessID: ProcessInfo.processInfo.processIdentifier)
    private var activationObserver: NSObjectProtocol?
    private var pasteTask: Task<Void, Never>?
    private var mutationTask: Task<Void, Never>?
    private var snapshot = HistorySnapshot(recent: [], favorites: [])
    private var registeredHotkey: FlycutHotkey?
    private let accessibility = AccessibilityService()
    private var terminating = false
    private let login: LoginItemService
    private var settingsWindow: NSWindow?
    private var importWindow: NSWindow?
    private var settingsEditor: SettingsModel?
    private var migration: MigrationCoordinator?
    private var sessionStartedNever = false
    private let bundleIdentity: String
    private let storageDirectory: URL?
    private let confirmRecovery: @MainActor (HistorySnapshot, HistorySnapshot) -> Bool
    /// Shared settings entry point.
    var showSettings: (() -> Void)?

    override convenience init() { self.init(bundleIdentifier: Bundle.main.bundleIdentifier) }

    static func settingsDomain(for bundleIdentifier: String?) -> String {
        (bundleIdentifier ?? "com.edynamics.flycut.preview") + ".settings.v3"
    }

    init(bundleIdentifier: String?, storageDirectory: URL? = nil,
         defaultsFactory: (String) -> UserDefaults? = { UserDefaults(suiteName: $0) },
         repository: SQLiteHistoryRepository? = nil,
         login: LoginItemService = LoginItemService(),
         confirmRecovery: @escaping @MainActor (HistorySnapshot, HistorySnapshot) -> Bool = AppCoordinator.askToRecover) {
        bundleIdentity = bundleIdentifier ?? "com.edynamics.flycut.preview"
        self.storageDirectory = storageDirectory
        self.confirmRecovery = confirmRecovery
        self.login = login
        // Never write v3 settings into the legacy source preferences domain.
        guard let defaults = defaultsFactory(Self.settingsDomain(for: bundleIdentifier)) else {
            fatalError("Unable to initialize isolated settings storage")
        }
        settingsStore = SettingsStore(defaults: defaults)
        settings = settingsStore.load()
        do { self.repository = try repository ?? SQLiteHistoryRepository() }
        catch { fatalError("Unable to initialize private history storage") }
        history = HistoryService(repository: self.repository, recentCapacity: settings.recentCapacity, favoriteCapacity: settings.favoriteCapacity)
        super.init()
    }
    private static func askToRecover(_ current: HistorySnapshot, _ saved: HistorySnapshot) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Load previously saved history?"
        alert.informativeText = "Saved history contains \(saved.recent.count) recent and \(saved.favorites.count) favorite clippings. Loading it replaces this session's \(current.recent.count + current.favorites.count) in-memory clippings. Export any session clippings you need before continuing. Cancel keeps saving disabled."
        alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Load Saved History")
        return alert.runModal() == .alertSecondButtonReturn
    }
    isolated deinit {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Observe before any Flycut activation. Clicking a persistent panel does
        // not invoke willPresent, but app B's preceding activation is still kept.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let processID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { self?.pasteTargets.observeActivation(processID: processID) }
        }
        pasteTargets.observeActivation(processID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
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
        model.isPaused = settings.rememberPause && settings.capturePaused
        monitor.isPaused = model.isPaused
        sessionStartedNever = settings.saveMode == .never
        showSettings = { [weak self] in self?.openSettings() }
        wireActions()
        configure(settings)
        // The monitor has already recorded the launch count without reading clipboard text.
        enqueue { coordinator in
            if coordinator.settings.saveMode != .never {
                do {
                    let directory = try coordinator.supportDirectory()
                    let disk = try SQLiteHistoryRepository(url: directory.appendingPathComponent("history.sqlite"))
                    let persistence = HistoryPersistence(destination: disk)
                    coordinator.persistence = persistence
                    try await persistence.restore(into: coordinator.repository)
                } catch {
                    coordinator.model.storageWarning = "Saved history could not be loaded and has been left untouched. Capture will continue in memory only for this session. Export any new clippings before quitting; repair or restore the saved database before relaunching."
                }
            }
            coordinator.monitor.start()
            do {
                if try await coordinator.shouldOfferMigration() { coordinator.openImport(discover: true) }
            } catch {
                coordinator.model.storageWarning = "Previous migration status could not be read. Saved history was left untouched. Use Settings to retry saved history or review an explicit import."
            }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        shell?.showPanel()
        return false
    }

    func configure(_ proposed: FlycutSettings) {
        var value = proposed; value.validate()
        let old = registeredHotkey
        if let hotkey, old != value.hotkey {
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
        value.capturePaused = model.isPaused
        if value.saveMode == .never { sessionStartedNever = true }
        settings = value
        settingsStore.save(value)
        model.apply(value)
        history = HistoryService(repository: repository, recentCapacity: value.recentCapacity, favoriteCapacity: value.favoriteCapacity,
                                 archive: value.saveMode == .never ? nil : value.autoSaveToLocation.map(EvictionArchive.init),
                                 archiveRecents: value.saveForgottenClippings, archiveFavorites: value.saveForgottenFavorites)
        shell?.applyAppearance(value)
        NSApp?.appearance = value.appearance == "system" ? nil : NSAppearance(named: value.appearance == "dark" ? .darkAqua : .aqua)
    }
    private func wireActions() {
        model.perform = { [weak self] in self?.perform($0) }
        model.pause = { [weak self] in
            guard let self else { return }
            model.isPaused.toggle(); monitor.isPaused = model.isPaused
            settings.capturePaused = model.isPaused; settingsStore.save(settings)
        }
        model.clear = { [weak self] in self?.enqueue { _ = try await $0.history.clearRecents() } }
        model.settings = { [weak self] in
            guard let self else { return }
            showSettings?()
        }
        model.about = {
            NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Flycut Evolution", .applicationVersion: FlycutVersion.current,
                .credits: NSAttributedString(string: "Maintained by Emerging Dynamics\nFork of TermiT/Flycut and Jumpcut\nFree and open source · MIT license")])
            NSApp.activate(ignoringOtherApps: true)
        }
        model.accessibility = { [weak self] in self?.accessibility.openSettings() }
        model.quit = { NSApp.terminate(nil) }
    }
    private func preparePresentation() {
        pasteTask?.cancel()
        pasteTargets.observeActivation(processID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        model.needsAccessibility = !accessibility.isTrusted
        model.showAll = false
        model.presentation = UUID()
    }
    private func perform(_ command: PaletteCommand) {
        switch command {
        case .next: model.selection.move(1)
        case .previous: model.selection.move(-1)
        case .digit(let value): model.selection.selectDigit(value)
        case .dismiss: shell.dismiss()
        case .activate: copyOrPaste(.paste)
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
        pasteTargets.observeActivation(processID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        let target = pasteTargets.previousExternalApp
        if mode == .paste {
            shell.prepareForPaste(sticky: settings.stickyPalette)
        } else if !settings.stickyPalette { shell.dismiss() }
        pasteTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            let result = await paste.copyOrPaste(clip.text, mode: mode, previousApp: target)
            guard !Task.isCancelled else { return }
            switch result {
            case .copied: model.message = "Copied."
            case .pasted: model.message = nil
            case .copiedNeedsAccessibility:
                model.reportAccessibilityDenied()
                shell.showPanel()
            case .copiedNoEditableTarget:
                model.message = "Copied. No editable text field is focused."
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
            } catch { model.message = "History could not be updated or saved. Check the automatic export folder and saved-history access, then try again." }
        }
    }
    private func persist(_ snapshot: HistorySnapshot) async throws {
        guard settings.saveMode != .never else { return }
        guard let persistence, try await persistence.save(snapshot) else {
            if model.storageWarning == nil {
                model.storageWarning = "This session is running in memory only. Saved history has not been replaced. Export new clippings before quitting."
            }
            return
        }
    }

    private func supportDirectory() throws -> URL {
        if let storageDirectory { return storageDirectory }
        return try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(bundleIdentity, isDirectory: true)
    }

    /// Reads a complete disk snapshot before granting writes. A cancelled or failed
    /// recovery leaves the working session and unread destination unchanged.
    private func prepareSaving(force: Bool = false) async throws -> (ready: Bool, restored: HistorySnapshot?) {
        if settings.saveMode != .never && persistence != nil && model.storageWarning == nil && !sessionStartedNever && !force { return (true, nil) }
        persistence = nil
        model.storageWarning = "Saving is paused until saved history is loaded successfully. Export session clippings before quitting or retry in Settings."
        let disk = try SQLiteHistoryRepository(url: try supportDirectory().appendingPathComponent("history.sqlite"))
        let gate = HistoryPersistence(destination: disk)
        let staging = try SQLiteHistoryRepository(inMemory: ())
        try await gate.restore(into: staging)
        let saved = try await staging.snapshot()
        let current = try await repository.snapshot()
        if !saved.recent.isEmpty || !saved.favorites.isEmpty || saved.migration != nil {
            guard confirmRecovery(current, saved) else { return (false, nil) }
            try await repository.replaceAll(saved)
            settings.recentCapacity = max(settings.recentCapacity, saved.recent.count)
            settings.favoriteCapacity = max(settings.favoriteCapacity, saved.favorites.count)
        }
        configure(settings)
        persistence = gate; sessionStartedNever = false; model.storageWarning = nil
        return (true, (!saved.recent.isEmpty || !saved.favorites.isEmpty || saved.migration != nil) ? saved : nil)
    }

    func shouldOfferMigration() async throws -> Bool {
        guard bundleIdentity == "com.edynamics.flycut" else { return false }
        // Read only marker metadata; save-never must not restore clipboard rows.
        return try SQLiteHistoryRepository.migrationMarker(at: supportDirectory().appendingPathComponent("history.sqlite")) == nil
    }

    /// Apply the same recovered capacity floor to the editor proposal that will
    /// configure the next capture. A separate later reduction remains possible.
    func applySettings(_ draft: FlycutSettings) async throws -> String? {
        model.message = nil
        var proposed = draft
        var message: String?
        if proposed.saveMode != .never {
            let preparation = try await prepareSaving()
            guard preparation.ready else { return "Changes cancelled. Export session history before loading saved history." }
            if let restored = preparation.restored {
                proposed.recentCapacity = max(proposed.recentCapacity, restored.recent.count)
                proposed.favoriteCapacity = max(proposed.favoriteCapacity, restored.favorites.count)
            }
        }
        if proposed.openAtLogin != settings.openAtLogin {
            let status = await login.setEnabled(proposed.openAtLogin)
            switch status {
            case .registered: proposed.openAtLogin = true
            case .requiresApproval: message = "Approve Flycut in Login Items Settings."; proposed.openAtLogin = true
            case .notRegistered: proposed.openAtLogin = false
            case .notFound, .error: message = "Login item change failed. Check Login Items Settings."; proposed.openAtLogin = settings.openAtLogin
            }
        }
        configure(proposed)
        let currentFeedback = [model.message, message].compactMap { $0 }
        return currentFeedback.isEmpty ? "Changes applied." : currentFeedback.joined(separator: " ")
    }

    private func openSettings() {
        shell.dismiss()
        if let settingsWindow { settingsEditor?.value = settings; settingsWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let editor = SettingsModel(settings)
        settingsEditor = editor
        editor.apply = { [weak self, weak editor] in
            guard let self, let editor else { return }
            editor.busy = true
            enqueue { coordinator in
                defer { editor.busy = false; editor.value = coordinator.settings }
                do {
                    editor.message = try await coordinator.applySettings(editor.value)
                } catch { editor.message = "Saved history could not be read. It has been left untouched. Export your session, repair the database, then use Retry Saved History." }
            }
        }
        editor.importLegacy = { [weak self] in self?.openImport(discover: self?.bundleIdentity == "com.edynamics.flycut") }
        editor.recover = { [weak self, weak editor] in
            self?.enqueue { coordinator in
                do {
                    if try await coordinator.prepareSaving(force: true).ready { editor?.value = coordinator.settings; editor?.message = "Saved history loaded. Choose a save mode and Apply Changes." } else { editor?.message = "Recovery cancelled. Saved history was left untouched; this session remains in memory until recovery succeeds." }
                } catch { editor?.message = "Saved history is still unreadable and was left untouched. Export session clippings before quitting." }
            }
        }
        settingsWindow = makeWindow(title: "Flycut Settings", view: SettingsView(model: editor))
    }
    private func openImport(discover: Bool) {
        if let importWindow { importWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        do {
            let coordinator: MigrationCoordinator
            if let migration { coordinator = migration } else {
                coordinator = MigrationCoordinator(destination: repository, backupDirectory: try supportDirectory().appendingPathComponent("Migration Backups"), memoryDestination: repository)
                migration = coordinator
            }
            let found = discover ? LegacySourceDiscovery.discover() : nil
            let editor = ImportModel(coordinator: coordinator, working: repository, sources: found?.sources ?? [])
            if !(found?.inaccessibleSources.isEmpty ?? true) { editor.error = "Some legacy sources need file access. Use Choose Preferences File to select them." }
            editor.close = { [weak self] in self?.importWindow?.close(); self?.importWindow = nil }
            editor.performImport = { [weak self] editor in
                guard let self, let source = editor.decision.selectedSource, editor.decision.beginImport() else { return }
                editor.busy = true
                let acceptedChoice = editor.decision.choice
                let acceptedMode = editor.decision.persistentSaveMode
                let acceptedReport = editor.report
                enqueue { owner in
                    defer { editor.busy = false }
                    do {
                        // Preparing disk history can change the destination: require a new preview.
                        let before = try await owner.repository.snapshot()
                        if acceptedReport?.inMemoryOnly == false {
                            guard try await owner.prepareSaving().ready else { editor.decision.failed(); editor.error = "Import cancelled before any source or history was changed."; return }
                            let after = try await owner.repository.snapshot()
                            if before != after { editor.decision.failed(); editor.preview(); return }
                        }
                        let result = try await coordinator.import(source: source, choice: acceptedChoice, persistentSaveMode: acceptedMode, expectedSourceFingerprint: acceptedReport?.sourceFingerprint, expectedDestinationFingerprint: acceptedReport?.destinationFingerprint)
                        var adopted = result.settingsForAdoption(preserving: owner.settings)
                        adopted.openAtLogin = owner.settings.openAtLogin
                        adopted.appearance = owner.settings.appearance
                        adopted.rememberPause = owner.settings.rememberPause
                        adopted.autoSaveToLocation = owner.settings.autoSaveToLocation
                        adopted.saveForgottenClippings = owner.settings.saveForgottenClippings
                        adopted.saveForgottenFavorites = owner.settings.saveForgottenFavorites
                        owner.configure(adopted)
                        if owner.settings.saveMode == .afterEachClip { try await owner.persist(owner.repository.snapshot()) }
                        editor.report = result; editor.complete = true; editor.decision.failed(); editor.error = nil
                        owner.settingsEditor?.value = owner.settings
                    } catch { editor.decision.failed(); editor.error = "Import failed. Your source is unchanged. The source or destination may have changed, or file access failed. Retry the preview and confirm again." }
                }
            }
            importWindow = makeWindow(title: "Import Legacy Flycut", view: MigrationView(model: editor))
        } catch { model.message = "Could not open import. Check access to Application Support." }
    }
    private func makeWindow<V: View>(title: String, view: V) -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = title; window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        return window
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
