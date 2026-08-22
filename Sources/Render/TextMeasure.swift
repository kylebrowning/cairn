import ProfileKit

/// Estimated text metrics. No font is available at render time, so widths come
/// from per-character average-width tables (em units) calibrated against the
/// design's system stacks, then padded 5% so text never clips.
public enum TextMeasure {
    public enum Family: Sendable {
        case sans
        case mono

        /// Picks the table for a theme's font stack.
        public init(stack: String) {
            self = stack.lowercased().contains("mono") ? .mono : .sans
        }
    }

    public struct Style: Sendable {
        public var size: Double
        public var weight: Int
        public var family: Family

        public init(size: Double, weight: Int = 400, family: Family = .sans) {
            self.size = size
            self.weight = weight
            self.family = family
        }
    }

    /// Overestimate factor: better a little air than a clipped label.
    static let safety = 1.05
    static let boldFactor = 1.05

    /// Average advance widths in em for the system sans stack.
    static let sansWidths: [Character: Double] = {
        var w: [Character: Double] = [:]
        func set(_ chars: String, _ width: Double) {
            for c in chars { w[c] = width }
        }
        set("iljI.,:;'|!", 0.28)
        set("ftr()[]{}/\\ ", 0.34)
        set("\"", 0.36)
        set("abcdeghknopqsuvxyz", 0.55)
        set("mw", 0.85)
        set("ABCDEFGHKLNPRSTUVXYZ", 0.68)
        set("JOQ", 0.72)
        set("MW", 0.92)
        set("0123456789", 0.56)
        set("-–", 0.36)
        set("—", 0.72)
        set("~+=<>", 0.58)
        set("%", 0.89)
        set("&@", 0.80)
        set("#$_", 0.56)
        set("*^", 0.46)
        set("·", 0.28)
        return w
    }()

    static let sansDefault = 0.60
    static let monoAdvance = 0.60

    public static func width(of text: String, style: Style) -> Double {
        let em: Double
        switch style.family {
        case .mono:
            em = Double(text.count) * monoAdvance
        case .sans:
            em = text.reduce(0) { $0 + (sansWidths[$1] ?? sansDefault) }
        }
        let bold = style.weight >= 600 ? boldFactor : 1.0
        return em * style.size * bold * safety
    }

    /// Truncates with an ellipsis so the result fits `maxWidth`. Returns the
    /// text unchanged when it already fits.
    public static func truncate(_ text: String, toFit maxWidth: Double, style: Style) -> String {
        guard width(of: text, style: style) > maxWidth else { return text }
        let ellipsis = "…"
        var kept = ""
        for char in text {
            let candidate = kept + String(char)
            if width(of: candidate + ellipsis, style: style) > maxWidth {
                break
            }
            kept = candidate
        }
        return kept + ellipsis
    }

    /// Baseline offset below a line's vertical center — places text visually
    /// centered the way the mockup's flexbox does.
    public static func baselineOffset(size: Double) -> Double {
        size * 0.35
    }

    /// Greedy word wrap to a width; used by the text block.
    public static func wrap(_ text: String, toFit maxWidth: Double, style: Style) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            let candidate = current.isEmpty ? String(word) : current + " " + word
            if width(of: candidate, style: style) > maxWidth && !current.isEmpty {
                lines.append(current)
                current = String(word)
            } else {
                current = candidate
            }
        }
        if !current.isEmpty || lines.isEmpty {
            lines.append(current)
        }
        return lines
    }
}
