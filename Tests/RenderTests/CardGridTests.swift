import Foundation
import ProfileKit
import Testing

@testable import Render

/// The card set from the design mockup (`design/mockups/GitHub Profile.html`),
/// verbatim values — the milestone-3 reference layout.
enum MockupCards {
    static let activity = Card(
        id: "activity", title: "Activity", icon: .flame,
        blocks: [
            .stat(Stat(icon: .commit, label: "Commits", value: "13,100", dense: true)),
            .stat(Stat(icon: .pr, label: "PRs opened", value: "915", dense: true)),
            .stat(Stat(icon: .merge, label: "PRs reviewed", value: "39", dense: true)),
            .stat(Stat(icon: .issue, label: "Issues opened", value: "15", dense: true)),
            .stat(Stat(icon: .comment, label: "Issue comments", value: "1,462", dense: true)),
            .stat(Stat(icon: .people, label: "Contributed to", value: "75", dense: true)),
        ])

    static let repositories = Card(
        id: "repositories", title: "Repositories", icon: .repo,
        blocks: [
            .stat(Stat(icon: .repo, label: "Repositories", value: "112")),
            .stat(Stat(icon: .package, label: "Packages", value: "1")),
            .stat(Stat(icon: .tag, label: "Releases", value: "0")),
            .stat(Stat(icon: .database, label: "Storage used", value: "4.36 GB")),
            .divider("popularity"),
            .statGrid([
                BigStat(value: "0", label: "sponsors"),
                BigStat(value: "0", label: "stargazers"),
                BigStat(value: "0", label: "forkers"),
                BigStat(value: "0", label: "watchers"),
            ]),
        ])

    static let community = Card(
        id: "community", title: "Community", icon: .people,
        blocks: [
            .stat(Stat(icon: .heart, label: "Followers", value: "203")),
            .stat(Stat(icon: .people, label: "Following", value: "39")),
            .stat(Stat(icon: .organization, label: "Organizations", value: "6")),
            .stat(Stat(icon: .star, label: "Starred", value: "154")),
            .stat(Stat(icon: .eye, label: "Watching", value: "13")),
            .stat(Stat(icon: .sparkle, label: "Sponsoring", value: "0")),
        ])

    static let commits = Card(
        id: "commits", title: "Commits", icon: .commit,
        blocks: [
            .statGrid([
                BigStat(value: "13.1k", label: "total commits"),
                BigStat(value: "670", label: "highest day", accent: true),
                BigStat(value: "~26.1", label: "avg / day"),
            ]),
            .divider("streaks"),
            .statGrid([
                BigStat(value: "23 days", label: "current streak", accent: true),
                BigStat(value: "47 days", label: "best streak"),
            ]),
        ])

    static func contributions(iso: Bool) -> Card {
        let heatmap = Heatmap(
            weeks: demoLevels(weeks: 53),
            monthLabels: demoMonthLabels(weeks: 53),
            weekdayLabels: !iso)
        return Card(
            id: "contributions", title: "Contributions", icon: .calendar,
            subtitle: "last 12 months",
            footer: "These metrics include private contributions — updated daily by GitHub Actions",
            span: 2,
            blocks: [iso ? .isometricHeatmap(heatmap) : .heatmap(heatmap)])
    }

    /// Order that shortest-column-first packs into the mockup's desktop layout:
    /// [activity, repos] left · [community, commits] right · contributions full-width.
    static let all = [activity, community, repositories, commits, contributions(iso: false)]
}

@Suite struct CardRendererTests {
    let theme = lightTheme

    @Test func heightFollowsTheDesignFormula() {
        // Activity: 20 + 24 + 12 + 6 dense rows (6*20) + 5 gaps (5*8) + 20 = 236.
        let height = CardRenderer.height(of: MockupCards.activity, theme: theme, width: 440)
        #expect(height == 236)
    }

