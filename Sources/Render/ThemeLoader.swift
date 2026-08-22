import Foundation
import ProfileKit
import Yams

/// Loads and enumerates the YAML theme files shipped in `themes/`.
public enum ThemeLoader {
    public enum LoadError: Error, CustomStringConvertible {
        case unreadable(String)
        case notFound(name: String, variant: Variant, searched: String)

        public var description: String {
            switch self {
            case .unreadable(let path):
                return "cannot read theme file \(path)"
            case .notFound(let name, let variant, let searched):
                return "no theme \(name).\(variant.rawValue).yml in \(searched)"
            }
        }
    }

    public enum Variant: String, Sendable, CaseIterable {
        case light
        case dark
    }

    public static func load(contentsOf url: URL) throws -> Theme {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw LoadError.unreadable(url.path)
        }
        let theme = try YAMLDecoder().decode(Theme.self, from: text)
        try theme.validate()
        return theme
    }

    /// Loads theme `<name>.<variant>`, from `themesDirectory` when given,
    /// otherwise from the themes embedded in the binary. A theme missing the
    /// requested variant (Terminal has no light) falls back to the variant it
    /// does have.
    public static func load(name: String, variant: Variant, themesDirectory: URL? = nil) throws -> Theme {
        let other = variant == .light ? Variant.dark : .light
        if let dir = themesDirectory {
            for v in [variant, other] {
                let url = dir.appendingPathComponent("\(name).\(v.rawValue).yml")
                if FileManager.default.fileExists(atPath: url.path) {
                    return try load(contentsOf: url)
                }
            }
            throw LoadError.notFound(name: name, variant: variant, searched: dir.path)
        }
        for v in [variant, other] {
            if let yaml = bundledThemes["\(name).\(v.rawValue)"] {
                let theme = try YAMLDecoder().decode(Theme.self, from: yaml)
                try theme.validate()
                return theme
            }
        }
        throw LoadError.notFound(name: name, variant: variant, searched: "bundled themes")
    }

    /// Theme names available, sorted. Reads a directory when given, otherwise
    /// the embedded set.
    public static func availableThemes(in themesDirectory: URL? = nil) throws -> [String] {
        let keys: [String]
        if let dir = themesDirectory {
            keys = try FileManager.default.contentsOfDirectory(atPath: dir.path)
                .filter { $0.hasSuffix(".yml") }
                .map { String($0.dropLast(4)) }
        } else {
            keys = Array(bundledThemes.keys)
        }
        let names = keys.compactMap { key -> String? in
            let parts = key.split(separator: ".")
            guard parts.count == 2 else { return nil }
            return String(parts[0])
        }
        return Array(Set(names)).sorted()
    }
}
