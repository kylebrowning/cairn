import Foundation
import ProfileKit
import Yams

/// `.github/profile.yml` — theme, columns, output, and the plugin list.
public struct Config: Sendable {
    public struct Output: Sendable {
        public var branch: String = "metrics"
        public var dir: String = "."
    }

    public enum PluginRef: Sendable {
        case builtin(id: String)
        case external(path: String)
    }

    public struct PluginEntry: Sendable {
        public var ref: PluginRef
        public var options: PluginOptions

        public init(ref: PluginRef, options: PluginOptions) {
            self.ref = ref
            self.options = options
        }

        public var id: String {
            switch ref {
            case .builtin(let id):
                return id
            case .external(let path):
                return URL(fileURLWithPath: path).lastPathComponent
            }
        }
    }

    public var theme: String = "default"
    public var columns: Int = 2
    public var output: Output = Output()
    public var plugins: [PluginEntry] = Self.defaultPlugins

    public static let defaultPlugins: [PluginEntry] = [
        "activity", "community", "repositories", "streaks", "commits", "calendar",
    ].map { PluginEntry(ref: .builtin(id: $0), options: PluginOptions()) }

    public struct ParseError: Error, CustomStringConvertible, Sendable {
        public var description: String

        public init(description: String) {
            self.description = description
        }
    }

    /// Loads the config file; a missing file yields the defaults.
    public static func load(path: String) throws -> Config {
        guard FileManager.default.fileExists(atPath: path) else {
            return Config()
        }
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw ParseError(description: "cannot read config at \(path)")
        }
        return try parse(text)
    }

    public static func parse(_ yaml: String) throws -> Config {
        let raw = try YAMLDecoder().decode(RawConfig.self, from: yaml)
        var config = Config()
        if let theme = raw.theme { config.theme = theme }
        if let columns = raw.columns { config.columns = columns }
        if let output = raw.output {
            if let branch = output.branch { config.output.branch = branch }
            if let dir = output.dir { config.output.dir = dir }
        }
        if let plugins = raw.plugins {
            config.plugins = plugins.map(\.entry)
        }
        return config
    }
}

private struct RawConfig: Decodable {
    var theme: String?
    var columns: Int?
    var output: RawOutput?
    var plugins: [RawPluginEntry]?
}

private struct RawOutput: Decodable {
    var branch: String?
    var dir: String?
}

/// A plugin list entry: `- activity`, `- repositories: {top: 6}`, or
/// `- path: ./plugins/wakatime` with optional `options:`.
private struct RawPluginEntry: Decodable {
    var entry: Config.PluginEntry

    init(from decoder: Decoder) throws {
        if let name = try? decoder.singleValueContainer().decode(String.self) {
            entry = Config.PluginEntry(ref: .builtin(id: name), options: PluginOptions())
            return
        }
        let object = try decoder.singleValueContainer().decode([String: JSONValue].self)
        if case .string(let path)? = object["path"] {
            let options = object["options"]?.objectValue ?? [:]
            entry = Config.PluginEntry(ref: .external(path: path), options: PluginOptions(options))
            return
        }
        guard object.count == 1, let (name, value) = object.first else {
            throw Config.ParseError(
                description: "plugin entry must be a name, `name: {options}`, or `path: ...`; got \(object.keys.sorted())")
        }
        entry = Config.PluginEntry(ref: .builtin(id: name), options: PluginOptions(value.objectValue ?? [:]))
    }
}
