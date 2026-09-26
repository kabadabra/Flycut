import AppKit
import SwiftUI

/// AppKit delivers the first mouse-down immediately, without waiting to decide
/// whether it belongs to a double-click gesture.
final class ImmediateRowClickView: NSView {
    var onClick: (Int) -> Void

    init(onClick: @escaping (Int) -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick(event.clickCount)
    }
}

struct ImmediateRowClickSurface: NSViewRepresentable {
    var onClick: (Int) -> Void

    func makeNSView(context: Context) -> ImmediateRowClickView {
        ImmediateRowClickView(onClick: onClick)
    }

    func updateNSView(_ view: ImmediateRowClickView, context: Context) {
        view.onClick = onClick
    }
}
