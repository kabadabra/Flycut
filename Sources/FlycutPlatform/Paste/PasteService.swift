import AppKit

public enum PasteMode: Sendable { case copy, paste }
public enum PasteResult: Equatable, Sendable {
    case copied, pasted, copiedNeedsAccessibility, copiedNoEditableTarget, copiedPasteUnavailable, writeFailed
}

/// All system effects are injected. A successful write returns the final change count.
@MainActor public struct PasteClient {
    public var write: (String) -> Int?
    public var changeCount: () -> Int
    public var isTrusted: () -> Bool
    public var activate: (pid_t) -> Bool
    public var waitForFocus: () async -> Void
    public var isFrontmost: (pid_t) -> Bool
    public var isEditableTarget: (pid_t) -> Bool
    public var pasteKeyCode: () -> UInt16?
    public var sendPaste: (UInt16) -> Bool

    public init(write: @escaping (String) -> Int?, changeCount: @escaping () -> Int, isTrusted: @escaping () -> Bool,
                activate: @escaping (pid_t) -> Bool, waitForFocus: @escaping () async -> Void,
                isFrontmost: @escaping (pid_t) -> Bool, isEditableTarget: @escaping (pid_t) -> Bool,
                pasteKeyCode: @escaping () -> UInt16?,
                sendPaste: @escaping (UInt16) -> Bool) {
        self.write = write; self.changeCount = changeCount; self.isTrusted = isTrusted; self.activate = activate
        self.waitForFocus = waitForFocus; self.isFrontmost = isFrontmost; self.isEditableTarget = isEditableTarget
        self.pasteKeyCode = pasteKeyCode; self.sendPaste = sendPaste
    }

    public static var system: PasteClient {
        PasteClient(write: { text in
            let board = NSPasteboard.general
            board.clearContents()
            guard board.setString(text, forType: .string) else { return nil }
            return board.changeCount
        }, changeCount: { NSPasteboard.general.changeCount }, isTrusted: { AXIsProcessTrusted() }, activate: { pid in
            guard pid != ProcessInfo.processInfo.processIdentifier,
                  let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return false }
            return app.activate(options: [.activateIgnoringOtherApps])
        }, waitForFocus: {
            try? await Task.sleep(for: .milliseconds(150))
        }, isFrontmost: { NSWorkspace.shared.frontmostApplication?.processIdentifier == $0 },
        isEditableTarget: { FocusedEditableTarget.isEditable(processID: $0) },
        pasteKeyCode: { KeyboardLayout().keyCode(for: "v") }, sendPaste: { code in
            guard let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { return false }
            down.flags = .maskCommand; up.flags = .maskCommand
            down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
            return true
        })
    }
}

@MainActor public final class PasteService {
    private let client: PasteClient
    private let recordSelfWrite: (Int) -> Void
    private var generation = 0

    public init(client: PasteClient = .system, recordSelfWrite: @escaping (Int) -> Void) {
        self.client = client; self.recordSelfWrite = recordSelfWrite
    }

    public func copyOrPaste(_ text: String, mode: PasteMode, previousApp: pid_t?) async -> PasteResult {
        generation += 1
        let request = generation
        guard let count = client.write(text) else { return .writeFailed }
        // Must precede any suspension: the clipboard monitor can poll during focus restoration.
        recordSelfWrite(count)
        guard mode == .paste else { return .copied }
        guard client.isTrusted() else { return .copiedNeedsAccessibility }
        guard let pid = previousApp, client.activate(pid) else {
            return .copiedPasteUnavailable
        }
        await client.waitForFocus()
        guard !Task.isCancelled, request == generation, client.isFrontmost(pid) else { return .copiedPasteUnavailable }
        guard client.isTrusted() else { return .copiedNeedsAccessibility }
        guard let code = client.pasteKeyCode() else { return .copiedPasteUnavailable }
        // Another process can replace the shared clipboard while focus is settling.
        guard client.changeCount() == count else { return .copiedPasteUnavailable }
        guard client.isEditableTarget(pid) else { return .copiedNoEditableTarget }
        // The Accessibility query crosses a process boundary; focus and clipboard can change while it runs.
        guard !Task.isCancelled, request == generation, client.isFrontmost(pid),
              client.changeCount() == count else { return .copiedPasteUnavailable }
        guard client.isTrusted() else { return .copiedNeedsAccessibility }
        return client.sendPaste(code) ? .pasted : .copiedPasteUnavailable
    }
}
