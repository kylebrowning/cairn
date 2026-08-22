import ProfileKit

/// A block renderer is a pair of injectable closures — no protocol, because the
/// `Block` vocabulary is closed and tests want to stub either half.
public struct BlockRenderer: Sendable {
    /// Must be computable without rendering.
    public var height: @Sendable (Block, Double, Theme) -> Double
    public var render: @Sendable (Block, Point, Double, Theme) -> SVG

    public init(
        height: @escaping @Sendable (Block, Double, Theme) -> Double,
        render: @escaping @Sendable (Block, Point, Double, Theme) -> SVG
    ) {
        self.height = height
        self.render = render
    }
}

extension Theme {
    var family: TextMeasure.Family { TextMeasure.Family(stack: font.stack) }

    func style(size: Double, weight: Int = 400) -> TextMeasure.Style {
        TextMeasure.Style(size: size, weight: weight, family: family)
    }
}

/// Wraps a fragment in a translate group when the origin is not zero.
private func at(_ origin: Point, _ nodes: [SVGNode]) -> SVG {
    if origin == .zero {
        return SVG(nodes: nodes)
    }
    return SVG(nodes: [Group(transform: "translate(\(num(origin.x)) \(num(origin.y)))") { nodes }])
}

public enum BlockRenderers {
    public static func renderer(for block: Block) -> BlockRenderer {
        switch block {
        case .stat: return stat
        case .statGrid: return statGrid
        case .heatmap: return heatmap
        case .isometricHeatmap: return isometricHeatmap
        case .sparkline: return sparkline
        case .barList: return barList
        case .badgeRow: return badgeRow
        case .text: return text
        case .divider: return divider
        }
    }

    public static func height(of block: Block, width: Double, theme: Theme) -> Double {
        renderer(for: block).height(block, width, theme)
    }

    public static func render(_ block: Block, at origin: Point, width: Double, theme: Theme) -> SVG {
        renderer(for: block).render(block, origin, width, theme)
    }

    /// Icons referenced by a block (inlined once per file as `<symbol>`).
    public static func icons(in block: Block) -> [Icon] {
        if case .stat(let stat) = block { return [stat.icon] }
        return []
    }

    // MARK: Stat row — design/components.md "StatRow"

    public static let stat = BlockRenderer { block, _, _ in
        guard case .stat(let payload) = block else { return 0 }
        return payload.dense ? Metrics.statRowDenseHeight : Metrics.statRowHeight
    } render: { block, origin, width, theme in
        guard case .stat(let payload) = block else { return .empty }
        let rowHeight = payload.dense ? Metrics.statRowDenseHeight : Metrics.statRowHeight
        let center = rowHeight / 2
        let baseline = center + TextMeasure.baselineOffset(size: theme.font.sizeBase)
        let labelX = Metrics.statIconSize + Metrics.statGap
        let valueStyle = theme.style(size: theme.font.sizeBase, weight: 600)
        let valueWidth = TextMeasure.width(of: payload.value, style: valueStyle)
        let labelRoom = width - labelX - valueWidth - Metrics.statGap
        let label = TextMeasure.truncate(payload.label, toFit: labelRoom, style: theme.style(size: theme.font.sizeBase))
        return at(origin, [
            Use(
                href: "#icon-\(payload.icon.rawValue)",
                x: 0, y: center - Metrics.statIconSize / 2,
                width: Metrics.statIconSize, height: Metrics.statIconSize,
                fill: theme.text.muted
            ),
            Text(
                label, x: labelX, y: baseline,
                fontSize: theme.font.sizeBase, fontFamily: theme.font.stack,
                fill: theme.text.primary
            ),
            Text(
                payload.value, x: width, y: baseline,
                fontSize: theme.font.sizeBase, fontFamily: theme.font.stack,
                fontWeight: 600, fill: theme.text.primary, anchor: .end
            ),
        ])
    }

    // MARK: Stat grid — 48px: 24px/700 value (28px line) + 4px + 11px label

    public static let statGrid = BlockRenderer { _, _, _ in
        Metrics.statGridHeight
    } render: { block, origin, width, theme in
        guard case .statGrid(let items) = block, !items.isEmpty else { return .empty }
        let n = Double(items.count)
        let columnWidth = (width - Metrics.statGridColumnGap * (n - 1)) / n
        let valueBaseline = Metrics.bigValueLineHeight / 2
            + TextMeasure.baselineOffset(size: Metrics.bigValueSize)
        let labelBaseline = Metrics.bigValueLineHeight + Metrics.bigLabelGap
            + theme.font.sizeSmall / 2 + 2
            + TextMeasure.baselineOffset(size: theme.font.sizeSmall)
        var nodes: [SVGNode] = []
        for (i, item) in items.enumerated() {
            let centerX = Double(i) * (columnWidth + Metrics.statGridColumnGap) + columnWidth / 2
            nodes.append(Text(
                item.value, x: centerX, y: valueBaseline,
                fontSize: Metrics.bigValueSize, fontFamily: theme.font.stack,
                fontWeight: Metrics.bigValueWeight,
                fill: item.accent ? theme.text.accent : theme.text.primary,
                anchor: .middle
            ))
            let label = TextMeasure.truncate(
                item.label, toFit: columnWidth,
                style: theme.style(size: theme.font.sizeSmall))
            nodes.append(Text(
                label, x: centerX, y: labelBaseline,
                fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                fill: theme.text.muted, anchor: .middle
            ))
        }
        return at(origin, nodes)
    }

