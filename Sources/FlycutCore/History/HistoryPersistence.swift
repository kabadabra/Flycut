/// A destination remains read-only until its complete snapshot has been restored.
/// Keeping this gate independent of the database handle prevents failed reads from
/// turning into destructive replacements during shutdown or subsequent captures.
public actor HistoryPersistence {
    private let destination: any HistoryRepository
    private var restored = false
    public init(destination: any HistoryRepository) { self.destination = destination }

    public func restore(into working: any HistoryRepository) async throws {
        restored = false
        let snapshot = try await destination.snapshot()
        try await working.replaceAll(snapshot)
        restored = true
    }

    @discardableResult
    public func save(_ snapshot: HistorySnapshot) async throws -> Bool {
        guard restored else { return false }
        try await destination.replaceAll(snapshot)
        return true
    }
}
