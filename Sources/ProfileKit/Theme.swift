/// A complete theme — mirrors the 23-token list in `design/tokens/` exactly.
/// Every field is required: a theme file is complete or it is rejected.
public struct Theme: Codable, Sendable, Equatable {
    public struct Font: Codable, Sendable, Equatable {
        /// System font stack, verbatim CSS value.
        public var stack: String
        public var sizeBase: Double
        public var sizeTitle: Double
        public var sizeSmall: Double

        public init(stack: String, sizeBase: Double, sizeTitle: Double, sizeSmall: Double) {
            self.stack = stack
            self.sizeBase = sizeBase
            self.sizeTitle = sizeTitle
            self.sizeSmall = sizeSmall
        }
    }

    public struct CardStyle: Codable, Sendable, Equatable {
        public var bg: String
        public var border: String
        public var borderWidth: Double
        public var radius: Double
        public var padding: Double

        public init(bg: String, border: String, borderWidth: Double, radius: Double, padding: Double) {
            self.bg = bg
            self.border = border
            self.borderWidth = borderWidth
            self.radius = radius
            self.padding = padding
        }
    }

    public struct TextColors: Codable, Sendable, Equatable {
        public var primary: String
        public var muted: String
        public var accent: String

        public init(primary: String, muted: String, accent: String) {
            self.primary = primary
            self.muted = muted
            self.accent = accent
        }
    }

    public struct HeatmapScale: Codable, Sendable, Equatable {
        /// Exactly 5 colors, level 0 (none) through 4 (most).
        public var scale: [String]

        public init(scale: [String]) {
            self.scale = scale
        }
    }

    public struct Spark: Codable, Sendable, Equatable {
        public var stroke: String
        /// May carry alpha as 8-digit hex, e.g. "#2da44e29".
        public var fill: String

        public init(stroke: String, fill: String) {
            self.stroke = stroke
            self.fill = fill
        }
    }

    public struct BarStyle: Codable, Sendable, Equatable {
        public var track: String
        public var fill: String

        public init(track: String, fill: String) {
            self.track = track
            self.fill = fill
        }
    }

    public struct BadgeStyle: Codable, Sendable, Equatable {
        public var bg: String
        public var text: String

        public init(bg: String, text: String) {
            self.bg = bg
            self.text = text
        }
    }

    public var font: Font
    public var card: CardStyle
    public var text: TextColors
    public var heatmap: HeatmapScale
    public var spark: Spark
    public var bar: BarStyle
    public var badge: BadgeStyle

    public init(
        font: Font,
        card: CardStyle,
        text: TextColors,
        heatmap: HeatmapScale,
        spark: Spark,
        bar: BarStyle,
        badge: BadgeStyle
    ) {
        self.font = font
        self.card = card
        self.text = text
        self.heatmap = heatmap
        self.spark = spark
        self.bar = bar
        self.badge = badge
    }

    public enum ValidationError: Error, CustomStringConvertible {
        case wrongHeatScaleCount(Int)

        public var description: String {
            switch self {
            case .wrongHeatScaleCount(let n):
                return "heatmap.scale must have exactly 5 colors, found \(n)"
            }
        }
    }

    /// Structural checks Codable can't express.
    public func validate() throws {
        guard heatmap.scale.count == 5 else {
            throw ValidationError.wrongHeatScaleCount(heatmap.scale.count)
        }
    }
}
