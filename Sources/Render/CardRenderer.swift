import ProfileKit

/// Renders one card. The same node is used standalone (with xmlns) and nested
/// inside the grid (with x/y), so both outputs share one code path.
public enum CardRenderer {
    /// Total card height: padding + title row + 12 + blocks with 8px gaps
    /// (+ 12 + footer) + padding. See design/components.md "Layout grid".
    public static func height(of card: Card, theme: Theme, width: Double) -> Double {
        let contentWidth = width - theme.card.padding * 2
        var h = theme.card.padding + Metrics.titleRowHeight + Metrics.titleBodyGap
        for (i, block) in card.blocks.enumerated() {
            if i > 0 { h += Metrics.blockGap }
            h += BlockRenderers.height(of: block, width: contentWidth, theme: theme)
        }
        if card.footer != nil {
            h += Metrics.footerGap + Metrics.footerHeight
        }
        return h + theme.card.padding
    }

    /// Icons this card references, deduplicated in first-use order.
    static func icons(of card: Card) -> [Icon] {
        var seen: Set<Icon> = []
        var result: [Icon] = []
        for icon in (card.icon.map { [$0] } ?? []) + card.blocks.flatMap(BlockRenderers.icons(in:)) {
            if seen.insert(icon).inserted {
                result.append(icon)
            }
        }
        return result
    }

    /// The card as an `<svg>` element. Pass x/y when nesting into the grid.
    public static func node(
        card: Card, theme: Theme, width: Double,
        x: Double? = nil, y: Double? = nil
    ) -> SVGNode {
        let totalHeight = height(of: card, theme: theme, width: width)
        let pad = theme.card.padding
        let contentWidth = width - pad * 2
        let bw = theme.card.borderWidth

        return Svg(x: x, y: y, width: width, height: totalHeight,
                   viewBox: "0 0 \(num(width)) \(num(totalHeight))") {
            let cardIcons = icons(of: card)
            if !cardIcons.isEmpty {
                Defs {
                    for icon in cardIcons {
                        // Ids are prefixed per card so composed documents stay unique.
                        Symbol(id: "\(card.id)-icon-\(icon.rawValue)", viewBox: "0 0 16 16",
                               rawContent: iconPaths[icon.rawValue] ?? "")
                    }
                }
            }

            // Container: stroke straddles the rect edge, so inset by half the
            // border to keep the painted box exactly `width` wide.
            Rect(x: bw / 2, y: bw / 2, width: width - bw, height: totalHeight - bw,
                 rx: theme.card.radius, fill: theme.card.bg,
                 stroke: theme.card.border, strokeWidth: bw)

            header(card: card, theme: theme, contentWidth: contentWidth)

            blocks(card: card, theme: theme, contentWidth: contentWidth)

            if let footer = card.footer {
                let footerTop = totalHeight - pad - Metrics.footerHeight
                let style = theme.style(size: theme.font.sizeSmall)
                Text(
                    TextMeasure.truncate(footer, toFit: contentWidth, style: style),
                    x: pad,
                    y: footerTop + Metrics.footerHeight / 2
                        + TextMeasure.baselineOffset(size: theme.font.sizeSmall),
                    fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                    fill: theme.text.muted
                )
            }
        }
    }

    @SVGBuilder
    private static func header(card: Card, theme: Theme, contentWidth: Double) -> [SVGNode] {
        let pad = theme.card.padding
        let rowCenter = pad + Metrics.titleRowHeight / 2
        let titleBaseline = rowCenter + TextMeasure.baselineOffset(size: theme.font.sizeTitle)
        var titleX = pad
        if let icon = card.icon {
            Use(
                href: "#\(card.id)-icon-\(icon.rawValue)",
                x: pad, y: rowCenter - Metrics.titleIconSize / 2,
                width: Metrics.titleIconSize, height: Metrics.titleIconSize,
                fill: theme.text.muted
            )
            let _ = titleX += Metrics.titleIconSize + Metrics.titleIconGap
        }
        let subtitleWidth = card.subtitle.map {
            TextMeasure.width(of: $0, style: theme.style(size: theme.font.sizeSmall)) + Metrics.titleIconGap
        } ?? 0
        let titleRoom = pad + contentWidth - titleX - subtitleWidth
        Text(
            TextMeasure.truncate(card.title, toFit: titleRoom,
                                 style: theme.style(size: theme.font.sizeTitle, weight: 600)),
            x: titleX, y: titleBaseline,
            fontSize: theme.font.sizeTitle, fontFamily: theme.font.stack,
            fontWeight: 600, fill: theme.text.primary
        )
        if let subtitle = card.subtitle {
            Text(
                subtitle, x: pad + contentWidth,
                y: rowCenter + TextMeasure.baselineOffset(size: theme.font.sizeSmall),
                fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                fill: theme.text.muted, anchor: .end
            )
        }
    }

    @SVGBuilder
    private static func blocks(card: Card, theme: Theme, contentWidth: Double) -> [SVGNode] {
        let pad = theme.card.padding
        var cursor = pad + Metrics.titleRowHeight + Metrics.titleBodyGap
        for (i, block) in card.blocks.enumerated() {
            if i > 0 { let _ = cursor += Metrics.blockGap }
            // Ids inside blocks reference the card-prefixed symbols.
            prefixUses(
                BlockRenderers.render(block, at: Point(pad, cursor), width: contentWidth, theme: theme).nodes,
                cardId: card.id
            )
            let _ = cursor += BlockRenderers.height(of: block, width: contentWidth, theme: theme)
        }
    }

    /// Rewrites `#icon-*` references to this card's prefixed symbol ids.
    private static func prefixUses(_ nodes: [SVGNode], cardId: String) -> [SVGNode] {
        nodes.map { node in
            switch node {
            case .element(let name, let attributes, let children):
                let fixed = attributes.map { key, value in
                    key == "href" && value.hasPrefix("#icon-")
                        ? (key, "#\(cardId)-icon-" + value.dropFirst("#icon-".count))
                        : (key, value)
                }
                return .element(name: name, attributes: fixed, children: prefixUses(children, cardId: cardId))
            default:
                return node
            }
        }
    }

    /// Standalone SVG document for one card.
    public static func render(card: Card, theme: Theme, width: Double) -> String {
        SVG(nodes: [node(card: card, theme: theme, width: width)]).serialize()
    }
}
