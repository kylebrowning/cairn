import Foundation
import ProfileKit
import Testing

@testable import Render

let lightTheme = try! ThemeLoader.load(name: "default", variant: .light)

/// Wraps a block render in a standalone document so goldens open in a browser.
func blockDocument(_ block: Block, width: Double, theme: Theme = lightTheme) -> String {
    let height = BlockRenderers.height(of: block, width: width, theme: theme)
    let body = BlockRenderers.render(block, at: Point(10, 10), width: width, theme: theme)
    let icons = BlockRenderers.icons(in: block)
    let doc = Svg(width: width + 20, height: height + 20, viewBox: "0 0 \(num(width + 20)) \(num(height + 20))") {
        if !icons.isEmpty {
            Defs {
                for icon in icons {
                    Symbol(id: "icon-\(icon.rawValue)", viewBox: "0 0 16 16", rawContent: iconPaths[icon.rawValue] ?? "")
                }
            }
        }
        Rect(x: 0, y: 0, width: width + 20, height: height + 20, fill: theme.card.bg)
        body
    }
    return SVG(nodes: [doc]).serialize()
}

/// Deterministic pseudo-random contribution levels, mirroring the design
/// bundle's demoLevels(seed: 7) so goldens match the mockup's shape.
func demoLevels(weeks: Int, seed: Int = 7) -> [[Int]] {
    var s = seed
    func rnd() -> Double {
        s = (s * 1_103_515_245 + 12345) % 2_147_483_648
        return Double(s) / 2_147_483_648
    }
    return (0..<weeks).map { w in
        (0..<7).map { d in
            let busy = d > 0 && d < 6 ? 0.18 : 0.0
            let wave = 0.15 * Foundation.sin(Double(w) / 5)
            let v = rnd() + busy + wave
            return v < 0.45 ? 0 : v < 0.68 ? 1 : v < 0.85 ? 2 : v < 0.96 ? 3 : 4
        }
    }
}

/// Month labels every ~4.33 weeks, like the mockup's demo data.
func demoMonthLabels(weeks: Int, startMonth: Int = 8) -> [Heatmap.MonthLabel] {
    stride(from: 0, to: weeks, by: 4).map {
        Heatmap.MonthLabel(week: $0, month: (startMonth + Int(Double($0) / 4.33)) % 12)
    }
}

@Suite struct BlockHeightTests {
    let theme = lightTheme

    @Test func statRowHeights() {
        let dense = Block.stat(Stat(icon: .commit, label: "Commits", value: "13,100", dense: true))
        let regular = Block.stat(Stat(icon: .repo, label: "Repositories", value: "112"))
        #expect(BlockRenderers.height(of: dense, width: 400, theme: theme) == 20)
        #expect(BlockRenderers.height(of: regular, width: 400, theme: theme) == 24)
    }

    @Test func fixedHeights() {
        #expect(BlockRenderers.height(of: .statGrid([BigStat(value: "1", label: "x")]), width: 400, theme: theme) == 48)
        #expect(BlockRenderers.height(of: .divider(nil), width: 400, theme: theme) == 16)
        #expect(BlockRenderers.height(of: .sparkline(Sparkline(values: [1, 2])), width: 400, theme: theme) == 40)
    }

    @Test func heatmapHeightIsMonthBandPlusSevenRows() {
        let block = Block.heatmap(Heatmap(weeks: demoLevels(weeks: 53), monthLabels: demoMonthLabels(weeks: 53)))
        // 20 + 7*14 - 3 = 115 per design/components.md
        #expect(BlockRenderers.height(of: block, width: 860, theme: theme) == 115)
    }

    @Test func barListHeightIsRowCount() {
        let bars = [Bar(label: "Swift", value: "34%", raw: 34), Bar(label: "Go", value: "21%", raw: 21)]
        #expect(BlockRenderers.height(of: .barList(bars), width: 400, theme: theme) == 40)
    }

    @Test func badgeRowWraps() {
        let badges = (0..<12).map { Badge(text: "badge-\($0)") }
        let narrow = BlockRenderers.height(of: .badgeRow(badges), width: 200, theme: theme)
        let wide = BlockRenderers.height(of: .badgeRow(badges), width: 900, theme: theme)
        #expect(wide == 20)
        #expect(narrow > 20)
        // Height is always a whole number of 26px lines minus the trailing gap.
        #expect((narrow + 6).truncatingRemainder(dividingBy: 26) == 0)
    }

    @Test func textBlockWrapsAt18PerLine() {
        let short = BlockRenderers.height(of: .text("hello"), width: 400, theme: theme)
        let long = BlockRenderers.height(
            of: .text(String(repeating: "wide words ", count: 20)), width: 200, theme: theme)
        #expect(short == 18)
        #expect(long > 18)
        #expect(long.truncatingRemainder(dividingBy: 18) == 0)
    }
}