    // MARK: Divider — 16px, 1px rule in --card-border, optional centered label

    public static let divider = BlockRenderer { _, _, _ in
        Metrics.dividerHeight
    } render: { block, origin, width, theme in
        guard case .divider(let label) = block else { return .empty }
        let y = Metrics.dividerHeight / 2
        guard let label, !label.isEmpty else {
            return at(origin, [
                Rect(x: 0, y: y - theme.card.borderWidth / 2, width: width,
                     height: theme.card.borderWidth, fill: theme.card.border)
            ])
        }
        let style = theme.style(size: theme.font.sizeSmall)
        let labelWidth = TextMeasure.width(of: label, style: style)
        let ruleWidth = (width - labelWidth) / 2 - Metrics.dividerLabelGap
        let ruleY = y - theme.card.borderWidth / 2
        return at(origin, [
            Rect(x: 0, y: ruleY, width: max(ruleWidth, 0), height: theme.card.borderWidth,
                 fill: theme.card.border),
            Text(
                label, x: width / 2, y: y + TextMeasure.baselineOffset(size: theme.font.sizeSmall),
                fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                fill: theme.text.muted, anchor: .middle
            ),
            Rect(x: width - max(ruleWidth, 0), y: ruleY, width: max(ruleWidth, 0),
                 height: theme.card.borderWidth, fill: theme.card.border),
        ])
    }

    // MARK: Text block — 18px per line

    public static let text = BlockRenderer { block, width, theme in
        guard case .text(let content) = block else { return 0 }
        let lines = TextMeasure.wrap(content, toFit: width, style: theme.style(size: theme.font.sizeBase))
        return Double(lines.count) * Metrics.textLineHeight
    } render: { block, origin, width, theme in
        guard case .text(let content) = block else { return .empty }
        let style = theme.style(size: theme.font.sizeBase)
        let lines = TextMeasure.wrap(content, toFit: width, style: style)
        let nodes = lines.enumerated().map { i, line in
            Text(
                line,
                x: 0,
                y: Double(i) * Metrics.textLineHeight + Metrics.textLineHeight / 2
                    + TextMeasure.baselineOffset(size: theme.font.sizeBase),
                fontSize: theme.font.sizeBase, fontFamily: theme.font.stack,
                fill: theme.text.primary
            )
        }
        return at(origin, nodes)
    }

    // MARK: Badge row — 20px pills, 6px gaps, wraps at 26px pitch

    static func badgeLayout(_ badges: [Badge], width: Double, theme: Theme)
        -> [(badge: Badge, x: Double, y: Double, width: Double)]
    {
        let style = theme.style(size: theme.font.sizeSmall)
        var placed: [(Badge, Double, Double, Double)] = []
        var x = 0.0
        var y = 0.0
        for badge in badges {
            let pillWidth = TextMeasure.width(of: badge.text, style: style) + Metrics.badgeSidePadding * 2
            if x > 0 && x + pillWidth > width {
                x = 0
                y += Metrics.badgeLinePitch
            }
            placed.append((badge, x, y, pillWidth))
            x += pillWidth + Metrics.badgeGap
        }
        return placed
    }

    public static let badgeRow = BlockRenderer { block, width, theme in
        guard case .badgeRow(let badges) = block, !badges.isEmpty else { return 0 }
        let last = badgeLayout(badges, width: width, theme: theme).last!
        return last.y + Metrics.badgeHeight
    } render: { block, origin, width, theme in
        guard case .badgeRow(let badges) = block else { return .empty }
        var nodes: [SVGNode] = []
        for pill in badgeLayout(badges, width: width, theme: theme) {
            nodes.append(Rect(
                x: pill.x, y: pill.y, width: pill.width, height: Metrics.badgeHeight,
                rx: Metrics.badgeRadius, fill: theme.badge.bg
            ))
            nodes.append(Text(
                pill.badge.text,
                x: pill.x + pill.width / 2,
                y: pill.y + Metrics.badgeHeight / 2 + TextMeasure.baselineOffset(size: theme.font.sizeSmall),
                fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                fill: theme.badge.text, anchor: .middle
            ))
        }
        return at(origin, nodes)
    }

