import Foundation
import ProfileKit
import Testing

@testable import Plugins

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

let fixtureSnapshot: Snapshot = {
    let data = try! Data(contentsOf: repoRoot.appendingPathComponent("Fixtures/snapshot.json"))
    return try! Snapshot.decoder().decode(Snapshot.self, from: data)
}()

func scratchDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("cairn-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Suite struct BuiltinPluginTests {
    @Test func everyBuiltinRendersFromTheFixtureSnapshot() throws {
        #expect(Registry.builtins.count == 7)
        for (id, plugin) in Registry.builtins {
            let card = try plugin.render(fixtureSnapshot, options: PluginOptions())
            #expect(card.id == id)
            #expect(!card.blocks.isEmpty, "\(id) produced no blocks")
        }
    }

    @Test func activityHonorsDense() throws {
        let plugin = ActivityPlugin()
        let dense = try plugin.render(fixtureSnapshot, options: PluginOptions(["dense": .bool(true)]))
        guard case .stat(let stat) = dense.blocks[0] else {
            Issue.record("expected stat block")
            return
        }
        #expect(stat.dense)
        #expect(stat.value == Format.thousands(fixtureSnapshot.activity.totalCommitContributions))
    }

    @Test func repositoriesRespectsTopAndIgnore() throws {
        let plugin = RepositoriesPlugin()
        let card = try plugin.render(
            fixtureSnapshot,
            options: PluginOptions(["top": .int(3), "ignore": .array([.string("PHP")])]))
        guard case .barList(let bars) = card.blocks.last else {
            Issue.record("expected a bar list")
            return
        }
        #expect(bars.count == 3)
        #expect(!bars.contains { $0.label == "PHP" })
        // Percentages recompute over the remaining languages.
        #expect(bars[0].raw >= bars[1].raw)
    }

    @Test func languagesBarColorsAreGitHubColors() throws {
        let card = try LanguagesPlugin().render(fixtureSnapshot, options: PluginOptions())
        guard case .barList(let bars) = card.blocks[0] else {
            Issue.record("expected a bar list")
            return
        }
        let swift = bars.first { $0.label == "Swift" }
        #expect(swift?.color == "#F05138")
    }

    @Test func calendarStyleOption() throws {
        let plugin = CalendarPlugin()
        let flat = try plugin.render(fixtureSnapshot, options: PluginOptions())
        let iso = try plugin.render(fixtureSnapshot, options: PluginOptions(["style": .string("isometric")]))
        if case .heatmap(let payload) = flat.blocks[0] {
            #expect(payload.weekdayLabels)
            #expect(payload.weeks.count == 52)
            #expect(!payload.monthLabels.isEmpty)
        } else {
            Issue.record("flat style should emit .heatmap")
        }
        if case .isometricHeatmap = iso.blocks[0] {
        } else {
            Issue.record("isometric style should emit .isometricHeatmap")
        }
        #expect(flat.span == 2)
        #expect(try plugin.render(fixtureSnapshot, options: PluginOptions(["weeks": .int(23)]))
            .blocks.compactMap { if case .heatmap(let h) = $0 { h.weeks.count } else { nil } } == [23])
    }

    @Test func streaksCardHasGridAndSparkline() throws {
        let card = try StreaksPlugin().render(fixtureSnapshot, options: PluginOptions())
        guard case .statGrid(let grid) = card.blocks[0] else {
            Issue.record("expected stat grid first")
            return
        }
        #expect(grid.count == 2)
        #expect(grid[0].label == "current streak")
        if case .sparkline(let spark) = card.blocks[2] {
            #expect(spark.values.count == 12)
        } else {
            Issue.record("expected sparkline third")
        }
    }
}

@Suite struct ConfigTests {
    @Test func parsesTheSpecExample() throws {
        let yaml = """
            theme: default
            columns: 2
            output:
              branch: metrics
              dir: .
            plugins:
              - activity
              - repositories: { top: 6, ignore: [HTML, CSS] }
              - community
              - streaks: { timezone: America/Los_Angeles }
              - commits
              - calendar: { style: isometric, span: 2 }
              - path: ./plugins/wakatime
                options: { weeks: 4 }
            """
        let config = try Config.parse(yaml)
        #expect(config.theme == "default")
        #expect(config.columns == 2)
        #expect(config.output.branch == "metrics")
        #expect(config.plugins.count == 7)
        if case .builtin(let id) = config.plugins[1].ref {
            #expect(id == "repositories")
        }
        #expect(config.plugins[1].options.int("top", default: 0) == 6)
        #expect(config.plugins[1].options.strings("ignore") == ["HTML", "CSS"])
        #expect(config.plugins[3].options.string("timezone") == "America/Los_Angeles")
        if case .external(let path) = config.plugins[6].ref {
            #expect(path == "./plugins/wakatime")
        } else {
            Issue.record("expected external plugin entry")
        }
        #expect(config.plugins[6].options.int("weeks", default: 0) == 4)
        #expect(config.plugins[6].id == "wakatime")
    }

