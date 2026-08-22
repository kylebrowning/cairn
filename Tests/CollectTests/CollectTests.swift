import Foundation
import ProfileKit
import Testing

@testable import Collect

/// The moment the fixtures were recorded; keeps the built snapshot stable.
let fixtureNow = ISO8601DateFormatter().date(from: "2026-08-22T12:00:00Z")!

func fixtureClient(transport: any HTTPTransport = FixtureTransport()) -> GitHubClient {
    GitHubClient(token: "test-token", transport: transport, sleep: { _ in })
}

@Suite struct QueryDecodingTests {
    @Test func userQueryDecodes() throws {
        let response = try GitHubClient.decodeGraphQL(UserQuery.Response.self, from: fixture("user.json"))
        #expect(response.user.followers.totalCount > 0)
        #expect(response.user.createdAt < fixtureNow)
    }

    @Test func calendarQueryDecodes() throws {
        let response = try GitHubClient.decodeGraphQL(
            ContributionCalendarQuery.Response.self, from: fixture("contributions-calendar.json"))
        let weeks = response.user.contributionsCollection.contributionCalendar.weeks
        #expect(weeks.count >= 52 && weeks.count <= 54)
        let day = weeks[10].contributionDays[3]
        #expect(day.date.count == 10)
        #expect((0...4).contains(day.contributionLevel.rank))
    }

    @Test func totalsQueryDecodes() throws {
        let response = try GitHubClient.decodeGraphQL(
            ContributionTotalsQuery.Response.self, from: fixture("contributions-2025.json"))
        #expect(response.user.contributionsCollection.totalCommitContributions >= 0)
    }

    @Test func repositoriesQueryDecodes() throws {
        let page1 = try GitHubClient.decodeGraphQL(
            RepositoriesQuery.Response.self, from: fixture("repositories-page-1.json"))
        #expect(page1.user.repositories.nodes.count == 100)
        #expect(page1.user.repositories.pageInfo.hasNextPage)
        let page2 = try GitHubClient.decodeGraphQL(
            RepositoriesQuery.Response.self, from: fixture("repositories-page-2.json"))
        #expect(!page2.user.repositories.pageInfo.hasNextPage)
    }

    @Test func graphQLErrorsSurface() {
        let body = Data(#"{"data": null, "errors": [{"message": "Bad credentials"}]}"#.utf8)
        #expect(throws: GitHubError.self) {
            try GitHubClient.decodeGraphQL(UserQuery.Response.self, from: body)
        }
    }
}

@Suite struct SnapshotBuilderTests {
    @Test func buildsTheCheckedInSnapshot() async throws {
        let snapshot = try await SnapshotBuilder.build(
            login: "kylebrowning", client: fixtureClient(), now: fixtureNow)
        let encoded = try Snapshot.encoder().encode(snapshot)

        let file = fixturesDir.appendingPathComponent("snapshot.json")
        if ProcessInfo.processInfo.environment["UPDATE_SNAPSHOT"] == "1" {
            try encoded.write(to: file)
            return
        }
        let expected = try Data(contentsOf: file)
        #expect(
            encoded == expected,
            "snapshot built from fixtures differs from Fixtures/snapshot.json — regenerate with UPDATE_SNAPSHOT=1 if intended")
    }

    @Test func paginatesRepositories() async throws {
        let repos = try await SnapshotBuilder.fetchAllRepositories(
            login: "kylebrowning", client: fixtureClient())
        #expect(repos.count == 112)
    }

    @Test func pluginCollectFailureLeavesExtraAbsent() async throws {
        struct FailingPlugin: Plugin {
            static let id = "failing"
            func collect(_ ctx: CollectContext) async throws -> JSONValue? {
                throw GitHubError(status: nil, message: "boom")
            }
            func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
                Card(id: Self.id, title: "x", blocks: [])
            }
        }
        let snapshot = try await SnapshotBuilder.build(
            login: "kylebrowning", client: fixtureClient(),
            plugins: [FailingPlugin()], now: fixtureNow)
        #expect(snapshot.extra["failing"] == nil)
    }

    @Test func pluginCollectResultLandsInExtra() async throws {
        struct WeatherPlugin: Plugin {
            static let id = "weather"
            func collect(_ ctx: CollectContext) async throws -> JSONValue? {
                .object(["temp": .int(21)])
            }
            func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
                Card(id: Self.id, title: "x", blocks: [])
            }
        }
        let snapshot = try await SnapshotBuilder.build(
            login: "kylebrowning", client: fixtureClient(),
            plugins: [WeatherPlugin()], now: fixtureNow)
        #expect(snapshot.extra["weather"] == .object(["temp": .int(21)]))
    }
}

@Suite struct RetryTests {
    @Test func retriesOn502ThenSucceeds() async throws {
        let ok = Data(#"{"data": {"ok": true}}"#.utf8)
        let transport = ScriptedTransport([
            TransportResponse(status: 502, body: Data()),
            TransportResponse(status: 200, body: ok),
        ])
        let client = fixtureClient(transport: transport)
        let data = try await client.graphQLData("query {}", variables: [:])
        #expect(data == ok)
        #expect(transport.requests.count == 2)
    }

    @Test func honorsRetryAfterOnSecondaryRateLimit() async throws {
        let delays = Delays()
        let transport = ScriptedTransport([
            TransportResponse(status: 403, headers: [("Retry-After", "7")], body: Data()),
            TransportResponse(status: 200, body: Data("{}".utf8)),
        ])
        let client = GitHubClient(
            token: "t", transport: transport,
            sleep: { await delays.record($0) })
        _ = try await client.restData("/rate_limit")
        #expect(await delays.values == [.seconds(7)])
    }

    @Test func givesUpAfterThreeAttempts() async throws {
        let transport = ScriptedTransport([
            TransportResponse(status: 503, body: Data()),
            TransportResponse(status: 503, body: Data()),
            TransportResponse(status: 503, body: Data()),
            TransportResponse(status: 200, body: Data("{}".utf8)),
        ])
        let client = fixtureClient(transport: transport)
        await #expect(throws: GitHubError.self) {
            _ = try await client.restData("/user")
        }
        #expect(transport.requests.count == 3)
    }

    @Test func doesNotRetryClientErrors() async throws {
        let transport = ScriptedTransport([
            TransportResponse(status: 401, body: Data("bad credentials".utf8))
        ])
        let client = fixtureClient(transport: transport)
        await #expect(throws: GitHubError.self) {
            _ = try await client.restData("/user")
        }
        #expect(transport.requests.count == 1)
    }
}

actor Delays {
    var values: [Duration] = []

    func record(_ d: Duration) {
        values.append(d)
    }
}
