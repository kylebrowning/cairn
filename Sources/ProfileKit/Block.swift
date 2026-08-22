/// The block vocabulary. Plugins compose cards exclusively from these; they
/// never choose colors, fonts, or pixel positions. Payloads carry exactly the
/// fields `design/components.md` says each block needs.
public enum Block: Codable, Sendable {
    /// Icon, label, right-aligned value.
    case stat(Stat)
    /// 2 or 3 headline numbers.
    case statGrid([BigStat])
    /// 52-53 weeks x 7 days, levels 0-4.
    case heatmap(Heatmap)
    /// Same data, 3D projection.
    case isometricHeatmap(Heatmap)
    /// Values with an optional end label.
    case sparkline(Sparkline)
    /// Label, value, optional color.
    case barList([Bar])
    case badgeRow([Badge])
    case text(String)
    case divider(String?)
}

public struct Stat: Codable, Sendable {
    public var icon: Icon
    public var label: String
    public var value: String
    /// 20px rows instead of 24px — for stacks of 8+.
    public var dense: Bool

    public init(icon: Icon, label: String, value: String, dense: Bool = false) {
        self.icon = icon
        self.label = label
        self.value = value
        self.dense = dense
    }
}

public struct BigStat: Codable, Sendable {
    public var value: String
    public var label: String
    /// Renders the value in the theme accent color.
    public var accent: Bool

    public init(value: String, label: String, accent: Bool = false) {
        self.value = value
        self.label = label
        self.accent = accent
    }
}

public struct Heatmap: Codable, Sendable {
    /// A month label above the week at `week` (0-based column index).
    public struct MonthLabel: Codable, Sendable, Equatable {
        public var week: Int
        /// 0 = Jan.
        public var month: Int

        public init(week: Int, month: Int) {
            self.week = week
            self.month = month
        }
    }

    /// Weeks oldest-first; each week is up to 7 levels (0-4), Sunday first.
    public var weeks: [[Int]]
    /// Labels for the 20px month band — one per first week of a month.
    public var monthLabels: [MonthLabel]
    /// Show the Mon/Wed/Fri gutter (flat variant only).
    public var weekdayLabels: Bool

    public init(weeks: [[Int]], monthLabels: [MonthLabel] = [], weekdayLabels: Bool = true) {
        self.weeks = weeks
        self.monthLabels = monthLabels
        self.weekdayLabels = weekdayLabels
    }
}

public struct Sparkline: Codable, Sendable {
    public var values: [Double]
    /// Optional label next to the end dot.
    public var label: String?

    public init(values: [Double], label: String? = nil) {
        self.values = values
        self.label = label
    }
}

public struct Bar: Codable, Sendable {
    public var label: String
    /// Display string, e.g. "34%".
    public var value: String
    /// Bar length relative to the largest `raw` in the list.
    public var raw: Double
    /// The one place a plugin may pass a color — GitHub language colors only.
    public var color: String?

    public init(label: String, value: String, raw: Double, color: String? = nil) {
        self.label = label
        self.value = value
        self.raw = raw
        self.color = color
    }
}

public struct Badge: Codable, Sendable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}
