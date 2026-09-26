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

/// The optional type detail remains selectable while its mouse-down follows
/// the same immediate row-selection path as the rest of the clipping.
final class SelectableTypeField: NSTextField {
    var onClick: (Int) -> Void = { _ in }

    override func mouseDown(with event: NSEvent) {
        onClick(event.clickCount)
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }
}

struct SelectableTypeLabel: NSViewRepresentable {
    let text: String
    let onClick: (Int) -> Void

    func makeNSView(context: Context) -> SelectableTypeField {
        let field = SelectableTypeField(labelWithString: text)
        field.isSelectable = true
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .secondaryLabelColor
        field.lineBreakMode = .byTruncatingTail
        field.onClick = onClick
        return field
    }

    func updateNSView(_ field: SelectableTypeField, context: Context) {
        field.stringValue = text
        field.onClick = onClick
    }
}
