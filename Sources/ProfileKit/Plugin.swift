import Foundation

/// Minimal authenticated GitHub access handed to plugin `collect`.
/// Implemented by the Collect target; declared here so ProfileKit stays
/// dependency-free.
public protocol GitHubAPI: Sendable {
    /// POST a GraphQL query, returning the raw response body.
    func graphQLData(_ query: String, variables: [String: JSONValue]) async throws -> Data
    /// GET a REST path like "/users/octocat/packages", returning the raw body.
    func restData(_ path: String) async throws -> Data
}

public struct CollectContext: Sendable {
    public var login: String
    public var client: any GitHubAPI

    public init(login: String, client: any GitHubAPI) {
        self.login = login
        self.client = client
    }
}

/// `[String: JSONValue]` with typed accessors and defaults.
public struct PluginOptions: Codable, Sendable {
    public var values: [String: JSONValue]

    public init(_ values: [String: JSONValue] = [:]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    public subscript(key: String) -> JSONValue? { values[key] }

    public func int(_ key: String, default fallback: Int) -> Int {
        values[key]?.intValue ?? fallback
    }

    public func double(_ key: String, default fallback: Double) -> Double {
        values[key]?.doubleValue ?? fallback
    }

    public func bool(_ key: String, default fallback: Bool) -> Bool {
        values[key]?.boolValue ?? fallback
    }

    public func string(_ key: String, default fallback: String) -> String {
        values[key]?.stringValue ?? fallback
    }

    public func string(_ key: String) -> String? {
        values[key]?.stringValue
    }

    public func strings(_ key: String) -> [String] {
        values[key]?.arrayValue?.compactMap(\.stringValue) ?? []
    }
}

public protocol Plugin: Sendable {
    static var id: String { get }
    /// Optional: fetch extra data into `snapshot.extra[id]`. Default does nothing.
    func collect(_ ctx: CollectContext) async throws -> JSONValue?
    /// Required: build a card from the snapshot. Must not touch the network.
    func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card
}

extension Plugin {
    public func collect(_ ctx: CollectContext) async throws -> JSONValue? { nil }
}

/// Entry point for external Swift plugins. Adopt with `@main`:
/// the process reads `{ "snapshot": ..., "options": ... }` from stdin and
/// writes the rendered `Card` to stdout as JSON.
public protocol ExternalPluginMain: Plugin {
    init()
}

private struct ExternalPluginInput: Decodable {
    var snapshot: Snapshot
    var options: PluginOptions?
}

extension ExternalPluginMain {
    public static func main() throws {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let decoder = Snapshot.decoder()
        let request = try decoder.decode(ExternalPluginInput.self, from: input)
        let card = try Self().render(request.snapshot, options: request.options ?? PluginOptions())
        let output = try Snapshot.encoder().encode(card)
        FileHandle.standardOutput.write(output)
    }
}
