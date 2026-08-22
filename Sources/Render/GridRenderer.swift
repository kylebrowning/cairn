import ProfileKit

/// Lays cards into columns by span (shortest column first) and composes one
/// SVG. Cards are embedded as nested `<svg x y>` from CardRenderer, so the
/// per-card and composed outputs come from the same code path.
public enum GridRenderer {
    public struct Placement: Sendable {
        public var card: Card
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
    }

    static func layout(cards: [Card], theme: Theme, columns: Int) -> (placements: [Placement], width: Double, height: Double) {
        let columnCount = max(columns, 1)
        let columnWidth = Metrics.columnCardWidth
        let totalWidth = Double(columnCount) * columnWidth + Double(columnCount - 1) * Metrics.gutter
        var columnBottoms = [Double](repeating: 0, count: columnCount)
        var placements: [Placement] = []

        for card in cards {
            let span = max(1, min(card.span, columnCount))
            let width = Double(span) * columnWidth + Double(span - 1) * Metrics.gutter
            let height = CardRenderer.height(of: card, theme: theme, width: width)
            // Shortest run of `span` adjacent columns.
            var bestStart = 0
            var bestTop = Double.infinity
            for start in 0...(columnCount - span) {
                let top = columnBottoms[start..<(start + span)].max() ?? 0
                if top < bestTop {
                    bestTop = top
                    bestStart = start
                }
            }
            let y = bestTop == 0 ? 0 : bestTop + Metrics.gutter
            let x = Double(bestStart) * (columnWidth + Metrics.gutter)
            placements.append(Placement(card: card, x: x, y: y, width: width, height: height))
            for column in bestStart..<(bestStart + span) {
                columnBottoms[column] = y + height
            }
        }
        return (placements, totalWidth, columnBottoms.max() ?? 0)
    }

    public static func render(cards: [Card], theme: Theme, columns: Int = 2) -> String {
        let (placements, width, height) = layout(cards: cards, theme: theme, columns: columns)
        let doc = Svg(width: width, height: height, viewBox: "0 0 \(num(width)) \(num(height))") {
            for placement in placements {
                CardRenderer.node(
                    card: placement.card, theme: theme, width: placement.width,
                    x: placement.x, y: placement.y)
            }
        }
        return SVG(nodes: [doc]).serialize()
    }
}
