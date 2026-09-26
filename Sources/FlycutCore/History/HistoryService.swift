import Foundation

public actor HistoryService {
    private let repository: any HistoryRepository
    private let recentCapacity: Int
    private let favoriteCapacity: Int
    private let archive: EvictionArchive?
    private let archiveRecents: Bool
    private let archiveFavorites: Bool

    public init(repository: any HistoryRepository, recentCapacity: Int = 40, favoriteCapacity: Int = 40, archive: EvictionArchive? = nil, archiveRecents: Bool = false, archiveFavorites: Bool = false) {
        self.archive = archive; self.archiveRecents = archiveRecents; self.archiveFavorites = archiveFavorites
        self.repository = repository
        self.recentCapacity = max(0, recentCapacity)
        self.favoriteCapacity = max(0, favoriteCapacity)
    }

    @discardableResult
    public func capture(_ clip: Clip, removeDuplicates: Bool = false) async throws -> HistorySnapshot {
        let capacity = recentCapacity
        let archive = archiveRecents ? archive : nil
        return try await repository.update { current in
            guard current.recent.first?.text != clip.text else { return }
            if removeDuplicates { current.recent.removeAll { $0.text == clip.text } }
            current.recent.insert(clip, at: 0)
            if current.recent.count > capacity {
                try archive?.save(Array(current.recent.suffix(current.recent.count - capacity)))
                current.recent.removeLast(current.recent.count - capacity)
            }
        }
    }

    public func search(_ query: String) async throws -> [Clip] {
        let before = try await repository.snapshot()
        guard !query.isEmpty else { return before.recent + before.favorites }
        return (before.recent + before.favorites).filter { $0.text.localizedStandardContains(query) }
    }

    @discardableResult
    public func favorite(id: UUID) async throws -> HistorySnapshot {
        let capacity = favoriteCapacity
        let archive = archiveFavorites ? archive : nil
        return try await repository.update { current in
            guard let selected = current.recent.first(where: { $0.id == id }) else { throw HistoryError.missingClip }
            current.favorites.insert(Clip(id: selected.id, text: selected.text, pasteboardType: selected.pasteboardType, sourceAppName: selected.sourceAppName, sourceBundleURL: selected.sourceBundleURL, capturedAt: selected.capturedAt, collection: .favorite, order: 0), at: 0)
            if current.favorites.count > capacity {
                try archive?.save(Array(current.favorites.suffix(current.favorites.count - capacity)))
                current.favorites.removeLast(current.favorites.count - capacity)
            }
            current.recent.removeAll { $0.id == id }
        }
    }

    @discardableResult
    public func clearRecents() async throws -> HistorySnapshot {
        try await repository.apply(.clear(.recent))
    }

    @discardableResult
    public func delete(id: UUID) async throws -> HistorySnapshot {
        try await repository.apply(.delete(id))
    }

    @discardableResult
    public func moveToTop(id: UUID) async throws -> HistorySnapshot {
        try await repository.apply(.moveToTop(id))
    }

    @discardableResult
    public func mergeAll() async throws -> Clip? {
        let snapshot = try await repository.update { current in
            guard let newest = current.recent.first else { return }
            let merged = Clip(id: UUID(), text: current.recent.reversed().map(\.text).joined(separator: "\n"), pasteboardType: newest.pasteboardType, sourceAppName: nil, sourceBundleURL: nil, capturedAt: Date(), collection: .recent, order: 0)
            current.recent = [merged]
        }
        return snapshot.recent.first
    }
}
