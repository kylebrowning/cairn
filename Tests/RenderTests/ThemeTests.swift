import Foundation
import ProfileKit
import Testing
import Yams

@testable import Render

/// The repository root, located from this source file's path.
let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // ThemeTests.swift
    .deletingLastPathComponent()  // RenderTests
    .deletingLastPathComponent()  // Tests

let themesDir = repoRoot.appendingPathComponent("themes")

@Suite struct ThemeTests {
    static let expectedFiles = [
        "default.light.yml", "default.dark.yml",
        "paper.light.yml", "paper.dark.yml",
        "terminal.dark.yml",
        "ocean.light.yml", "ocean.dark.yml",
        "marker.light.yml", "marker.dark.yml",
    ]

    @Test func allExpectedThemeFilesExist() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: themesDir.path)
            .filter { $0.hasSuffix(".yml") }
        #expect(Set(files) == Set(Self.expectedFiles))
    }

    @Test(arguments: expectedFiles)
    func themeFileDecodesCompletely(file: String) throws {
        let theme = try ThemeLoader.load(contentsOf: themesDir.appendingPathComponent(file))
        #expect(theme.heatmap.scale.count == 5)
        #expect(!theme.font.stack.isEmpty)
        #expect(theme.font.sizeSmall >= 11, "11px is the design's hard floor")
        #expect(theme.card.bg.hasPrefix("#"))
    }

    @Test func bundledThemesMatchFilesOnDisk() throws {
        for file in Self.expectedFiles {
            let key = String(file.dropLast(4))
            let onDisk = try String(contentsOf: themesDir.appendingPathComponent(file), encoding: .utf8)
            let bundled = try #require(bundledThemes[key], "missing bundled theme \(key)")
            // Files carry a generated-by header; the bundled copy is the body
            // minus the final newline (Swift multiline literals strip it).
            #expect(onDisk.hasSuffix(bundled + "\n"), "bundled \(key) is stale — re-run scripts/generate-themes.py")
        }
        #expect(bundledThemes.count == Self.expectedFiles.count)
    }

    @Test func incompleteThemeIsRejected() throws {
        var yaml = try #require(bundledThemes["default.light"])
        yaml = yaml.replacingOccurrences(of: "  accent: \"#1a7f37\"\n", with: "")
        #expect(throws: (any Error).self) {
            try YAMLDecoder().decode(Theme.self, from: yaml)
        }
    }

    @Test func shortHeatScaleIsRejected() throws {
        var theme = try ThemeLoader.load(name: "default", variant: .light)
        theme.heatmap.scale.removeLast()
        #expect(throws: (any Error).self) { try theme.validate() }
    }

    @Test func terminalFallsBackToDark() throws {
        let theme = try ThemeLoader.load(name: "terminal", variant: .light)
        #expect(theme.card.radius == 0)
    }

    @Test func unknownThemeThrows() {
        #expect(throws: (any Error).self) {
            try ThemeLoader.load(name: "nope", variant: .light)
        }
    }

    @Test func availableThemesListsAllFive() throws {
        #expect(try ThemeLoader.availableThemes() == ["default", "marker", "ocean", "paper", "terminal"])
        #expect(try ThemeLoader.availableThemes(in: themesDir) == ["default", "marker", "ocean", "paper", "terminal"])
    }
}
