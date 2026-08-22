import Foundation
import Logging
import ProfileKit

public struct GitHubError: Error, CustomStringConvertible {
    public var status: Int?
    public var message: String

    public var description: String {
        if let status {
            return "GitHub API error (HTTP \(status)): \(message)"
        }
        return "GitHub API error: \(message)"
    }
}

/// GitHub GraphQL + REST client: bearer auth, and up to 3 attempts with
/// backoff on 502/503 and secondary rate limits, honoring Retry-After.
public struct GitHubClient: GitHubAPI {
    let transport: any HTTPTransport
    let token: String
    let apiBase: String
    let logger = Logger(label: "cairn.collect")
    /// Injectable for tests; production sleeps for real.
    let sleep: @Sendable (Duration) async throws -> Void

    static let maxAttempts = 3

    public init(
        token: String,
        transport: any HTTPTransport = AsyncHTTPClientTransport(),
        apiBase: String = "https://api.github.com",
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.token = token
        self.transport = transport
        self.apiBase = apiBase
        self.sleep = sleep
    }

    var commonHeaders: [(String, String)] {
        [
            ("Authorization", "Bearer \(token)"),
            ("User-Agent", "cairn"),
            ("Accept", "application/vnd.github+json"),
        ]
    }

    func sendWithRetry(_ request: TransportRequest) async throws -> TransportResponse {
        var attempt = 1
        while true {
            let response = try await transport.send(request)
            if response.status < 400 {
                return response
            }
            let secondaryLimit = response.status == 403 || response.status == 429
            let retryable = response.status == 502 || response.status == 503 || secondaryLimit
            guard retryable, attempt < Self.maxAttempts else {
                throw GitHubError(
                    status: response.status,
                    message: String(data: response.body.prefix(512), encoding: .utf8) ?? "")
            }
            let delay: Duration
            if let after = response.header("Retry-After").flatMap(Double.init) {
                delay = .seconds(after)
            } else {
                delay = .seconds(Double(1 << (attempt - 1)))  // 1s, 2s
            }
            logger.warning("HTTP \(response.status) from GitHub, retrying in \(delay) (attempt \(attempt)/\(Self.maxAttempts))")
            try await sleep(delay)
            attempt += 1
        }
    }

    // MARK: GraphQL

    struct GraphQLEnvelope<T: Decodable>: Decodable {
        struct GraphQLMessage: Decodable {
            var message: String
        }

        var data: T?
        var errors: [GraphQLMessage]?
    }

    public func graphql<T: Decodable>(
        _ query: String, variables: [String: JSONValue] = [:]
    ) async throws -> T {
        let data = try await graphQLData(query, variables: variables)
        return try Self.decodeGraphQL(T.self, from: data)
    }

    /// Decodes a GraphQL envelope, surfacing API-level errors.
    /// Exposed so fixture tests decode exactly like production.
    public static func decodeGraphQL<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let envelope = try Snapshot.decoder().decode(GraphQLEnvelope<T>.self, from: data)
        if let payload = envelope.data {
            return payload
        }
        let message = envelope.errors?.map(\.message).joined(separator: "; ") ?? "empty response"
        throw GitHubError(status: nil, message: message)
    }

    // MARK: GitHubAPI (raw variants handed to plugin collect)

    public func graphQLData(_ query: String, variables: [String: JSONValue]) async throws -> Data {
        struct Payload: Encodable {
            var query: String
            var variables: [String: JSONValue]
        }
        let body = try JSONEncoder().encode(Payload(query: query, variables: variables))
        let response = try await sendWithRetry(TransportRequest(
            method: "POST", url: "\(apiBase)/graphql",
            headers: commonHeaders + [("Content-Type", "application/json")],
            body: body))
        return response.body
    }

    public func restData(_ path: String) async throws -> Data {
        let response = try await sendWithRetry(TransportRequest(
            method: "GET", url: apiBase + path, headers: commonHeaders))
        return response.body
    }

    public func rest<T: Decodable>(_ path: String) async throws -> T {
        try Snapshot.decoder().decode(T.self, from: try await restData(path))
    }
}
