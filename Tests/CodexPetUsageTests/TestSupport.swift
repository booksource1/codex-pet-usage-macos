import Foundation

struct TestCase: Sendable {
    let name: String
    let body: @Sendable () async throws -> Void
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard condition() else {
        throw TestFailure(description: "\(file):\(line): \(message)")
    }
}

func expectApproximately(
    _ actual: Double?,
    _ expected: Double,
    accuracy: Double = 0.001,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard let actual, abs(actual - expected) <= accuracy else {
        throw TestFailure(description: "\(file):\(line): \(message); actual=\(String(describing: actual)) expected=\(expected)")
    }
}

func fixedDate(_ secondsSinceEpoch: TimeInterval = 1_767_268_800) -> Date {
    Date(timeIntervalSince1970: secondsSinceEpoch)
}