    @Test func missingFileYieldsDefaults() throws {
        let config = try Config.load(path: "/nonexistent/profile.yml")
        #expect(config.theme == "default")
        #expect(config.plugins.count == 6)
    }

    @Test func badPluginEntryThrows() {
        #expect(throws: (any Error).self) {
            try Config.parse("plugins:\n  - repositories: {top: 1}\n    extra: {x: 1}\n")
        }
    }
}

@Suite struct RenderPipelineTests {
    @Test func writesCardsComposedOutputAndCache() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pipeline = RenderPipeline(
            snapshot: fixtureSnapshot, config: Config(), outDir: dir, themesDir: nil)
        let outcomes = try await pipeline.run()
        #expect(outcomes.allSatisfy { $0.status == .ok })
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains("profile.light.svg"))
        #expect(files.contains("profile.dark.svg"))
        #expect(files.contains("activity.light.svg"))
        #expect(files.contains("calendar.dark.svg"))
        let cache = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("cache").path)
        #expect(Set(cache) == Set(Config().plugins.map { "\($0.id).json" }))
    }

    @Test func failedPluginFallsBackToCacheWithAsOfSubtitle() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Seed the cache with a healthy run.
        var config = Config()
        config.plugins = [Config.PluginEntry(ref: .builtin(id: "activity"), options: PluginOptions())]
        _ = try await RenderPipeline(
            snapshot: fixtureSnapshot, config: config, outDir: dir, themesDir: nil).run()

        // Now break the plugin by pointing the same id at a bad external path?
        // Simpler: an unknown builtin id with a cache file under the same id.
        let cacheFile = dir.appendingPathComponent("cache/activity.json")
        var broken = config
        broken.plugins = [Config.PluginEntry(ref: .external(path: "/nonexistent/activity"), options: PluginOptions())]
        // The external entry's id is "activity", matching the cached card.
        let outcomes = try await RenderPipeline(
            snapshot: fixtureSnapshot, config: broken, outDir: dir, themesDir: nil).run()
        #expect(outcomes.map(\.status) == [.cached])
        #expect(FileManager.default.fileExists(atPath: cacheFile.path))
        let svg = try String(
            contentsOf: dir.appendingPathComponent("activity.light.svg"), encoding: .utf8)
        #expect(svg.contains("cached · as of Aug 22"))
    }

    @Test func failedPluginWithNoCacheIsSkippedNotFatal() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var config = Config()
        config.plugins = [
            Config.PluginEntry(ref: .builtin(id: "activity"), options: PluginOptions()),
            Config.PluginEntry(ref: .external(path: "/nonexistent/broken"), options: PluginOptions()),
        ]
        let outcomes = try await RenderPipeline(
            snapshot: fixtureSnapshot, config: config, outDir: dir, themesDir: nil).run()
        #expect(outcomes.map(\.status) == [.ok, .skipped])
        // The composed grid still renders with the surviving card.
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("profile.light.svg").path))
    }

    @Test func stepSummaryIsAMarkdownTable() {
        let table = RenderPipeline.stepSummary([
            RenderPipeline.Outcome(id: "activity", status: .ok, milliseconds: 12),
            RenderPipeline.Outcome(id: "wakatime", status: .cached, milliseconds: 20004),
        ])
        #expect(table.contains("| activity | ok | 12 ms |"))
        #expect(table.contains("| wakatime | cached | 20004 ms |"))
    }
}

@Suite struct ExternalPluginTests {
    @Test func runsAScriptOverStdinStdout() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = dir.appendingPathComponent("echo-plugin")
        // Reads the snapshot, emits a fixed card naming the login.
        try #"""
            #!/bin/sh
            login=$(tr -d ' ' | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)
            printf '{"id":"echo","title":"Hello %s","span":1,"blocks":[{"text":{"_0":"external"}}]}' "$login"
            """#.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        let card = try await ExternalPluginRunner(path: script.path)
            .render(fixtureSnapshot, options: PluginOptions())
        #expect(card.id == "echo")
        #expect(card.title == "Hello kylebrowning")
    }

    @Test func nonZeroExitBecomesAnError() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = dir.appendingPathComponent("failing-plugin")
        try "#!/bin/sh\ncat > /dev/null\necho doomed >&2\nexit 3\n"
            .write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        await #expect(throws: ExternalPluginRunner.RunError.self) {
            _ = try await ExternalPluginRunner(path: script.path)
                .render(fixtureSnapshot, options: PluginOptions())
        }
    }
}
