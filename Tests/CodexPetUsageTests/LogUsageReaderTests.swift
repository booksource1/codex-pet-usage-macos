import Foundation
import SQLite3
import CodexPetUsageCore

private func makeLogDatabase(rows: [(Int64, String)]) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-pet-log-\(UUID().uuidString).sqlite")
    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
        throw TestFailure(description: "failed to create fixture database")
    }
    defer { sqlite3_close(database) }
    guard sqlite3_exec(database, "CREATE TABLE logs (id INTEGER PRIMARY KEY, ts INTEGER, ts_nanos INTEGER, feedback_log_body TEXT)", nil, nil, nil) == SQLITE_OK else {
        throw TestFailure(description: "failed to create logs fixture table")
    }
    for (index, row) in rows.enumerated() {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "INSERT INTO logs (ts, ts_nanos, feedback_log_body) VALUES (?, ?, ?)", -1, &statement, nil) == SQLITE_OK, let statement else {
            throw TestFailure(description: "failed to prepare fixture insert")
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, row.0)
        sqlite3_bind_int64(statement, 2, Int64(index))
        sqlite3_bind_text(statement, 3, row.1, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TestFailure(description: "failed to insert fixture row")
        }
    }
    return url
}

private let oldBody = #"prefix {"type":"codex.rate_limits","rate_limits":{"primary":{"remaining_percent":25}}} suffix"#
private let newBody = #"prefix {"type":"codex.rate_limits","rate_limits":{"primary":{"remaining_percent":75}}} suffix"#

let logUsageReaderTests: [TestCase] = [
    TestCase(name: "extractsRateLimitObjectFromMixedLogBody") {
        let usage = try LogUsageReader.decode(body: newBody, now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 75, "mixed body should decode newest payload")
        try expect(usage?.source == .log, "log payload source should be log")
    },
    TestCase(name: "bracesInsideStringsDoNotBreakExtraction") {
        let body = #"noise {"message":"escaped \" } still text","type":"codex.rate_limits","rate_limits":{"primary":{"remaining_percent":81}}} tail"#
        let usage = try LogUsageReader.decode(body: body, now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 81, "quoted braces must not change JSON depth")
    },
    TestCase(name: "unrelatedOrMalformedBodiesReturnNil") {
        let unrelated = try LogUsageReader.decode(body: "nothing useful", now: fixedDate())
        let malformed = try LogUsageReader.decode(body: #"{"type":"codex.rate_limits""#, now: fixedDate())
        try expect(unrelated == nil, "unrelated text should return nil")
        try expect(malformed == nil, "malformed JSON should return nil")
    },
    TestCase(name: "sqliteReturnsNewestMatchingEvent") {
        let url = try makeLogDatabase(rows: [(1, oldBody), (2, newBody)])
        defer { try? FileManager.default.removeItem(at: url) }
        let usage = LogUsageReader.read(paths: [url], now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 75, "newest SQLite event should win")
    },
    TestCase(name: "sqliteFallsThroughMissingPath") {
        let url = try makeLogDatabase(rows: [(1, newBody)])
        defer { try? FileManager.default.removeItem(at: url) }
        let missing = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        let usage = LogUsageReader.read(paths: [missing, url], now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 75, "reader should try next existing database")
    },
    TestCase(name: "sqliteMissingOrCorruptReturnsNil") {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try expect(LogUsageReader.read(paths: [missing], now: fixedDate()) == nil, "missing database should return nil")
        let corrupt = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not sqlite".utf8).write(to: corrupt)
        defer { try? FileManager.default.removeItem(at: corrupt) }
        try expect(LogUsageReader.read(paths: [corrupt], now: fixedDate()) == nil, "corrupt database should return nil")
    },
]