    @Test func footerAddsTwentyEight() {
        var card = MockupCards.activity
        let plain = CardRenderer.height(of: card, theme: theme, width: 440)
        card.footer = "Updated daily"
        let withFooter = CardRenderer.height(of: card, theme: theme, width: 440)
        #expect(withFooter == plain + Metrics.footerGap + Metrics.footerHeight)
    }

    @Test func standaloneDocumentHasNamespaceAndViewBox() {
        let svg = CardRenderer.render(card: MockupCards.commits, theme: theme, width: 440)
        #expect(svg.contains(#"xmlns="http://www.w3.org/2000/svg""#))
        #expect(svg.contains(#"viewBox="0 0 440"#))
        // Nested (grid) variant carries x/y instead of xmlns.
        let nested = SVG(nodes: [CardRenderer.node(card: MockupCards.commits, theme: theme, width: 440, x: 460, y: 0)]).serialize()
        #expect(nested.contains(#"x="460""#))
    }

    @Test func iconSymbolsAreInlinedOncePerCard() {
        let svg = CardRenderer.render(card: MockupCards.community, theme: theme, width: 440)
        // `people` appears as the card icon and in a stat row — one symbol, two uses.
        #expect(svg.components(separatedBy: "symbol id=\"community-icon-people\"").count == 2)
        #expect(svg.components(separatedBy: "href=\"#community-icon-people\"").count == 3)
    }

    @Test(arguments: ["activity", "repositories", "community", "commits"])
    func cardGoldens(id: String) throws {
        let card = MockupCards.all.first { $0.id == id }!
        try assertGolden("card-\(id)", CardRenderer.render(card: card, theme: lightTheme, width: 440))
    }

    @Test func contributionsCardGoldens() throws {
        try assertGolden(
            "card-contributions",
            CardRenderer.render(card: MockupCards.contributions(iso: false), theme: lightTheme, width: 900))
        try assertGolden(
            "card-contributions-iso",
            CardRenderer.render(card: MockupCards.contributions(iso: true), theme: lightTheme, width: 900))
    }
}

@Suite struct GridRendererTests {
    let theme = lightTheme

    @Test func packsShortestColumnFirstAndSpansFullWidth() {
        let (placements, width, height) = GridRenderer.layout(
            cards: MockupCards.all, theme: theme, columns: 2)
        #expect(width == 900)
        let byId = Dictionary(uniqueKeysWithValues: placements.map { ($0.card.id, $0) })
        // Mockup layout: activity+repos left, community+commits right.
        #expect(byId["activity"]!.x == 0 && byId["activity"]!.y == 0)
        #expect(byId["community"]!.x == 460 && byId["community"]!.y == 0)
        #expect(byId["repositories"]!.x == 0)
        #expect(byId["commits"]!.x == 460)
        // Contributions spans both columns below everything.
        let contributions = byId["contributions"]!
        #expect(contributions.x == 0 && contributions.width == 900)
        #expect(contributions.y > byId["repositories"]!.y)
        #expect(height == contributions.y + contributions.height)
    }

    @Test func composedGridGolden() throws {
        try assertGolden(
            "grid-profile",
            GridRenderer.render(cards: MockupCards.all, theme: lightTheme, columns: 2))
    }

    @Test func everyThemeRendersWithoutCrashing() throws {
        for name in try ThemeLoader.availableThemes() {
            for variant in ThemeLoader.Variant.allCases {
                let theme = try ThemeLoader.load(name: name, variant: variant)
                let svg = GridRenderer.render(cards: MockupCards.all, theme: theme, columns: 2)
                #expect(svg.contains("<svg"))
            }
        }
    }

    @Test func markerThemeLayoutSurvivesBigRadiusAndBorder() throws {
        // Marker: 14px radius, 2px border — the layout-assumption canary.
        let marker = try ThemeLoader.load(name: "marker", variant: .light)
        try assertGolden(
            "grid-profile-marker",
            GridRenderer.render(cards: MockupCards.all, theme: marker, columns: 2))
    }
}
