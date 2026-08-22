import Foundation

/// Everything `collect` learned about a profile, persisted as `snapshot.json`.
/// The render stage consumes only this — it never touches the network.
public struct Snapshot: Codable, Sendable {
    public var generatedAt: Date
    public var login: String
    public var user: User
    public var activity: Activity
    public var repositories: [Repository]
    public var contributions: ContributionCalendar
    public var community: Community
    /// Namespace for plugin-collected data, keyed by plugin id.
    public var extra: [String: JSONValue]

    public init(
        generatedAt: Date,
        login: String,
        user: User,
        activity: Activity,
        repositories: [Repository],
        contributions: ContributionCalendar,
        community: Community,
        extra: [String: JSONValue] = [:]
    ) {
        self.generatedAt = generatedAt
        self.login = login
        self.user = user
        self.activity = activity
        self.repositories = repositories
        self.contributions = contributions
        self.community = community
        self.extra = extra
    }
}

public struct User: Codable, Sendable {
    public var name: String?
    public var createdAt: Date
    public var avatarUrl: String?
    public var websiteUrl: String?
    public var location: String?
    public var company: String?

    public init(
        name: String? = nil,
        createdAt: Date,
        avatarUrl: String? = nil,
        websiteUrl: String? = nil,
        location: String? = nil,
        company: String? = nil
    ) {
        self.name = name
        self.createdAt = createdAt
        self.avatarUrl = avatarUrl
        self.websiteUrl = websiteUrl
        self.location = location
        self.company = company
    }
}

/// Contribution totals summed across every year back to account creation.
/// Field names match GitHub's `contributionsCollection`.
public struct Activity: Codable, Sendable {
    public var totalCommitContributions: Int
    public var totalIssueContributions: Int
    public var totalPullRequestContributions: Int
    public var totalPullRequestReviewContributions: Int
    public var issueComments: Int
    public var repositoriesContributedTo: Int

    public init(
        totalCommitContributions: Int,
        totalIssueContributions: Int,
        totalPullRequestContributions: Int,
        totalPullRequestReviewContributions: Int,
        issueComments: Int,
        repositoriesContributedTo: Int
    ) {
        self.totalCommitContributions = totalCommitContributions
        self.totalIssueContributions = totalIssueContributions
        self.totalPullRequestContributions = totalPullRequestContributions
        self.totalPullRequestReviewContributions = totalPullRequestReviewContributions
        self.issueComments = issueComments
        self.repositoriesContributedTo = repositoriesContributedTo
    }
}

public struct Repository: Codable, Sendable {
    public struct Language: Codable, Sendable {
        public var name: String
        public var color: String?
        /// Bytes of code in this language, from the languages edge `size`.
        public var size: Int

        public init(name: String, color: String? = nil, size: Int) {
            self.name = name
            self.color = color
            self.size = size
        }
    }

    public var name: String
    public var isFork: Bool
    public var stargazerCount: Int
    public var forkCount: Int
    /// Kilobytes, as reported by the API.
    public var diskUsage: Int
    public var releases: Int
    public var languages: [Language]

    public init(
        name: String,
        isFork: Bool,
        stargazerCount: Int,
        forkCount: Int,
        diskUsage: Int,
        releases: Int,
        languages: [Language]
    ) {
        self.name = name
        self.isFork = isFork
        self.stargazerCount = stargazerCount
        self.forkCount = forkCount
        self.diskUsage = diskUsage
        self.releases = releases
        self.languages = languages
    }
}

public struct ContributionDay: Codable, Sendable, Equatable {
    /// Calendar date as "YYYY-MM-DD", exactly as the API reports it.
    public var date: String
    public var count: Int
    /// 0 (none) through 4 (most), GitHub's own bucketing.
    public var level: Int

    public init(date: String, count: Int, level: Int) {
        self.date = date
        self.count = count
        self.level = level
    }
}

/// The last ~12 months of contribution days, oldest first.
public struct ContributionCalendar: Codable, Sendable {
    public var days: [ContributionDay]

    public init(days: [ContributionDay]) {
        self.days = days
    }

    /// Days grouped into weeks of 7 (last week may be partial), oldest first.
    public func weeks() -> [[ContributionDay]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }
}

public struct Community: Codable, Sendable {
    public var followers: Int
    public var following: Int
    public var organizations: Int
    public var starredRepositories: Int
    public var watching: Int
    public var sponsoring: Int
    public var sponsors: Int

    public init(
        followers: Int,
        following: Int,
        organizations: Int,
        starredRepositories: Int,
        watching: Int,
        sponsoring: Int,
        sponsors: Int
    ) {
        self.followers = followers
        self.following = following
        self.organizations = organizations
        self.starredRepositories = starredRepositories
        self.watching = watching
        self.sponsoring = sponsoring
        self.sponsors = sponsors
    }
}

extension Snapshot {
    /// The one encoder/decoder pair for `snapshot.json`: ISO 8601 dates,
    /// sorted keys so the checked-in fixture diffs cleanly.
    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
