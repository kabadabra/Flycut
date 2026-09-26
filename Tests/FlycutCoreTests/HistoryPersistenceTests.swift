import XCTest
import SQLite3
@testable import FlycutCore

final class HistoryPersistenceTests: XCTestCase {
    func testMalformedSavedMetadataSurvivesRestoreFailureAndQuitSave() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("history.sqlite")
        let disk = try SQLiteHistoryRepository(url: url)
        let clip = Clip(id: UUID(), text: "synthetic recoverable text", pasteboardType: "text", sourceAppName: nil, sourceBundleURL: nil, capturedAt: nil, collection: .recent, order: 0)
        try await disk.replaceAll(HistorySnapshot(recent: [clip], favorites: []))
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO metadata(key,value) VALUES('migration','malformed-json')", nil, nil, nil), SQLITE_OK)
        let working = try SQLiteHistoryRepository()
        let persistence = HistoryPersistence(destination: disk)
        do { try await persistence.restore(into: working); XCTFail("Expected malformed metadata read failure") } catch {}
        let saved = try await persistence.save(HistorySnapshot(recent: [], favorites: []))
        XCTAssertFalse(saved, "Quit must never replace an unread destination")
        XCTAssertEqual(sqlite3_exec(db, "DELETE FROM metadata WHERE key='migration'", nil, nil, nil), SQLITE_OK)
        let recovered = try await disk.snapshot()
        XCTAssertEqual(recovered.recent.map(\.text), ["synthetic recoverable text"])
    }
    func testSuccessfulRestorePermitsSavingAndUnattemptedRestoreDoesNot() async throws {
        let disk = try SQLiteHistoryRepository(), working = try SQLiteHistoryRepository()
        let persistence = HistoryPersistence(destination: disk)
        let before = try await persistence.save(HistorySnapshot(recent: [], favorites: []))
        XCTAssertFalse(before)
        try await persistence.restore(into: working)
        let after = try await persistence.save(HistorySnapshot(recent: [], favorites: []))
        XCTAssertTrue(after)
    }
}
