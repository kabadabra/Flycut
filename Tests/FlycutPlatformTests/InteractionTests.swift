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
                                     isTrusted: { true }, activate: { _ in true },
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
        let accessibility = AccessibilityService(trust: { prompt in prompt }, open: { opened = $0; return true })
        XCTAssertFalse(accessibility.isTrusted)
        XCTAssertTrue(accessibility.requestPermission())
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
    var frontmost = true
    var key: UInt16? = 47
    let trusted: Bool
    init(trusted: Bool) { self.trusted = trusted }
    lazy var service = PasteService(client: PasteClient(
        write: { [unowned self] _ in actions.append("write"); return 2 },
        isTrusted: { [unowned self] in trusted },
        activate: { [unowned self] pid in actions.append("activate:\(pid)"); return true },
        waitForFocus: { [unowned self] in actions.append("wait") },
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
