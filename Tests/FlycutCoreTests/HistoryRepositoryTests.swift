import Foundation
import XCTest
import FlycutCore
import SQLite3

final class HistoryRepositoryTests: XCTestCase {
    private func clip(_ text: String, id: UUID = UUID(), collection: CollectionKind = .recent, order: Int = 0) -> Clip {
        Clip(id: id, text: text, pasteboardType: "public.utf8-plain-text", sourceAppName: "Test", sourceBundleURL: "file:///Applications/Test.app", capturedAt: Date(timeIntervalSince1970: 123), collection: collection, order: order)
    }

    private func repository() throws -> SQLiteHistoryRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SQLiteHistoryRepository(url: directory.appendingPathComponent("history.sqlite"))
    }

    func testInsertPreservesNewestFirstOrderAndMetadataAcrossReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.sqlite")
        let first = clip("first\n")
        let second = clip("second")
        let store = try SQLiteHistoryRepository(url: url)
        _ = try await store.apply(.insert(first))
        _ = try await store.apply(.insert(second))
        let reopened = try SQLiteHistoryRepository(url: url)
        let values = try await reopened.snapshot().recent
        XCTAssertEqual(values.map(\.id), [second.id, first.id])
        XCTAssertEqual(values.map(\.order), [0, 1])
        XCTAssertEqual(values[1].text, "first\n")
        XCTAssertEqual(values[1].sourceAppName, "Test")
        XCTAssertEqual(values[1].sourceBundleURL, "file:///Applications/Test.app")
        XCTAssertEqual(values[1].capturedAt, Date(timeIntervalSince1970: 123))
    }

    func testFavoritesRemainSeparateAndSameTextDuplicatesSurvive() async throws {
        let store = try repository()
        let first = clip("same")
        let second = clip("same")
        let favorite = clip("same", collection: .favorite)
        try await store.replaceAll(HistorySnapshot(recent: [first, second], favorites: [favorite]))
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.recent.map(\.id), [first.id, second.id])
        XCTAssertEqual(snapshot.favorites.map(\.id), [favorite.id])
        XCTAssertEqual(snapshot.recent.map(\.order), [0, 1])
    }

    func testServiceOptionallyDeduplicatesAndEvictsOldest() async throws {
        let store = try repository()
        let service = HistoryService(repository: store, recentCapacity: 2, favoriteCapacity: 2)
        let first = clip("A")
        let second = clip("B")
        let third = clip("A")
        _ = try await service.capture(first)
        _ = try await service.capture(second)
        let snapshot = try await service.capture(third, removeDuplicates: true)
        XCTAssertEqual(snapshot.recent.map(\.id), [third.id, second.id])
        let fourth = clip("C")
        let capped = try await service.capture(fourth)
        XCTAssertEqual(capped.recent.map(\.id), [fourth.id, third.id])
    }

    func testSearchMapsResultsBackToStableClips() async throws {
        let store = try repository()
        let service = HistoryService(repository: store)
        let first = clip("Café note")
        let second = clip("other")
        try await store.replaceAll(HistorySnapshot(recent: [first, second], favorites: []))
        let results = try await service.search("CAFÉ")
        XCTAssertEqual(results.map(\.id), [first.id])
    }

    func testMergeAllJoinsOldestToNewestAndReplacesRecents() async throws {
        let store = try repository()
        let service = HistoryService(repository: store)
        try await store.replaceAll(HistorySnapshot(recent: [clip("new"), clip("middle"), clip("old")], favorites: []))
        let merged = try await service.mergeAll()
        XCTAssertEqual(merged?.text, "old\nmiddle\nnew")
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.recent.map(\.text), ["old\nmiddle\nnew"])
    }

    func testInvalidBatchRollsBackEveryMutation() async throws {
        let store = try repository()
        let first = clip("safe")
        _ = try await store.apply(.insert(first))
        do {
            _ = try await store.apply(.batch([.insert(clip("temporary")), .insert(first)]))
            XCTFail("Expected duplicate identifier to abort the transaction")
        } catch {
            let snapshot = try await store.snapshot()
            XCTAssertEqual(snapshot.recent.map(\.text), ["safe"])
        }
    }

    func testReplaceAllFailureLeavesOriginalSnapshot() async throws {
        let store = try repository()
        let first = clip("safe")
        try await store.replaceAll(HistorySnapshot(recent: [first], favorites: []))
        do {
            try await store.replaceAll(HistorySnapshot(recent: [first, first], favorites: []))
            XCTFail("Expected duplicate identifier to abort replacement")
        } catch {
            let after = try await store.snapshot()
            XCTAssertEqual(after.recent.map(\.text), ["safe"])
        }
    }

    func testDatabasePermissionsSchemaAndMigrationMarker() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.sqlite")
        let store = try SQLiteHistoryRepository(url: url)
        let marker = MigrationMarker(sourceIdentity: "legacy-profile", importedAt: Date(timeIntervalSince1970: 456))
        try await store.replaceAll(HistorySnapshot(recent: [], favorites: [], migration: marker))
        let reopened = try SQLiteHistoryRepository(url: url)
        let snapshot = try await reopened.snapshot()
        XCTAssertEqual(snapshot.migration, marker)
        let directoryMode = try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int
        let fileMode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(directoryMode, 0o700)
        XCTAssertEqual(fileMode, 0o600)
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(handle) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(handle, "PRAGMA user_version", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 1)
    }

    func testExactTextIncludingEmbeddedNullRoundTrips() async throws {
        let store = try repository()
        let value = "before\u{0000}after\n🦋"
        _ = try await store.apply(.insert(clip(value)))
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.recent.first?.text, value)
    }

    func testMoveDeleteAndClearDoNotAffectFavorites() async throws {
        let store = try repository()
        let first = clip("first")
        let second = clip("second")
        let favorite = clip("favorite", collection: .favorite)
        try await store.replaceAll(HistorySnapshot(recent: [first, second], favorites: [favorite]))
        _ = try await store.apply(.moveToTop(second.id))
        _ = try await store.apply(.delete(first.id))
        let snapshot = try await store.apply(.clear(.recent))
        XCTAssertTrue(snapshot.recent.isEmpty)
        XCTAssertEqual(snapshot.favorites.map(\.id), [favorite.id])
    }

    func testFavoriteMovesClipToSeparateBoundedCollection() async throws {
        let store = try repository()
        let service = HistoryService(repository: store, recentCapacity: 3, favoriteCapacity: 1)
        let first = clip("first")
        let second = clip("second")
        try await store.replaceAll(HistorySnapshot(recent: [first, second], favorites: []))
        _ = try await service.favorite(id: first.id)
        let snapshot = try await service.favorite(id: second.id)
        XCTAssertTrue(snapshot.recent.isEmpty)
        XCTAssertEqual(snapshot.favorites.map(\.id), [second.id])
        XCTAssertEqual(snapshot.favorites.first?.collection, .favorite)
        XCTAssertEqual(snapshot.favorites.first?.order, 0)
    }

    func testTopDuplicateIsIgnoredEvenWhenDeduplicationDisabled() async throws {
        let store = try repository()
        let service = HistoryService(repository: store)
        let first = clip("same")
        let second = clip("same")
        _ = try await service.capture(first)
        let snapshot = try await service.capture(second)
        XCTAssertEqual(snapshot.recent.map(\.id), [first.id])
    }
}
