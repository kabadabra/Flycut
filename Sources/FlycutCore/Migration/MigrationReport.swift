import Foundation

public struct LegacySource: Sendable, Equatable {
    public let url: URL
    public let identity: String
    public init(url: URL, identity: String? = nil) {
        self.url = url
        self.identity = identity ?? url.standardizedFileURL.path
    }
}

public struct SkippedLegacyRecord: Sendable, Equatable {
    public let collection: CollectionKind
    public let index: Int
    public let reason: String
}

public struct LegacySnapshot: Sendable {
    public let history: HistorySnapshot
    public var settings: FlycutSettings
    public let skipped: [SkippedLegacyRecord]
    public let warnings: [String]
}

public struct MigrationReport: Sendable {
    public let source: LegacySource
    public let recentCount: Int
    public let favoriteCount: Int
    public let destinationCount: Int
    public var settings: FlycutSettings
    public let skipped: [SkippedLegacyRecord]
    public var warnings: [String]
    public var importedCount = 0
    public var alreadyImported = false
    public var inMemoryOnly: Bool
    public var sourceBackup: URL?
    public var destinationBackup: URL?
}

public enum MigrationChoice: Sendable {
    case importNew
    case merge(confirmed: Bool)
    case replace(confirmed: Bool)
}

public enum MigrationError: Error, Equatable, Sendable {
    case absentStore
    case invalidPropertyList
    case nothingImportable
    case confirmationRequired
    case importInProgress
}

public struct LegacySourceDiscovery: Sendable {
    public let sources: [LegacySource]
    public let inaccessibleSources: [LegacySource]
    public let offersFilePicker = true

    public static func candidates(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [LegacySource] {
        ["com.edynamics.flycut", "com.kabadabra.flycut", "com.generalarcade.flycut"].map { domain in
            let path = domain == "com.generalarcade.flycut"
                ? "Library/Containers/\(domain)/Data/Library/Preferences/\(domain).plist"
                : "Library/Preferences/\(domain).plist"
            return LegacySource(url: home.appendingPathComponent(path), identity: domain)
        }
    }

    public static func discover(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Self {
        var sources: [LegacySource] = [], inaccessible: [LegacySource] = []
        for source in candidates(home: home) {
            do {
                _ = try FileHandle(forReadingFrom: source.url).close()
                sources.append(source)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile { continue }
            catch { inaccessible.append(source) }
        }
        return Self(sources: sources, inaccessibleSources: inaccessible)
    }
}
