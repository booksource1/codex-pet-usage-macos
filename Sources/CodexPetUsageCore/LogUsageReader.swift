import Foundation
import SQLite3

public enum LogUsageReader {
    private static let marker = "codex.rate_limits"

    public static func decode(body: String, now: Date = Date()) throws -> UsageSnapshot? {
        guard !body.isEmpty else { return nil }
        let text = body as NSString
        var markerSearchStart = 0

        while markerSearchStart < text.length {
            let markerRange = text.range(
                of: marker,
                options: [.caseInsensitive],
                range: NSRange(location: markerSearchStart, length: text.length - markerSearchStart)
            )
            guard markerRange.location != NSNotFound else { break }

            var braceSearchEnd = markerRange.location
            while braceSearchEnd > 0 {
                let braceRange = text.range(
                    of: "{",
                    options: [.backwards],
                    range: NSRange(location: 0, length: braceSearchEnd)
                )
                guard braceRange.location != NSNotFound else { break }
                if let json = balancedObject(in: text, start: braceRange.location),
                   json.range(of: marker, options: .caseInsensitive) != nil,
                   let usage = try? UsageDecoder.decode(
                       data: Data(json.utf8),
                       source: .log,
                       now: now
                   ) {
                    return usage
                }
                braceSearchEnd = braceRange.location
            }

            markerSearchStart = NSMaxRange(markerRange)
        }
        return nil
    }

    public static func read(paths: [URL], now: Date = Date()) -> UsageSnapshot? {
        for path in paths where FileManager.default.fileExists(atPath: path.path) {
            guard let body = newestRateLimitBody(path: path) else { continue }
            return try? decode(body: body, now: now)
        }
        return nil
    }

    private static func balancedObject(in text: NSString, start: Int) -> String? {
        var depth = 0
        var inString = false
        var escaping = false

        for index in start..<text.length {
            let character = text.character(at: index)
            if inString {
                if escaping {
                    escaping = false
                } else if character == 0x5C {
                    escaping = true
                } else if character == 0x22 {
                    inString = false
                }
                continue
            }

            if character == 0x22 {
                inString = true
            } else if character == 0x7B {
                depth += 1
            } else if character == 0x7D {
                depth -= 1
                if depth == 0 {
                    return text.substring(with: NSRange(location: start, length: index - start + 1))
                }
            }
        }
        return nil
    }

    private static func newestRateLimitBody(path: URL) -> String? {
        var database: OpaquePointer?
        guard sqlite3_open_v2(path.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let database else {
            if database != nil { sqlite3_close(database) }
            return nil
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT feedback_log_body
        FROM logs
        WHERE feedback_log_body LIKE '%codex.rate_limits%'
        ORDER BY ts DESC, ts_nanos DESC, id DESC
        LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            if statement != nil { sqlite3_finalize(statement) }
            return nil
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let bytes = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: bytes)
    }
}