@Suite struct TextMeasureTests {
    @Test func truncateAppendsEllipsisAndFits() {
        let style = TextMeasure.Style(size: 12)
        let long = "an-extremely-long-repository-name-that-cannot-fit"
        let cut = TextMeasure.truncate(long, toFit: 120, style: style)
        #expect(cut.hasSuffix("…"))
        #expect(TextMeasure.width(of: cut, style: style) <= 120)
        #expect(TextMeasure.truncate("short", toFit: 120, style: style) == "short")
    }

    @Test func widthOverestimates() {
        // The table carries a 5% safety factor; "wide" text costs more than narrow.
        let style = TextMeasure.Style(size: 12)
        #expect(TextMeasure.width(of: "MMMM", style: style) > TextMeasure.width(of: "iiii", style: style))
        #expect(TextMeasure.width(of: "", style: style) == 0)
    }

    @Test func monoIsFixedAdvance() {
        let style = TextMeasure.Style(size: 12, family: .mono)
        #expect(TextMeasure.width(of: "MMMM", style: style) == TextMeasure.width(of: "iiii", style: style))
    }
}

@Suite struct BlockGoldenTests {
    @Test func statRow() throws {
        try assertGolden(
            "block-stat",
            blockDocument(.stat(Stat(icon: .commit, label: "Commits", value: "13,100")), width: 400))
    }

    @Test func statRowDense() throws {
        try assertGolden(
            "block-stat-dense",
            blockDocument(.stat(Stat(icon: .pr, label: "PRs opened", value: "915", dense: true)), width: 400))
    }

    @Test func statGrid() throws {
        let items = [
            BigStat(value: "13.1k", label: "total commits"),
            BigStat(value: "670", label: "highest day", accent: true),
            BigStat(value: "~26.1", label: "avg / day"),
        ]
        try assertGolden("block-statgrid", blockDocument(.statGrid(items), width: 400))
    }

    @Test func divider() throws {
        try assertGolden("block-divider", blockDocument(.divider("popularity"), width: 400))
        try assertGolden("block-divider-plain", blockDocument(.divider(nil), width: 400))
    }

    @Test func sparkline() throws {
        let values: [Double] = [14, 22, 18, 31, 26, 12, 19, 28, 35, 24, 30, 41, 33, 26]
        try assertGolden(
            "block-sparkline",
            blockDocument(.sparkline(Sparkline(values: values, label: "26")), width: 392))
    }

    @Test func barList() throws {
        let bars = [
            Bar(label: "Swift", value: "34%", raw: 34, color: "#F05138"),
            Bar(label: "Go", value: "21%", raw: 21, color: "#00ADD8"),
            Bar(label: "TypeScript", value: "18%", raw: 18, color: "#3178c6"),
            Bar(label: "Shell", value: "11%", raw: 11, color: "#89e051"),
            Bar(label: "Python", value: "9%", raw: 9, color: "#3572A5"),
            Bar(label: "Ruby", value: "7%", raw: 7, color: "#701516"),
        ]
        try assertGolden("block-barlist", blockDocument(.barList(bars), width: 400))
    }

    @Test func badgeRow() throws {
        let badges = ["swift", "server-side", "grpc", "vapor", "apns", "open source contributor"]
            .map(Badge.init(text:))
        try assertGolden("block-badgerow", blockDocument(.badgeRow(badges), width: 260))
    }

    @Test func textBlock() throws {
        try assertGolden(
            "block-text",
            blockDocument(.text("These metrics include private contributions — updated daily by GitHub Actions"), width: 400))
    }

    @Test func heatmap() throws {
        let block = Block.heatmap(Heatmap(weeks: demoLevels(weeks: 53), monthLabels: demoMonthLabels(weeks: 53)))
        try assertGolden("block-heatmap", blockDocument(block, width: 860))
    }

    @Test func heatmapDropsOldestWeeksWhenNarrow() throws {
        let block = Block.heatmap(Heatmap(weeks: demoLevels(weeks: 53), monthLabels: demoMonthLabels(weeks: 53), weekdayLabels: false))
        try assertGolden("block-heatmap-narrow", blockDocument(block, width: 320))
    }

    @Test func isometricHeatmap() throws {
        let block = Block.isometricHeatmap(Heatmap(weeks: demoLevels(weeks: 53), monthLabels: demoMonthLabels(weeks: 53), weekdayLabels: false))
        try assertGolden("block-heatmap-iso", blockDocument(block, width: 860))
    }
}
