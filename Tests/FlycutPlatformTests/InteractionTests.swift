import XCTest
import FlycutCore
@testable import FlycutPlatform

@MainActor final class InteractionTests: XCTestCase {
    func testCopyAndPasteSuppressMonitorCaptureEvenDuringFocusDelay() async {
        for mode in [PasteMode.copy, .paste] {
            let board = InteractionBoard()
            var captured = 0
            let monitor = ClipboardMonitor(pasteboard: board, settings: { FlycutSettings() }, topText: { nil }, onClip: { _ in captured += 1 })
            let client = PasteClient(write: { text in board.text = text; board.changeCount += 2; return board.changeCount },
                                     changeCount: { board.changeCount }, isTrusted: { true }, activate: { _ in true },
                                     waitForFocus: { monitor.pollOnce() }, isFrontmost: { _ in true },
                                     pasteKeyCode: { 47 }, sendPaste: { _ in true })
            let service = PasteService(client: client, recordSelfWrite: { monitor.recordSelfWrite(changeCount: $0) })
            _ = await service.copyOrPaste("selected", mode: mode, previousApp: 123)
            monitor.pollOnce()
            XCTAssertEqual(captured, 0)
            board.text = "external"; board.changeCount += 1
            monitor.pollOnce()
            XCTAssertEqual(captured, 1)
        }
    }

    func testAccessibilityAndLoginAdaptersExposeStatusAndErrors() async {
        var opened: URL?
        var trusted = false
        let accessibility = AccessibilityService(trust: { _ in trusted }, open: { opened = $0; return true })
        XCTAssertFalse(accessibility.isTrusted)
        XCTAssertFalse(accessibility.requestPermission())
        trusted = true
        XCTAssertTrue(accessibility.isTrusted)
        XCTAssertTrue(accessibility.openSettings())
        XCTAssertTrue(opened?.absoluteString.contains("Privacy_Accessibility") == true)
        let login = LoginItemService(client: LoginItemClient(status: { .requiresApproval }, register: {}, unregister: {}))
        XCTAssertEqual(login.status, .requiresApproval)
        let status = await login.setEnabled(true)
        XCTAssertEqual(status, .requiresApproval)
        let failing = LoginItemService(client: LoginItemClient(status: { .notRegistered }, register: { throw HotkeyError.system(-50) }, unregister: {}))
        if case .error = await failing.setEnabled(true) {} else { XCTFail("Must expose registration failure") }
    }

    func testDefaultHotkeyAndUnregister() throws {
        let client = FakeHotkey()
        let service = HotkeyService(client: client)
        try service.register(FlycutSettings().hotkey)
        XCTAssertEqual(client.key, 9)
        XCTAssertEqual(client.modifiers, 768) // Carbon command + shift
        service.unregister()
        XCTAssertEqual(client.removals, 1)
    }

    func testHotkeyConflictAndError() {
        let client = FakeHotkey()
        let service = HotkeyService(client: client)
        client.status = -9878
        XCTAssertThrowsError(try service.register(FlycutSettings().hotkey)) { XCTAssertEqual($0 as? HotkeyError, .conflict) }
        client.status = -50
        XCTAssertThrowsError(try service.register(FlycutSettings().hotkey)) { XCTAssertEqual($0 as? HotkeyError, .system(-50)) }
    }

    func testCopyAndDeniedPasteRecordFinalCountWithoutEvents() async {
        for mode in [PasteMode.copy, .paste] {
            let fixture = PasteFixture(trusted: false)
            let result = await fixture.service.copyOrPaste("selected", mode: mode, previousApp: 123)
            XCTAssertEqual(result, mode == .copy ? .copied : .copiedNeedsAccessibility)
            XCTAssertEqual(fixture.actions, ["write", "record:2"])
        }
    }

    func testNonQWERTYPasteRestoresFocusAndRecordsBeforeDelay() async {
        let fixture = PasteFixture(trusted: true)
        let result = await fixture.service.copyOrPaste("selected", mode: .paste, previousApp: 123)
        XCTAssertEqual(result, .pasted)
        XCTAssertEqual(fixture.actions, ["write", "record:2", "activate:123", "wait", "front:123", "key:47"])
    }

    func testLostFocusAndMissingLayoutDoNotSendEvents() async {
        let fixture = PasteFixture(trusted: true)
        fixture.frontmost = false
        let lost = await fixture.service.copyOrPaste("selected", mode: .paste, previousApp: 123)
        XCTAssertEqual(lost, .copiedPasteUnavailable)
        XCTAssertFalse(fixture.actions.contains("key:47"))
        fixture.frontmost = true
        fixture.key = nil
        let missing = await fixture.service.copyOrPaste("selected", mode: .paste, previousApp: 123)
        XCTAssertEqual(missing, .copiedPasteUnavailable)
    }

