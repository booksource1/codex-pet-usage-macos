import Foundation

public enum LiveUsageError: Error, Equatable {
    case invalidResponse
    case invalidEndpoint
    case invalidStatus(Int)
}

public final class RejectRedirectsDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public final class LiveUsageClient: @unchecked Sendable {
    private static let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    private let session: URLSession
    private let redirectDelegate: RejectRedirectsDelegate?

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
            self.redirectDelegate = nil
        } else {
            let delegate = RejectRedirectsDelegate()
            self.redirectDelegate = delegate
            self.session = URLSession(
                configuration: .ephemeral,
                delegate: delegate,
                delegateQueue: nil
            )
        }
    }

    public static func makeRequest(accessToken: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint, timeoutInterval: 20)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    public static func accessToken(from data: Data) throws -> String? {
        let object = try JSONSerialization.jsonObject(with: data)
        guard
            let root = object as? [String: Any],
            let tokens = root["tokens"] as? [String: Any],
            let token = tokens["access_token"] as? String
        else {
            return nil
        }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func validate(response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw LiveUsageError.invalidResponse
        }
        guard
            response.url?.scheme == "https",
            response.url?.host == "chatgpt.com",
            response.url?.path == "/backend-api/wham/usage",
            response.url?.query == nil,
            response.url?.fragment == nil
        else {
            throw LiveUsageError.invalidEndpoint
        }
        guard (200...299).contains(response.statusCode) else {
            throw LiveUsageError.invalidStatus(response.statusCode)
        }
    }

    public func fetch(authURL: URL, now: Date = Date()) async throws -> UsageSnapshot? {
        let authData = try Data(contentsOf: authURL)
        guard let token = try Self.accessToken(from: authData) else { return nil }
        let request = try Self.makeRequest(accessToken: token)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response)
        return try UsageDecoder.decode(data: data, source: .live, now: now)
    }
}

public struct UsageService: Sendable {
    public typealias LiveLoader = @Sendable () async throws -> UsageSnapshot?
    public typealias LogLoader = @Sendable () -> UsageSnapshot?

    private let liveLoader: LiveLoader
    private let logLoader: LogLoader
    private let now: @Sendable () -> Date

    public init(
        liveLoader: @escaping LiveLoader,
        logLoader: @escaping LogLoader,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.liveLoader = liveLoader
        self.logLoader = logLoader
        self.now = now
    }

    public init(codexHome: URL, client: LiveUsageClient = LiveUsageClient()) {
        let authURL = codexHome.appendingPathComponent("auth.json")
        let logURLs = ["logs_2.sqlite", "logs_1.sqlite"].map {
            codexHome.appendingPathComponent($0)
        }
        self.init(
            liveLoader: { try await client.fetch(authURL: authURL) },
            logLoader: { LogUsageReader.read(paths: logURLs) }
        )
    }

    public func refresh() async -> UsageSnapshot {
        do {
            if let live = try await liveLoader() {
                return live
            }
        } catch {
            // The local log fallback is the intended recovery path.
        }
        if let log = logLoader() {
            return log
        }
        return .unavailable(now: now())
    }
}
