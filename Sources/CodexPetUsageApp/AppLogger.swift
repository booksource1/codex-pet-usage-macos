import Darwin
import Foundation
import CodexPetUsageCore

@MainActor
final class AppLogger {
    let appDirectory: URL
    let pidURL: URL
    let logURL: URL

    private let processID = getpid()

    init(fileManager: FileManager = .default) throws {
        appDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexPetUsageOverlay", isDirectory: true)
        pidURL = appDirectory.appendingPathComponent("overlay.pid")
        logURL = appDirectory.appendingPathComponent("overlay.log")

        try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        try "\(processID)\n".write(to: pidURL, atomically: true, encoding: .utf8)
        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: nil)
        }
    }

    func write(_ message: SafeLogMessage) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        guard let data = "\(timestamp) \(message.text)\n".data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: logURL) else {
            return
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            return
        }
    }

    func removeOwnedPID(fileManager: FileManager = .default) {
        guard
            let stored = try? String(contentsOf: pidURL, encoding: .utf8),
            stored.trimmingCharacters(in: .whitespacesAndNewlines) == String(processID)
        else {
            return
        }
        try? fileManager.removeItem(at: pidURL)
    }
}
