import Foundation
import Logging
import ProfileKit
import Render

/// Builds every configured card (with cache fallback), renders light and dark
/// SVGs per card plus the composed grid, and reports per-plugin outcomes.
/// A failing plugin never fails the run.
public struct RenderPipeline {
    public enum Status: String, Sendable {
        case ok
        case cached
        case skipped
    }

    public struct Outcome: Sendable {
        public var id: String
        public var status: Status
        public var milliseconds: Int
    }

    public struct CacheEnvelope: Codable {
        public var generatedAt: Date
        public var card: Card
    }

    public let snapshot: Snapshot
    public let config: Config
    public let outDir: URL
    public let themesDir: URL?
    let logger = Logger(label: "cairn.render")

    public init(snapshot: Snapshot, config: Config, outDir: URL, themesDir: URL?) {
        self.snapshot = snapshot
        self.config = config
        self.outDir = outDir
        self.themesDir = themesDir
    }

    public var cacheDir: URL {
        outDir.appendingPathComponent("cache")
    }

    public func run() async throws -> [Outcome] {
        let fm = FileManager.default
        try fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        var cards: [Card] = []
        var outcomes: [Outcome] = []
        for entry in config.plugins {
            let started = ContinuousClock.now
            do {
                var card = try await buildCard(entry)
                if let span = entry.options["span"]?.intValue {
                    card.span = span
                }
                cards.append(card)
                try writeCache(entry.id, card: card)
                outcomes.append(outcome(entry.id, .ok, started))
            } catch {
                logger.error("plugin \(entry.id) failed: \(error)")
                if let cached = readCache(entry.id) {
                    var card = cached.card
                    card.subtitle = "cached · \(Format.asOf(cached.generatedAt))"
                    cards.append(card)
                    outcomes.append(outcome(entry.id, .cached, started))
                } else {
                    logger.error("no cached card for \(entry.id) — skipping")
                    outcomes.append(outcome(entry.id, .skipped, started))
                }
            }
        }

        for variant in ThemeLoader.Variant.allCases {
            let theme = try ThemeLoader.load(name: config.theme, variant: variant, themesDirectory: themesDir)
            for card in cards {
                let width = card.span >= 2
                    ? Metrics.columnCardWidth * Double(config.columns)
                        + Metrics.gutter * Double(config.columns - 1)
                    : Metrics.columnCardWidth
                let svg = CardRenderer.render(card: card, theme: theme, width: width)
                try write(svg, to: "\(card.id).\(variant.rawValue).svg")
            }
            let composed = GridRenderer.render(cards: cards, theme: theme, columns: config.columns)
            try write(composed, to: "profile.\(variant.rawValue).svg")
        }
        return outcomes
    }

    private func buildCard(_ entry: Config.PluginEntry) async throws -> Card {
        switch entry.ref {
        case .builtin(let id):
            guard let plugin = Registry.plugin(id: id) else {
                throw Config.ParseError(description: "unknown plugin \(id)")
            }
            return try plugin.render(snapshot, options: entry.options)
        case .external(let path):
            return try await ExternalPluginRunner(path: path).render(snapshot, options: entry.options)
        }
    }

    private func outcome(_ id: String, _ status: Status, _ started: ContinuousClock.Instant) -> Outcome {
        let elapsed = started.duration(to: .now)
        let ms = Int(elapsed.components.seconds * 1000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        return Outcome(id: id, status: status, milliseconds: ms)
    }

    private func write(_ svg: String, to name: String) throws {
        try svg.write(to: outDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func writeCache(_ id: String, card: Card) throws {
        let envelope = CacheEnvelope(generatedAt: snapshot.generatedAt, card: card)
        try Snapshot.encoder().encode(envelope)
            .write(to: cacheDir.appendingPathComponent("\(id).json"))
    }

    private func readCache(_ id: String) -> CacheEnvelope? {
        guard let data = try? Data(contentsOf: cacheDir.appendingPathComponent("\(id).json")) else {
            return nil
        }
        return try? Snapshot.decoder().decode(CacheEnvelope.self, from: data)
    }

    /// Markdown table for `GITHUB_STEP_SUMMARY`.
    public static func stepSummary(_ outcomes: [Outcome]) -> String {
        var lines = ["| Plugin | Status | Time |", "| --- | --- | --- |"]
        for outcome in outcomes {
            lines.append("| \(outcome.id) | \(outcome.status.rawValue) | \(outcome.milliseconds) ms |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func appendStepSummary(_ outcomes: [Outcome]) {
        guard let path = ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"] else { return }
        let table = "## cairn\n\n" + stepSummary(outcomes)
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(Data(table.utf8))
            try? handle.close()
        }
    }
}
