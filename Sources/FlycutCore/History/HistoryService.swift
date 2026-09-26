import Foundation

public actor HistoryService {
    private let repository: any HistoryRepository
    private let recentCapacity: Int
    private let favoriteCapacity: Int

    public init(repository: any HistoryRepository, recentCapacity: Int = 40, favoriteCapacity: Int = 40) {
        self.repository = repository
        self.recentCapacity = max(0, recentCapacity)
        self.favoriteCapacity = max(0, favoriteCapacity)
    }

    @discardableResult
    public func capture(_ clip: Clip, removeDuplicates: Bool = false) async throws -> HistorySnapshot {
        let before = try await repository.snapshot()
        guard before.recent.first?.text != clip.text else { return before }
        var recent = before.recent
        if removeDuplicates { recent.removeAll { $0.text == clip.text } }
        recent.insert(clip, at: 0)
        if recent.count > recentCapacity { recent.removeLast(recent.count - recentCapacity) }
        let next = HistorySnapshot(recent: recent, favorites: before.favorites, migration: before.migration)
        try await repository.replaceAll(next)
        return try await repository.snapshot()
    }

    public func search(_ query: String) async throws -> [Clip] {
        let before = try await repository.snapshot()
        guard !query.isEmpty else { return before.recent + before.favorites }
        return (before.recent + before.favorites).filter { $0.text.localizedStandardContains(query) }
    }

    @discardableResult
    public func favorite(id: UUID) async throws -> HistorySnapshot {
        let before = try await repository.snapshot()
        guard let selected = before.recent.first(where: { $0.id == id }) else { throw HistoryError.missingClip }
        var favorites = before.favorites
        favorites.insert(Clip(id: selected.id, text: selected.text, pasteboardType: selected.pasteboardType, sourceAppName: selected.sourceAppName, sourceBundleURL: selected.sourceBundleURL, capturedAt: selected.capturedAt, collection: .favorite, order: 0), at: 0)
        if favorites.count > favoriteCapacity { favorites.removeLast(favorites.count - favoriteCapacity) }
        let next = HistorySnapshot(recent: before.recent.filter { $0.id != id }, favorites: favorites, migration: before.migration)
        try await repository.replaceAll(next)
        return try await repository.snapshot()
    }

    @discardableResult
    public func mergeAll() async throws -> Clip? {
        let before = try await repository.snapshot()
        guard let newest = before.recent.first else { return nil }
        let merged = Clip(id: UUID(), text: before.recent.reversed().map(\.text).joined(separator: "\n"), pasteboardType: newest.pasteboardType, sourceAppName: nil, sourceBundleURL: nil, capturedAt: Date(), collection: .recent, order: 0)
        try await repository.replaceAll(HistorySnapshot(recent: [merged], favorites: before.favorites, migration: before.migration))
        return merged
    }
}