    // MARK: Sparkline — 40px, 1.5px stroke, area fill, end dot r2.5 + label

    public static let sparkline = BlockRenderer { _, _, _ in
        Metrics.sparklineHeight
    } render: { block, origin, width, theme in
        guard case .sparkline(let payload) = block, payload.values.count >= 2 else { return .empty }
        let values = payload.values
        let height = Metrics.sparklineHeight
        let maxV = max(values.max() ?? 1, 1)
        let minV = min(values.min() ?? 0, 0)
        let labelRoom = payload.label != nil ? Metrics.sparkLabelWidth : 0
        let chartWidth = width - labelRoom - Metrics.sparkDotInset
        let px = { (i: Int) -> Double in
            2 + Double(i) / Double(values.count - 1) * (chartWidth - 4)
        }
        let py = { (v: Double) -> Double in
            3 + (1 - (v - minV) / max(maxV - minV, 1)) * (height - 8)
        }
        let points = values.enumerated().map { i, v in "\(num(px(i))),\(num(py(v)))" }
        let area = "M\(num(px(0))),\(num(height - 2)) "
            + points.map { "L\($0)" }.joined(separator: " ")
            + " L\(num(px(values.count - 1))),\(num(height - 2)) Z"
        let line = "M" + points.joined(separator: " L")
        let endX = px(values.count - 1)
        let endY = py(values[values.count - 1])
        var nodes: [SVGNode] = [
            Path(d: area, fill: theme.spark.fill),
            Path(d: line, fill: "none", stroke: theme.spark.stroke,
                 strokeWidth: Metrics.sparkStrokeWidth,
                 strokeLinejoin: "round", strokeLinecap: "round"),
            Circle(cx: endX, cy: endY, r: Metrics.sparkDotRadius, fill: theme.spark.stroke),
        ]
        if let label = payload.label {
            nodes.append(Text(
                label, x: endX + 8, y: endY + 4,
                fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                fontWeight: 600, fill: theme.text.primary
            ))
        }
        return at(origin, nodes)
    }

    // MARK: Bar list — 20px rows, 110px label, 8px track, right value

    public static let barList = BlockRenderer { block, _, _ in
        guard case .barList(let bars) = block else { return 0 }
        return Double(bars.count) * Metrics.barRowHeight
    } render: { block, origin, width, theme in
        guard case .barList(let bars) = block, !bars.isEmpty else { return .empty }
        let maxRaw = max(bars.map(\.raw).max() ?? 1, 1)
        let trackX = Metrics.barLabelWidth + Metrics.barGap
        let trackWidth = width - trackX - Metrics.barValueWidth - Metrics.barGap
        var nodes: [SVGNode] = []
        for (i, bar) in bars.enumerated() {
            let rowY = Double(i) * Metrics.barRowHeight
            let baseline = rowY + Metrics.barRowHeight / 2
            let label = TextMeasure.truncate(
                bar.label, toFit: Metrics.barLabelWidth,
                style: theme.style(size: theme.font.sizeBase))
            nodes.append(Text(
                label, x: 0, y: baseline + TextMeasure.baselineOffset(size: theme.font.sizeBase),
                fontSize: theme.font.sizeBase, fontFamily: theme.font.stack,
                fill: theme.text.primary
            ))
            let trackY = rowY + (Metrics.barRowHeight - Metrics.barTrackHeight) / 2
            nodes.append(Rect(
                x: trackX, y: trackY, width: trackWidth, height: Metrics.barTrackHeight,
                rx: Metrics.barTrackRadius, fill: theme.bar.track
            ))
            let fillWidth = bar.raw / maxRaw * trackWidth
            if fillWidth > 0 {
                nodes.append(Rect(
                    x: trackX, y: trackY, width: fillWidth, height: Metrics.barTrackHeight,
                    rx: Metrics.barTrackRadius, fill: bar.color ?? theme.bar.fill
                ))
            }
            nodes.append(Text(
                bar.value, x: width,
                y: baseline + TextMeasure.baselineOffset(size: theme.font.sizeSmall),
                fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                fill: theme.text.muted, anchor: .end
            ))
        }
        return at(origin, nodes)
    }

    // MARK: Heatmap — flat contributions calendar

    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// Drops the OLDEST weeks when width-constrained (per the design).
    static func fittedWeeks(_ weeks: [[Int]], width: Double, gutter: Double) -> [[Int]] {
        let maxWeeks = Int((width - gutter + Metrics.heatGap) / Metrics.heatPitch)
        guard weeks.count > maxWeeks else { return weeks }
        return Array(weeks.suffix(max(maxWeeks, 0)))
    }

