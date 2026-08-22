import Foundation

/// The last ~12 months of the contribution calendar (API default range).
public enum ContributionCalendarQuery {
    public static let text = """
        query($login: String!) {
          user(login: $login) {
            contributionsCollection {
              contributionCalendar {
                weeks {
                  contributionDays {
                    date
                    contributionCount
                    contributionLevel
                  }
                }
              }
            }
          }
        }
        """

    public struct Response: Decodable, Sendable {
        public var user: UserNode
    }

    public struct UserNode: Decodable, Sendable {
        public var contributionsCollection: Collection
    }

    public struct Collection: Decodable, Sendable {
        public var contributionCalendar: Calendar
    }

    public struct Calendar: Decodable, Sendable {
        public var weeks: [Week]
    }

    public struct Week: Decodable, Sendable {
        public var contributionDays: [Day]
    }

    public struct Day: Decodable, Sendable {
        public var date: String
        public var contributionCount: Int
        public var contributionLevel: Level
    }

    public enum Level: String, Decodable, Sendable {
        case none = "NONE"
        case first = "FIRST_QUARTILE"
        case second = "SECOND_QUARTILE"
        case third = "THIRD_QUARTILE"
        case fourth = "FOURTH_QUARTILE"

        public var rank: Int {
            switch self {
            case .none: return 0
            case .first: return 1
            case .second: return 2
            case .third: return 3
            case .fourth: return 4
            }
        }
    }
}

/// Contribution totals for one year window — run once per year back to
/// account creation and summed.
public enum ContributionTotalsQuery {
    public static let text = """
        query($login: String!, $from: DateTime!, $to: DateTime!) {
          user(login: $login) {
            contributionsCollection(from: $from, to: $to) {
              totalCommitContributions
              totalIssueContributions
              totalPullRequestContributions
              totalPullRequestReviewContributions
            }
          }
        }
        """

    public struct Response: Decodable, Sendable {
        public var user: UserNode
    }

    public struct UserNode: Decodable, Sendable {
        public var contributionsCollection: Totals
    }

    public struct Totals: Decodable, Sendable {
        public var totalCommitContributions: Int
        public var totalIssueContributions: Int
        public var totalPullRequestContributions: Int
        public var totalPullRequestReviewContributions: Int
    }
}
