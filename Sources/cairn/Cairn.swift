import ArgumentParser
import Collect
import Foundation
import Logging
import Plugins
import ProfileKit
import Render

@main
struct Cairn: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cairn",
        abstract: "Collects GitHub profile data and renders SVG cards for a profile README.",
        subcommands: [CollectCommand.self, RenderCommand.self, RunCommand.self, Themes.self, Validate.self]
    )

    /// Logs go to stderr; stdout is for command output only.
    static func bootstrapLogging() {
        LoggingSystem.bootstrap { label in
            StreamLogHandler.standardError(label: label)
        }
    }
}

struct CommonOptions: ParsableArguments {
    @Option(name: .long, help: "Path to the config file.")
    var config: String = ".github/profile.yml"

    @Option(name: .long, help: "Directory of theme YAML files (default: themes bundled in the binary).")
    var themesDir: String?

    var themesDirURL: URL? {
        themesDir.map { URL(fileURLWithPath: $0) }
    }
}

struct CollectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "collect",
        abstract: "Fetch profile data from the GitHub API into a snapshot file.")

    @Option(name: .long, help: "GitHub login to collect.")
    var login: String

    @Option(name: .long, help: "Environment variable holding the API token.")
    var tokenEnv: String = "GITHUB_TOKEN"

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Where to write the snapshot.")
    var out: String = "snapshot.json"

    func run() async throws {
        Cairn.bootstrapLogging()
        let snapshot = try await Self.collect(login: login, tokenEnv: tokenEnv, configPath: common.config)
        try Snapshot.encoder().encode(snapshot).write(to: URL(fileURLWithPath: out))
        FileHandle.standardError.write(Data("wrote \(out)\n".utf8))
    }

    static func collect(login: String, tokenEnv: String, configPath: String) async throws -> Snapshot {
        guard let token = ProcessInfo.processInfo.environment[tokenEnv], !token.isEmpty else {
            throw ValidationError("no token in $\(tokenEnv)")
        }
        let config = try Config.load(path: configPath)
        let plugins = config.plugins.compactMap { entry -> (any Plugin)? in
            if case .builtin(let id) = entry.ref {
                return Registry.plugin(id: id)
            }
            return nil
        }
        let client = GitHubClient(token: token)
        return try await SnapshotBuilder.build(login: login, client: client, plugins: plugins)
    }
}

struct RenderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract: "Render SVG cards from a snapshot. Never touches the network.")

    @Option(name: .long, help: "Snapshot file from `cairn collect`.")
    var snapshot: String = "snapshot.json"

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Output directory.")
    var out: String = "./out"

    func run() async throws {
        Cairn.bootstrapLogging()
        let data = try Data(contentsOf: URL(fileURLWithPath: snapshot))
        let decoded = try Snapshot.decoder().decode(Snapshot.self, from: data)
        _ = try await Self.render(
            snapshot: decoded, configPath: common.config,
            outDir: out, themesDir: common.themesDirURL)
    }

    @discardableResult
    static func render(
        snapshot: Snapshot, configPath: String, outDir: String, themesDir: URL?
    ) async throws -> [RenderPipeline.Outcome] {
        let config = try Config.load(path: configPath)
        let outURL = URL(fileURLWithPath: outDir)
        try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
        let pipeline = RenderPipeline(
            snapshot: snapshot, config: config, outDir: outURL, themesDir: themesDir)
        let outcomes = try await pipeline.run()
        RenderPipeline.appendStepSummary(outcomes)
        for outcome in outcomes {
            FileHandle.standardError.write(
                Data("\(outcome.id): \(outcome.status.rawValue) (\(outcome.milliseconds) ms)\n".utf8))
        }
        return outcomes
    }
}

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Collect then render, falling back to cached data on failure.")

    @Option(name: .long, help: "GitHub login to collect.")
    var login: String

    @Option(name: .long, help: "Environment variable holding the API token.")
    var tokenEnv: String = "GITHUB_TOKEN"

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Snapshot path (also the collect-failure fallback).")
    var snapshot: String = "snapshot.json"

    @Option(name: .long, help: "Output directory.")
    var out: String = "./out"

    func run() async throws {
        Cairn.bootstrapLogging()
        let logger = Logger(label: "cairn.run")
        var current: Snapshot?
        do {
            let collected = try await CollectCommand.collect(
                login: login, tokenEnv: tokenEnv, configPath: common.config)
            try Snapshot.encoder().encode(collected).write(to: URL(fileURLWithPath: snapshot))
            current = collected
        } catch {
            logger.error("collect failed: \(error) — falling back to \(snapshot)")
            if let data = try? Data(contentsOf: URL(fileURLWithPath: snapshot)),
               let previous = try? Snapshot.decoder().decode(Snapshot.self, from: data)
            {
                current = previous
            }
        }
        guard let snapshotToRender = current else {
            throw ValidationError("collect failed and no previous \(snapshot) exists")
        }
        _ = try await RenderCommand.render(
            snapshot: snapshotToRender, configPath: common.config,
            outDir: out, themesDir: common.themesDirURL)
    }
}

struct Themes: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List available themes.")

    @OptionGroup var common: CommonOptions

    func run() throws {
        for name in try ThemeLoader.availableThemes(in: common.themesDirURL) {
            let variants = ThemeLoader.Variant.allCases.filter { variant in
                if let dir = common.themesDirURL {
                    return FileManager.default.fileExists(
                        atPath: dir.appendingPathComponent("\(name).\(variant.rawValue).yml").path)
                }
                return bundledThemes["\(name).\(variant.rawValue)"] != nil
            }
            print("\(name) (\(variants.map(\.rawValue).joined(separator: ", ")))")
        }
    }
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Validate a config file.")

    @OptionGroup var common: CommonOptions

    func run() throws {
        var problems: [String] = []
        let config: Config
        do {
            config = try Config.load(path: common.config)
        } catch {
            throw ValidationError("config does not parse: \(error)")
        }
        let themes = (try? ThemeLoader.availableThemes(in: common.themesDirURL)) ?? []
        if !themes.contains(config.theme) {
            problems.append("unknown theme \(config.theme) (available: \(themes.joined(separator: ", ")))")
        }
        if config.columns < 1 || config.columns > 3 {
            problems.append("columns must be 1-3, got \(config.columns)")
        }
        for entry in config.plugins {
            switch entry.ref {
            case .builtin(let id):
                if Registry.plugin(id: id) == nil {
                    problems.append("unknown plugin \(id) (available: \(Registry.builtins.keys.sorted().joined(separator: ", ")))")
                }
            case .external(let path):
                if !FileManager.default.isExecutableFile(atPath: path) {
                    problems.append("external plugin \(path) is not an executable file")
                }
            }
        }
        guard problems.isEmpty else {
            throw ValidationError(problems.joined(separator: "\n"))
        }
        print("\(common.config): OK — theme \(config.theme), \(config.plugins.count) plugin(s)")
    }
}
