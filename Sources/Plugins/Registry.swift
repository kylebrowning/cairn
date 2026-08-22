import ProfileKit

/// The built-in plugins, keyed by id.
public enum Registry {
    public static let builtins: [String: any Plugin] = {
        let all: [any Plugin] = [
            ActivityPlugin(),
            RepositoriesPlugin(),
            CommunityPlugin(),
            StreaksPlugin(),
            CommitsPlugin(),
            CalendarPlugin(),
            LanguagesPlugin(),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { (type(of: $0).id, $0) })
    }()

    public static func plugin(id: String) -> (any Plugin)? {
        builtins[id]
    }
}
