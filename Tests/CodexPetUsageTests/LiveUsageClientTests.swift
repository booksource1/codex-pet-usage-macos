import Foundation
import CodexPetUsageCore

private final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() {
        lock.withLock { storage += 1 }
    }

    var value: Int {
        lock.withLock { storage }
    }
}

private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: URLRequest?

    init(_ request: URLRequest?) {
        storage = request
    }

    func set(_ request: URLRequest?) {
        lock.withLock { storage = request }
    }

    var value: URLRequest? {
        lock.withLock { storage }
    }
}

private func sampleUsage(source: UsageSource) -> UsageSnapshot {
    UsageSnapshot(
        available: true,
        source: source,
        primaryRemaining: 55,
        observedAt: fixedDate()
    )
}

let liveUsageClientTests: [TestCase] = [
    TestCase(name: "requestUsesOnlyFixedChatGPTUsageEndpoint") {
        let request = try LiveUsageClient.makeRequest(accessToken: "secret")
        try expect(request.url?.absoluteString == "https://chatgpt.com/backend-api/wham/usage", "request URL must be fixed")
        try expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret", "request must use bearer token")
        try expect(request.value(forHTTPHeaderField: "Accept") == "application/json", "request must request JSON")
        try expect(request.timeoutInterval == 20, "request timeout must match reference")
    },
    TestCase(name: "readsNestedAccessTokenWithoutPersistingIt") {
        let data = Data(#"{"tokens":{"access_token":"abc123"}}"#.utf8)
        let token = try LiveUsageClient.accessToken(from: data)
        try expect(token == "abc123", "nested token should decode")
    },
    TestCase(name: "missingOrBlankTokenReturnsNil") {
        let missing = try LiveUsageClient.accessToken(from: Data(#"{}"#.utf8))
        let blank = try LiveUsageClient.accessToken(from: Data(#"{"tokens":{"access_token":"  "}}"#.utf8))
        try expect(missing == nil, "missing token should return nil")
        try expect(blank == nil, "blank token should return nil")
    },
    TestCase(name: "redirectsAreRejectedBeforeTokenCanReachAnotherHost") {
        let delegate = RejectRedirectsDelegate()
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        let response = HTTPURLResponse(url: task.originalRequest!.url!, statusCode: 302, httpVersion: nil, headerFields: nil)!
        let redirected = URLRequest(url: URL(string: "https://evil.example/steal")!)
        let decision = RequestBox(redirected)
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: redirected) {
            decision.set($0)
        }
        try expect(decision.value == nil, "redirect delegate must reject every redirect")
        session.invalidateAndCancel()
    },
    TestCase(name: "nonSuccessHTTPStatusIsRejected") {
        for status in [401, 500] {
            let response = HTTPURLResponse(
                url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            do {
                try LiveUsageClient.validate(response: response)
                throw TestFailure(description: "status \(status) should fail")
            } catch is LiveUsageError {
                // Expected.
            }
        }
    },
    TestCase(name: "successfulLiveResultSkipsLogs") {
        let logCalls = TestCounter()
        let service = UsageService(
            liveLoader: { sampleUsage(source: .live) },
            logLoader: { logCalls.increment(); return sampleUsage(source: .log) },
            now: { fixedDate() }
        )
        let usage = await service.refresh()
        try expect(usage.source == .live, "live result should win")
        try expect(logCalls.value == 0, "logs should not be read after live success")
    },
    TestCase(name: "liveFailureFallsBackToLogs") {
        let service = UsageService(
            liveLoader: { throw LiveUsageError.invalidStatus(500) },
            logLoader: { sampleUsage(source: .log) },
            now: { fixedDate() }
        )
        let usage = await service.refresh()
        try expect(usage.source == .log, "log fallback should be used")
    },
    TestCase(name: "bothFailuresProduceUnavailable") {
        let service = UsageService(
            liveLoader: { nil },
            logLoader: { nil },
            now: { fixedDate() }
        )
        let usage = await service.refresh()
        try expect(!usage.available, "missing live and log data should be unavailable")
        try expect(usage.source == .none, "unavailable source should be none")
        try expect(usage.observedAt == fixedDate(), "unavailable observation time should be deterministic")
    },
]
