import Foundation

/// Profile fields plus every totalCount the community/repositories cards need.
public enum UserQuery {
    public static let text = """
        query($login: String!) {
          user(login: $login) {
            name
            createdAt
            avatarUrl
            websiteUrl
            location
            company
            followers { totalCount }
            following { totalCount }
            organizations { totalCount }
            starredRepositories { totalCount }
            watching { totalCount }
            sponsoring { totalCount }
            sponsors { totalCount }
            issueComments { totalCount }
            repositoriesContributedTo(includeUserRepositories: false) { totalCount }
            packages { totalCount }
          }
        }
        """

    public struct Response: Decodable, Sendable {
        public var user: UserNode
    }

    public struct Count: Decodable, Sendable {
        public var totalCount: Int
    }

    public struct UserNode: Decodable, Sendable {
        public var name: String?
        public var createdAt: Date
        public var avatarUrl: String?
        public var websiteUrl: String?
        public var location: String?
        public var company: String?
        public var followers: Count
        public var following: Count
        public var organizations: Count
        public var starredRepositories: Count
        public var watching: Count
        public var sponsoring: Count
        public var sponsors: Count
        public var issueComments: Count
        public var repositoriesContributedTo: Count
        public var packages: Count
    }
}
