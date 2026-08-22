import Foundation
import Logging
import ProfileKit

public enum SnapshotBuilder {
    static let logger = Logger(label: "cairn.collect")
    static let pluginCollectTimeout: Duration = .seconds(30)

    /// Runs the core queries concurrently, then each plugin's `collect` with a
    /// per-plugin timeout. A plugin failure is logged and its `extra` entry
    /// left absent — it never fails the build.
    public static func build(
        login: String,
        client: GitHubClient,
        plugins: [any Plugin] = [],
        now: Date = Date()
    ) async throws -> Snapshot {
        async let userTask = client.graphql(UserQuery.text, variables: ["login": .string(login)])
            as UserQuery.Response
        async let calendarTask = client.graphql(ContributionCalendarQuery.text, variables: ["login": .string(login)])
            as ContributionCalendarQuery.Response
        async let reposTask = fetchAllRepositories(login: login, client: client)

        let user = try await userTask

        // Contribution totals are fetched per year back to account creation,
        // concurrently, then summed.
        let yearlyTotals = try await fetchYearlyTotals(
            login: login, client: client, createdAt: user.user.createdAt, now: now)

        let calendar = try await calendarTask
        let repositories = try await reposTask

        var snapshot = Snapshot(
            generatedAt: now,
            login: login,
            user: User(
                name: user.user.name,
                createdAt: user.user.createdAt,
                avatarUrl: user.user.avatarUrl,
                websiteUrl: user.user.websiteUrl,
                location: user.user.location,
                company: user.user.company,
                packages: user.user.packages.totalCount
            ),
            activity: Activity(
                totalCommitContributions: yearlyTotals.map(\.totalCommitContributions).reduce(0, +),
                totalIssueContributions: yearlyTotals.map(\.totalIssueContributions).reduce(0, +),
                totalPullRequestContributions: yearlyTotals.map(\.totalPullRequestContributions).reduce(0, +),
                totalPullRequestReviewContributions: yearlyTotals.map(\.totalPullRequestReviewContributions).reduce(0, +),
                issueComments: user.user.issueComments.totalCount,
                repositoriesContributedTo: user.user.repositoriesContributedTo.totalCount
            ),
            repositories: repositories,
            contributions: ContributionCalendar(
                days: calendar.user.contributionsCollection.contributionCalendar.weeks
                    .flatMap(\.contributionDays)
                    .map { ContributionDay(date: $0.date, count: $0.contributionCount, level: $0.contributionLevel.rank) }
            ),
            community: Community(
                followers: user.user.followers.totalCount,
                following: user.user.following.totalCount,
                organizations: user.user.organizations.totalCount,
                starredRepositories: user.user.starredRepositories.totalCount,
                watching: user.user.watching.totalCount,
                sponsoring: user.user.sponsoring.totalCount,
                sponsors: user.user.sponsors.totalCount
            )
        )

        let context = CollectContext(login: login, client: client)
        for plugin in plugins {
            let id = type(of: plugin).id
            do {
                if let extra = try await withTimeout(pluginCollectTimeout, {
                    try await plugin.collect(context)
                }) {
                    snapshot.extra[id] = extra
                }
            } catch {
                logger.error("plugin \(id) collect failed: \(error) — extra[\(id)] left absent")
            }
        }
        return snapshot
    }

    static func fetchAllRepositories(login: String, client: GitHubClient) async throws -> [Repository] {
        var repositories: [Repository] = []
        var cursor: String?
        repeat {
            let variables: [String: JSONValue] = [
                "login": .string(login),
                "cursor": cursor.map(JSONValue.string) ?? .null,
            ]
            let page: RepositoriesQuery.Response = try await client.graphql(
                RepositoriesQuery.text, variables: variables)
            repositories += page.user.repositories.nodes.map { node in
                Repository(
                    name: node.name,
                    isFork: node.isFork,
                    stargazerCount: node.stargazerCount,
                    forkCount: node.forkCount,
                    diskUsage: node.diskUsage ?? 0,
                    releases: node.releases.totalCount,
                    languages: (node.languages?.edges ?? []).map {
                        Repository.Language(name: $0.node.name, color: $0.node.color, size: $0.size)
                    }
                )
            }
            cursor = page.user.repositories.pageInfo.hasNextPage
                ? page.user.repositories.pageInfo.endCursor : nil
        } while cursor != nil
        return repositories
    }

    static func fetchYearlyTotals(
        login: String, client: GitHubClient, createdAt: Date, now: Date
    ) async throws -> [ContributionTotalsQuery.Totals] {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let firstYear = utc.component(.year, from: createdAt)
        let currentYear = utc.component(.year, from: now)
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = utc.timeZone

        return try await withThrowingTaskGroup(of: (Int, ContributionTotalsQuery.Totals).self) { group in
            for year in firstYear...currentYear {
                let from = DateComponents(calendar: utc, year: year, month: 1, day: 1).date!
                let to = DateComponents(
                    calendar: utc, year: year, month: 12, day: 31,
                    hour: 23, minute: 59, second: 59
                ).date!
                let fromString = formatter.string(from: max(from, createdAt))
                let toString = formatter.string(from: min(to, now))
                group.addTask {
                    let response: ContributionTotalsQuery.Response = try await client.graphql(
                        ContributionTotalsQuery.text,
                        variables: [
                            "login": .string(login),
                            "from": .string(fromString),
                            "to": .string(toString),
                        ])
                    return (year, response.user.contributionsCollection)
                }
            }
            var results: [(Int, ContributionTotalsQuery.Totals)] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// Races work against a deadline; the loser is cancelled.
    static func withTimeout<T: Sendable>(
        _ limit: Duration,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: limit)
                throw GitHubError(status: nil, message: "timed out after \(limit)")
            }
            let winner = try await group.next()!
            group.cancelAll()
            return winner
        }
    }
}
