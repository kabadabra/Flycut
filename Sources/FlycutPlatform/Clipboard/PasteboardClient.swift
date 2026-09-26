import AppKit

public enum PasteboardReadResult: Equatable {
    case text(String)
    case unavailable
    case denied
}

/// A small boundary around the system pasteboard; tests provide an in-memory implementation.
@MainActor public protocol PasteboardClient: AnyObject {
    var changeCount: Int { get }
    var advertisedTypes: [String] { get }
    func readPlainText() -> PasteboardReadResult
}

@MainActor public final class SystemPasteboardClient: PasteboardClient {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int { pasteboard.changeCount }
    public var advertisedTypes: [String] { (pasteboard.types ?? []).map(\.rawValue) }

    public func readPlainText() -> PasteboardReadResult {
        if let text = pasteboard.string(forType: .string) { return .text(text) }
        // A declared text item that cannot be read must not be reported as captured.
        if pasteboard.availableType(from: [.string]) != nil { return .denied }
        return .unavailable
    }
}
