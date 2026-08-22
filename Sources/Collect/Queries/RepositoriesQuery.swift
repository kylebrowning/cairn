import Foundation

/// Owned repositories with language edges and counts, paginated by 100.
public enum RepositoriesQuery {
    public static let text = """
        query($login: String!, $cursor: String) {
          user(login: $login) {
            repositories(first: 100, after: $cursor, ownerAffiliations: OWNER) {
              pageInfo { hasNextPage endCursor }
              nodes {
                name
                isFork
                isPrivate
                stargazerCount
                forkCount
                diskUsage
                releases { totalCount }
                languages(first: 10, orderBy: {field: SIZE, direction: DESC}) {
                  edges {
                    size
                    node { name color }
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
        public var repositories: Connection
    }

    public struct Connection: Decodable, Sendable {
        public var pageInfo: PageInfo
        public var nodes: [Node]
    }

    public struct PageInfo: Decodable, Sendable {
        public var hasNextPage: Bool
        public var endCursor: String?
    }

    public struct Node: Decodable, Sendable {
        public var name: String
        public var isFork: Bool
        public var isPrivate: Bool
        public var stargazerCount: Int
        public var forkCount: Int
        public var diskUsage: Int?
        public var releases: Count
        public var languages: Languages?
    }

    public struct Count: Decodable, Sendable {
        public var totalCount: Int
    }

    public struct Languages: Decodable, Sendable {
        public var edges: [Edge]
    }

    public struct Edge: Decodable, Sendable {
        public var size: Int
        public var node: LanguageNode
    }

    public struct LanguageNode: Decodable, Sendable {
        public var name: String
        public var color: String?
    }
}
