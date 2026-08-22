import Foundation
import ProfileKit

/// Stat rows for the contribution totals. Option `dense: true` for 20px rows.
public struct ActivityPlugin: Plugin {
    public static let id = "activity"

    public init() {}

    public func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
        let dense = options.bool("dense", default: false)
        let a = snapshot.activity
        func stat(_ icon: Icon, _ label: String, _ value: Int) -> Block {
            .stat(Stat(icon: icon, label: label, value: Format.thousands(value), dense: dense))
        }
        return Card(
            id: Self.id, title: "Activity", icon: .flame,
            blocks: [
                stat(.commit, "Commits", a.totalCommitContributions),
                stat(.pr, "PRs opened", a.totalPullRequestContributions),
                stat(.merge, "PRs reviewed", a.totalPullRequestReviewContributions),
                stat(.issue, "Issues opened", a.totalIssueContributions),
                stat(.comment, "Issue comments", a.issueComments),
                stat(.people, "Contributed to", a.repositoriesContributedTo),
            ])
    }
}

/// Repository counts, then a divider and the top languages by bytes.
/// Options: `top` (default 6), `ignore` (language names).
public struct RepositoriesPlugin: Plugin {
    public static let id = "repositories"

    public init() {}

    public func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
        let repos = snapshot.repositories
        let bars = LanguageStats.topLanguages(
            in: snapshot,
            top: options.int("top", default: 6),
            ignore: options.strings("ignore"))
        let publicStars = repos.filter { !$0.isPrivate }.reduce(0) { $0 + $1.stargazerCount }
        var blocks: [Block] = [
            .stat(Stat(icon: .repo, label: "Repositories", value: Format.thousands(repos.count))),
            .stat(Stat(icon: .star, label: "Stars earned", value: Format.thousands(publicStars))),
            .stat(Stat(icon: .tag, label: "Releases", value: Format.thousands(repos.reduce(0) { $0 + $1.releases }))),
            .stat(Stat(icon: .package, label: "Packages", value: Format.thousands(snapshot.user.packages))),
            .stat(Stat(icon: .database, label: "Storage used", value: Format.storage(kilobytes: repos.reduce(0) { $0 + $1.diskUsage }))),
        ]
        if !bars.isEmpty {
            blocks.append(.divider("top languages"))
            blocks.append(.barList(bars))
        }
        return Card(id: Self.id, title: "Repositories", icon: .repo, blocks: blocks)
    }
}

/// Stat rows for the social counts.
public struct CommunityPlugin: Plugin {
    public static let id = "community"

    public init() {}

    public func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
        let c = snapshot.community
        func stat(_ icon: Icon, _ label: String, _ value: Int) -> Block {
            .stat(Stat(icon: icon, label: label, value: Format.thousands(value)))
        }
        return Card(
            id: Self.id, title: "Community", icon: .people,
            blocks: [
                stat(.heart, "Followers", c.followers),
                stat(.people, "Following", c.following),
                stat(.organization, "Organizations", c.organizations),
                stat(.star, "Starred", c.starredRepositories),
                stat(.eye, "Watching", c.watching),
                stat(.sparkle, "Sponsoring", c.sponsoring),
            ])
    }
}

/// Current and best streak, plus a sparkline of the last 12 weeks of commits.
/// Option `timezone` (default UTC) decides what "today" is.
public struct StreaksPlugin: Plugin {
    public static let id = "streaks"

    public init() {}

    public func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
        let timezone = TimeZone(identifier: options.string("timezone", default: "UTC"))
            ?? TimeZone(identifier: "UTC")!
        let streaks = CalendarMath.streaks(
            days: snapshot.contributions.days,
            now: snapshot.generatedAt,
            timezone: timezone)
        let weekly = CalendarMath.weeklyTotals(days: snapshot.contributions.days, weeks: 12)
        var blocks: [Block] = [
            .statGrid([
                BigStat(value: "\(streaks.current) days", label: "current streak", accent: true),
                BigStat(value: "\(streaks.best) days", label: "best streak"),
            ])
        ]
        if weekly.count >= 2 {
            blocks.append(.divider("commits / week"))
            blocks.append(.sparkline(Sparkline(
                values: weekly,
                label: Format.compact(Int(weekly.last ?? 0)))))
        }
        return Card(id: Self.id, title: "Streaks", icon: .zap, blocks: blocks)
    }
}

/// Headline commit numbers: total, highest single day, average per day.
public struct CommitsPlugin: Plugin {
    public static let id = "commits"

    public init() {}

    public func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
        let days = snapshot.contributions.days
        let highest = days.map(\.count).max() ?? 0
        let total = days.reduce(0) { $0 + $1.count }
        let average = days.isEmpty ? 0 : Double(total) / Double(days.count)
        return Card(
            id: Self.id, title: "Commits", icon: .commit,
            blocks: [
                .statGrid([
                    BigStat(value: Format.compact(snapshot.activity.totalCommitContributions), label: "total commits"),
                    BigStat(value: Format.compact(highest), label: "highest day", accent: true),
                    BigStat(value: "~" + Format.trim(average), label: "avg / day"),
                ])
            ])
    }
}

/// Full-width contribution heatmap.
/// Options: `style: flat | isometric`, `weeks` (default 52), `span` (default 2).
public struct CalendarPlugin: Plugin {
    public static let id = "calendar"

    public init() {}

    public func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
        let isometric = options.string("style", default: "flat") == "isometric"
        let weeks = options.int("weeks", default: 52)
        let heatmap = CalendarMath.heatmap(
            days: snapshot.contributions.days,
            weeks: weeks,
            weekdayLabels: !isometric)
        return Card(
            id: Self.id, title: "Contributions", icon: .calendar,
            subtitle: "last 12 months",
            span: options.int("span", default: 2),
            blocks: [isometric ? .isometricHeatmap(heatmap) : .heatmap(heatmap)])
    }
}

/// Standalone top-languages bar list. Options: `top` (default 6), `ignore`.
public struct LanguagesPlugin: Plugin {
    public static let id = "languages"

    public init() {}

    public func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
        let bars = LanguageStats.topLanguages(
            in: snapshot,
            top: options.int("top", default: 6),
            ignore: options.strings("ignore"))
        return Card(
            id: Self.id, title: "Languages", icon: .language,
            blocks: bars.isEmpty ? [.text("No language data")] : [.barList(bars)])
    }
}
