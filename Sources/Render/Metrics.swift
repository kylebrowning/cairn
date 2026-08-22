/// Every size and spacing rule, transcribed from `design/components.md`.
/// Change the design doc first, then this file — never scatter magic numbers.
public enum Metrics {
    // MARK: Layout grid
    /// Two-column card width at the ~900px README width.
    public static let columnCardWidth: Double = 440
    /// Column gutter between cards.
    public static let gutter: Double = 20
    /// Composed grid width for 2 columns: 440 + 20 + 440.
    public static let fullWidth: Double = columnCardWidth * 2 + gutter

    // MARK: Card
    public static let titleRowHeight: Double = 24
    public static let titleIconSize: Double = 16
    public static let titleIconGap: Double = 8
    /// Gap between title row and the first block.
    public static let titleBodyGap: Double = 12
    /// Blocks stack at this gap.
    public static let blockGap: Double = 8
    /// Footer: 11px muted line, 12px above.
    public static let footerGap: Double = 12
    public static let footerHeight: Double = 16

    // MARK: StatRow
    public static let statRowHeight: Double = 24
    public static let statRowDenseHeight: Double = 20
    public static let statIconSize: Double = 16
    /// Gap icon→label and label→value.
    public static let statGap: Double = 10

    // MARK: StatGrid — 48px = 24px/700 value (28px line) + 4px + 11px label.
    public static let statGridHeight: Double = 48
    public static let bigValueSize: Double = 24
    public static let bigValueLineHeight: Double = 28
    public static let bigValueWeight = 700
    public static let bigLabelGap: Double = 4
    public static let statGridColumnGap: Double = 12

    // MARK: Divider
    public static let dividerHeight: Double = 16
    public static let dividerLabelGap: Double = 10

    // MARK: TextBlock
    public static let textLineHeight: Double = 18

    // MARK: BadgeRow — 20px pills, wraps at 26px line pitch.
    public static let badgeHeight: Double = 20
    public static let badgeSidePadding: Double = 8
    public static let badgeRadius: Double = 10
    public static let badgeGap: Double = 6
    public static let badgeLinePitch: Double = 26

    // MARK: Sparkline
    public static let sparklineHeight: Double = 40
    public static let sparkStrokeWidth: Double = 1.5
    public static let sparkDotRadius: Double = 2.5
    /// Space reserved for the end value label.
    public static let sparkLabelWidth: Double = 44
    public static let sparkDotInset: Double = 4

    // MARK: BarList — 20px rows.
    public static let barRowHeight: Double = 20
    public static let barLabelWidth: Double = 110
    public static let barTrackHeight: Double = 8
    public static let barTrackRadius: Double = 4
    public static let barValueWidth: Double = 52
    public static let barGap: Double = 10

    // MARK: Heatmap — 11px cell, 3px gap (14px pitch), rx 2.
    public static let heatCell: Double = 11
    public static let heatGap: Double = 3
    public static let heatPitch: Double = heatCell + heatGap
    public static let heatCellRadius: Double = 2
    public static let heatRows = 7
    /// Month label band above the cells.
    public static let heatMonthBand: Double = 20
    /// Mon/Wed/Fri gutter on the left (flat variant only).
    public static let heatWeekdayGutter: Double = 28

    // MARK: IsoHeatmap — 2:1 dimetric, tile pitch 14 → tile 14w x 7h on screen.
    public static let isoPitch: Double = 14
    public static let isoMaxBar: Double = 40
    public static let isoMinBar: Double = 3
    public static let isoRightFaceOpacity: Double = 0.72
    public static let isoLeftFaceOpacity: Double = 0.5
}