    public static let heatmap = BlockRenderer { _, _, _ in
        Metrics.heatMonthBand + Double(Metrics.heatRows) * Metrics.heatPitch - Metrics.heatGap
    } render: { block, origin, width, theme in
        guard case .heatmap(let payload) = block else { return .empty }
        let gutter = payload.weekdayLabels ? Metrics.heatWeekdayGutter : 0
        let weeks = fittedWeeks(payload.weeks, width: width, gutter: gutter)
        let droppedWeeks = payload.weeks.count - weeks.count
        let top = Metrics.heatMonthBand
        let pitch = Metrics.heatPitch
        var nodes: [SVGNode] = []
        // Month labels along the top, one at the first week of each month.
        for label in payload.monthLabels {
            let week = label.week - droppedWeeks
            // Skip labels for dropped weeks and ones too close to the right
            // edge to fit the 3-character text.
            guard week >= 0, Double(week) * pitch + 24 <= Double(weeks.count) * pitch else { continue }
            nodes.append(Text(
                monthNames[((label.month % 12) + 12) % 12],
                x: gutter + Double(week) * pitch, y: 12,
                fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                fill: theme.text.muted
            ))
        }
        if payload.weekdayLabels {
            for (row, day) in [(1, "Mon"), (3, "Wed"), (5, "Fri")] {
                nodes.append(Text(
                    day, x: 0, y: top + Double(row) * pitch + Metrics.heatCell - 2,
                    fontSize: theme.font.sizeSmall, fontFamily: theme.font.stack,
                    fill: theme.text.muted
                ))
            }
        }
        for (week, levels) in weeks.enumerated() {
            for (day, level) in levels.enumerated() where day < Metrics.heatRows {
                nodes.append(Rect(
                    x: gutter + Double(week) * pitch,
                    y: top + Double(day) * pitch,
                    width: Metrics.heatCell, height: Metrics.heatCell,
                    rx: Metrics.heatCellRadius,
                    fill: theme.heatmap.scale[max(0, min(level, 4))]
                ))
            }
        }
        return at(origin, nodes)
    }

    // MARK: Isometric heatmap — 2:1 dimetric, painted back-to-front

    static func isoColumns(width: Double) -> Int {
        Int(width / (Metrics.isoPitch / 2)) - Metrics.heatRows
    }

    public static let isometricHeatmap = BlockRenderer { block, width, _ in
        guard case .isometricHeatmap(let payload) = block else { return 0 }
        let cols = min(payload.weeks.count, isoColumns(width: width))
        let hh = Metrics.isoPitch / 4
        return Double(cols + Metrics.heatRows) * hh + Metrics.isoMaxBar + 2
    } render: { block, origin, width, theme in
        guard case .isometricHeatmap(let payload) = block else { return .empty }
        let weeks = payload.weeks.suffix(isoColumns(width: width))
        let data = Array(weeks)
        let cols = data.count
        let rows = Metrics.heatRows
        let hw = Metrics.isoPitch / 2
        let hh = Metrics.isoPitch / 4
        let drawnWidth = Double(cols + rows) * hw
        // Center the projection in the block.
        let ox = Double(rows) * hw + (width - drawnWidth) / 2
        var nodes: [SVGNode] = []
        for s in 0...(cols + rows - 2) {
            for c in 0..<cols {
                let r = s - c
                guard r >= 0, r < rows, r < data[c].count else { continue }
                let level = max(0, min(data[c][r], 4))
                let fill = theme.heatmap.scale[level]
                let barHeight = Metrics.isoMinBar
                    + Double(level) / 4 * (Metrics.isoMaxBar - Metrics.isoMinBar)
                let x = ox + Double(c - r) * hw
                let y = Metrics.isoMaxBar + Double(c + r) * hh
                // Diamond top at (x, y - barHeight): points N, E, S, W.
                let n = "\(num(x)),\(num(y - barHeight))"
                let e = "\(num(x + hw)),\(num(y - barHeight + hh))"
                let so = "\(num(x)),\(num(y - barHeight + 2 * hh))"
                let w = "\(num(x - hw)),\(num(y - barHeight + hh))"
                let leftFace = "M\(w) L\(so) L\(num(x)),\(num(y + 2 * hh)) L\(num(x - hw)),\(num(y + hh)) Z"
                let rightFace = "M\(so) L\(e) L\(num(x + hw)),\(num(y + hh)) L\(num(x)),\(num(y + 2 * hh)) Z"
                let topFace = "M\(n) L\(e) L\(so) L\(w) Z"
                nodes.append(Path(d: leftFace, fill: fill, fillOpacity: Metrics.isoLeftFaceOpacity))
                nodes.append(Path(d: rightFace, fill: fill, fillOpacity: Metrics.isoRightFaceOpacity))
                nodes.append(Path(d: topFace, fill: fill))
            }
        }
        return at(origin, nodes)
    }
}
