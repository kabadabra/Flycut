import Foundation
import XCTest
@testable import FlycutCore
@testable import FlycutPlatform

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    func testLaunchPreservesClipboardAndOneEventPerCount() {
        let board = FakePasteboard(count: 7, result: .text("old"))
        let sink = ClipSink()
        let monitor = makeMonitor(board: board, sink: sink)
        XCTAssertEqual(board.readCount, 0)
        monitor.pollOnce()
        XCTAssertTrue(sink.clips.isEmpty)
        board.changeCount = 8
        board.result = .text("new")
        monitor.pollOnce()
        monitor.pollOnce()
        XCTAssertEqual(board.readCount, 1)
        XCTAssertEqual(sink.clips.map(\.text), ["new"])
        XCTAssertEqual(sink.clips.first?.sourceAppName, "Source")
        XCTAssertEqual(sink.clips.first?.sourceBundleURL, "file:///Applications/Source.app")
        XCTAssertEqual(sink.clips.first?.capturedAt, Date(timeIntervalSince1970: 100))
    }

    func testDelayedProviderChangeIsDiscarded() {
        let board = FakePasteboard(count: 1, result: .text("stale"))
        let sink = ClipSink()
        let monitor = makeMonitor(board: board, sink: sink)
        board.changeCount = 2
        board.onRead = { board.changeCount = 3 }
        monitor.pollOnce()
        XCTAssertTrue(sink.clips.isEmpty)
        board.onRead = nil
        board.result = .text("fresh")
        monitor.pollOnce()
        XCTAssertEqual(sink.clips.map(\.text), ["fresh"])
    }

    func testOwnWriteIsSuppressedButSubsequentCopyIsCaptured() {
        let board = FakePasteboard(count: 1, result: .text("own"))
        let sink = ClipSink()
        let monitor = makeMonitor(board: board, sink: sink)
        board.changeCount = 2
        monitor.recordSelfWrite(changeCount: 2)
        monitor.pollOnce()
        XCTAssertEqual(board.readCount, 0)
        board.changeCount = 3
        board.result = .text("other")
        monitor.pollOnce()
        XCTAssertEqual(sink.clips.map(\.text), ["other"])
    }

    func testDeniedReadDoesNotEmitClipAndReportsDenial() {
        let board = FakePasteboard(count: 1, result: .denied)
        let sink = ClipSink()
        var denied = 0
        let monitor = makeMonitor(board: board, sink: sink, onDenied: { denied += 1 })
        board.changeCount = 2
        monitor.pollOnce()
        monitor.pollOnce()
        XCTAssertTrue(sink.clips.isEmpty)
        XCTAssertEqual(denied, 1)
        XCTAssertEqual(board.readCount, 1)
    }

    func testRejectedTextDoesNotRequestMetadata() {
        let board = FakePasteboard(count: 1, result: .text("same"))
        let sink = ClipSink()
        var metadataCalls = 0
        let monitor = ClipboardMonitor(
            pasteboard: board,
            settings: { FlycutSettings() },
            topText: { "same" },
            source: { metadataCalls += 1; return ClipboardSource(appName: "Source", bundleURL: nil) },
            now: { Date(timeIntervalSince1970: 100) },
            onClip: { sink.clips.append($0) }
        )
        board.changeCount = 2
        monitor.pollOnce()
        XCTAssertTrue(sink.clips.isEmpty)
        XCTAssertEqual(metadataCalls, 0)
    }

    private func makeMonitor(board: FakePasteboard, sink: ClipSink, onDenied: @escaping @MainActor () -> Void = {}) -> ClipboardMonitor {
        let monitor = ClipboardMonitor(
            pasteboard: board,
            settings: { FlycutSettings() },
            topText: { nil },
            source: { ClipboardSource(appName: "Source", bundleURL: "file:///Applications/Source.app") },
            now: { Date(timeIntervalSince1970: 100) },
            onClip: { sink.clips.append($0) },
            onAccessDenied: onDenied
        )
        return monitor
    }
}

@MainActor private final class ClipSink { var clips: [Clip] = [] }

@MainActor private final class FakePasteboard: PasteboardClient {
    var changeCount: Int
    var advertisedTypes = ["public.utf8-plain-text"]
    var result: PasteboardReadResult
    var readCount = 0
    var onRead: (() -> Void)?

    init(count: Int, result: PasteboardReadResult) {
        changeCount = count
        self.result = result
    }

    func readPlainText() -> PasteboardReadResult {
        readCount += 1
        onRead?()
        return result
    }
}
