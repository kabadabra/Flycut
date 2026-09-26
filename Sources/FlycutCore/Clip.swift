import Foundation

public enum FlycutVersion {
    public static let current = "3.0.0"
}

public struct Clip: Codable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let pasteboardType: String
    public let sourceAppName: String?
    public let sourceBundleURL: String?
    public let capturedAt: Date?

    public init(
        id: UUID,
        text: String,
        pasteboardType: String,
        sourceAppName: String?,
        sourceBundleURL: String?,
        capturedAt: Date?
    ) {
        self.id = id
        self.text = text
        self.pasteboardType = pasteboardType
        self.sourceAppName = sourceAppName
        self.sourceBundleURL = sourceBundleURL
        self.capturedAt = capturedAt
    }
}
