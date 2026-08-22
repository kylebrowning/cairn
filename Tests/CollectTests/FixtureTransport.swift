import Foundation

@testable import Collect

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

let fixturesDir = repoRoot.appendingPathComponent("Fixtures")
let graphqlDir = fixturesDir.appendingPathComponent("graphql")

func fixture(_ name: String) throws -> Data {
    try Data(contentsOf: graphqlDir.appendingPathComponent(name))
}

/// Serves the recorded GraphQL responses in Fixtures/graphql/ by inspecting
/// the outgoing query and variables — no network, ever.
struct FixtureTransport: HTTPTransport {
    struct Request: Decodable {
        var query: String
        var variables: [String: JSONValueLite]
    }

    /// Just enough JSON decoding to read string variables.
    enum JSONValueLite: Decodable {
        case string(String)
        case other

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) {
                self = .string(s)
            } else {
                self = .other
            }
        }

        var string: String? {
            if case .string(let s) = self { return s }
            return nil
        }
    }

    func send(_ request: TransportRequest) async throws -> TransportResponse {
        let parsed = try JSONDecoder().decode(Request.self, from: request.body ?? Data())
        return TransportResponse(status: 200, body: try route(parsed))
    }

    func route(_ request: Request) throws -> Data {
        if request.query.contains("contributionCalendar") {
            return try fixture("contributions-calendar.json")
        }
        if request.query.contains("totalCommitContributions") {
            let year = String((request.variables["from"]?.string ?? "").prefix(4))
            return try fixture("contributions-\(year).json")
        }
        if request.query.contains("repositories(first: 100") {
            guard let cursor = request.variables["cursor"]?.string else {
                return try fixture("repositories-page-1.json")
            }
            // Find the page whose predecessor ends at this cursor.
            var page = 1
            while true {
                let data = try fixture("repositories-page-\(page).json")
                let response: RepositoriesQuery.Response = try GitHubClient.decodeGraphQL(
                    RepositoriesQuery.Response.self, from: data)
                if response.user.repositories.pageInfo.endCursor == cursor {
                    return try fixture("repositories-page-\(page + 1).json")
                }
                page += 1
            }
        }
        if request.query.contains("followers { totalCount }") {
            return try fixture("user.json")
        }
        throw GitHubError(status: nil, message: "no fixture for query: \(request.query.prefix(80))")
    }
}

/// A transport that replays a scripted list of responses — for retry tests.
final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    private let state: State

    final class State: @unchecked Sendable {
        let lock = NSLock()
        var script: [TransportResponse]
        var requests: [TransportRequest] = []

        init(script: [TransportResponse]) {
            self.script = script
        }
    }

    init(_ script: [TransportResponse]) {
        state = State(script: script)
    }

    var requests: [TransportRequest] {
        state.lock.withLock { state.requests }
    }

    func send(_ request: TransportRequest) async throws -> TransportResponse {
        state.lock.withLock {
            state.requests.append(request)
            return state.script.isEmpty
                ? TransportResponse(status: 500, body: Data())
                : state.script.removeFirst()
        }
    }
}
