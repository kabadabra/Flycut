import XCTest
import AppKit
import FlycutCore
@testable import FlycutMac

@MainActor final class PaletteRowClickTests: XCTestCase {
    func testFirstMouseDownSelectsImmediatelyAndSecondActivatesOnce() {
        let model = PaletteModel()
        let clips = (0..<2).map { index in
            Clip(id: UUID(), text: "Synthetic \(index)", pasteboardType: "public.utf8-plain-text",
                 sourceAppName: nil, sourceBundleURL: nil, capturedAt: nil, collection: .recent, order: index)
        }
        model.selection.update(.init(recent: clips, favorites: []))
        var actions: [PaletteCommand] = []
        model.perform = { actions.append($0) }
        let view = ImmediateRowClickView { model.handleRowClick(clips[1].id, clickCount: $0) }

        view.mouseDown(with: mouseEvent(clickCount: 1))
        XCTAssertEqual(model.selection.selectedID, clips[1].id)
        XCTAssertTrue(actions.isEmpty)

        view.mouseDown(with: mouseEvent(clickCount: 2))
        XCTAssertEqual(model.selection.selectedID, clips[1].id)
        XCTAssertEqual(actions, [.activate])
    }

    private func mouseEvent(clickCount: Int) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [],
                           timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1,
                           clickCount: clickCount, pressure: 1)!
    }
}
