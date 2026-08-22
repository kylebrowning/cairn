import ProfileKit

/// Shared language aggregation for the repositories and languages plugins.
enum LanguageStats {
    /// Top languages by bytes across non-fork repositories, as bar-list bars
    /// with percentage values and GitHub language colors.
    static func topLanguages(in snapshot: Snapshot, top: Int, ignore: [String]) -> [Bar] {
        let ignored = Set(ignore.map { $0.lowercased() })
        var bytes: [String: (size: Int, color: String?)] = [:]
        for repo in snapshot.repositories where !repo.isFork {
            for language in repo.languages where !ignored.contains(language.name.lowercased()) {
                let existing = bytes[language.name]
                bytes[language.name] = (
                    (existing?.size ?? 0) + language.size,
                    existing?.color ?? language.color
                )
            }
        }
        let total = bytes.values.reduce(0) { $0 + $1.size }
        guard total > 0 else { return [] }
        return bytes
            .sorted { $0.value.size == $1.value.size ? $0.key < $1.key : $0.value.size > $1.value.size }
            .prefix(top)
            .map { name, info in
                let percent = Double(info.size) / Double(total) * 100
                return Bar(
                    label: name,
                    value: percent < 1 ? "<1%" : "\(Int(percent.rounded()))%",
                    raw: Double(info.size),
                    color: info.color
                )
            }
    }
}