    func testClipboardReplacementDuringWaitDoesNotSendOrOverwrite() async {
        let fixture = PasteFixture(trusted: true)
        fixture.duringWait = { fixture.count = 3 }
        let result = await fixture.service.copyOrPaste("selected", mode: .paste, previousApp: 123)
        XCTAssertEqual(result, .copiedPasteUnavailable)
        XCTAssertFalse(fixture.actions.contains(where: { $0.hasPrefix("key:") }))
        XCTAssertEqual(fixture.actions.filter { $0 == "write" }.count, 1)
        XCTAssertEqual(fixture.count, 3)
    }

    func testTrustRevocationDuringWaitDoesNotSend() async {
        let fixture = PasteFixture(trusted: true)
        fixture.duringWait = { fixture.trusted = false }
        let result = await fixture.service.copyOrPaste("selected", mode: .paste, previousApp: 123)
        XCTAssertEqual(result, .copiedNeedsAccessibility)
        XCTAssertFalse(fixture.actions.contains(where: { $0.hasPrefix("key:") }))
    }

    func testCancelledSuspendedPasteDoesNotSend() async {
        let fixture = PasteFixture(trusted: true)
        let gate = FocusGate()
        fixture.duringWait = { await gate.wait() }
        let task = Task { await fixture.service.copyOrPaste("selected", mode: .paste, previousApp: 123) }
        await gate.waitUntilSuspended()
        task.cancel()
        gate.resume()
        let result = await task.value
        XCTAssertEqual(result, .copiedPasteUnavailable)
        XCTAssertFalse(fixture.actions.contains(where: { $0.hasPrefix("key:") }))
    }

    func testNewCopyInvalidatesSuspendedPaste() async {
        let fixture = PasteFixture(trusted: true)
        let gate = FocusGate()
        fixture.duringWait = { await gate.wait() }
        let task = Task { await fixture.service.copyOrPaste("first", mode: .paste, previousApp: 123) }
        await gate.waitUntilSuspended()
        _ = await fixture.service.copyOrPaste("second", mode: .copy, previousApp: nil)
        gate.resume()
        let result = await task.value
        XCTAssertEqual(result, .copiedPasteUnavailable)
        XCTAssertFalse(fixture.actions.contains(where: { $0.hasPrefix("key:") }))
    }

    func testLayoutIsResolvedAfterFocusChanges() async {
        let fixture = PasteFixture(trusted: true)
        fixture.duringWait = { fixture.key = 12 }
        let result = await fixture.service.copyOrPaste("selected", mode: .paste, previousApp: 123)
        XCTAssertEqual(result, .pasted)
        XCTAssertTrue(fixture.actions.contains("key:12"))
        XCTAssertFalse(fixture.actions.contains("key:47"))
    }

    func testLayoutBecomingUnavailableDuringWaitDoesNotSend() async {
        let fixture = PasteFixture(trusted: true)
        fixture.duringWait = { fixture.key = nil }
        let result = await fixture.service.copyOrPaste("selected", mode: .paste, previousApp: 123)
        XCTAssertEqual(result, .copiedPasteUnavailable)
        XCTAssertFalse(fixture.actions.contains(where: { $0.hasPrefix("key:") }))
    }

    func testLayoutMapsCharacterUsingInjectedTranslation() {
        let layout = KeyboardLayout { code in code == 47 ? "v" : "x" }
        XCTAssertEqual(layout.keyCode(for: "v"), 47)
        XCTAssertNil(layout.keyCode(for: "z"))
    }
}

@MainActor private final class FakeHotkey: HotkeyClient {
    var key: UInt32?; var modifiers: UInt32?; var removals = 0; var status: Int32 = 0
    func register(keyCode: UInt32, modifiers: UInt32, onPress: @escaping @MainActor () -> Void) -> Int32 {
        key = keyCode; self.modifiers = modifiers; return status
    }
    func unregister() { removals += 1 }
}

@MainActor private final class PasteFixture {
    var actions: [String] = []
    var count = 2
    var frontmost = true
    var key: UInt16? = 47
    var trusted: Bool
    var duringWait: @MainActor () async -> Void = {}
    init(trusted: Bool) { self.trusted = trusted }
    lazy var service = PasteService(client: PasteClient(
        write: { [unowned self] _ in actions.append("write"); return 2 },
        changeCount: { [unowned self] in count },
        isTrusted: { [unowned self] in trusted },
        activate: { [unowned self] pid in actions.append("activate:\(pid)"); return true },
        waitForFocus: { [unowned self] in actions.append("wait"); await duringWait() },
        isFrontmost: { [unowned self] pid in actions.append("front:\(pid)"); return frontmost },
        pasteKeyCode: { [unowned self] in key },
        sendPaste: { [unowned self] key in actions.append("key:\(key)"); return true }
    ), recordSelfWrite: { [unowned self] count in actions.append("record:\(count)") })
}

@MainActor private final class InteractionBoard: PasteboardClient {
    var changeCount = 0
    var text = ""
    var advertisedTypes = ["public.utf8-plain-text"]
    func readPlainText() -> PasteboardReadResult { .text(text) }
}

@MainActor private final class FocusGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            observer?.resume(); observer = nil
        }
    }
    func waitUntilSuspended() async {
        if continuation != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func resume() { continuation?.resume(); continuation = nil }
}
