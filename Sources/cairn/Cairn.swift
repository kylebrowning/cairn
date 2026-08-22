import ArgumentParser
import Foundation
import Render

@main
struct Cairn: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cairn",
        abstract: "Collects GitHub profile data and renders SVG cards for a profile README.",
        subcommands: [Themes.self]
    )
}

struct Themes: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List available themes.")

    func run() throws {
        for name in try ThemeLoader.availableThemes() {
            let variants = ThemeLoader.Variant.allCases
                .filter { bundledThemes["\(name).\($0.rawValue)"] != nil }
                .map(\.rawValue)
                .joined(separator: ", ")
            print("\(name) (\(variants))")
        }
    }
}
