# Profile Cards Design System

Visual system for a `lowlighter/metrics` replacement: a GitHub Action (built in Swift) that renders static SVG stat cards embedded in profile READMEs. This design system is the source of truth an engineer translates into SVG templates — every size, spacing rule, and color is written down; nothing should need guessing.

## Hard constraints (from the brief)
- Static SVG only: no hover, animation, JS, or external resources. System font stacks only.
- Each card is a standalone SVG; light and dark are separate renders switched by `<picture>` + `prefers-color-scheme`. Cards must sit well on both `#ffffff` and `#0d1117`.
- Text never reflows: positions are computed at render time; long names truncate with ellipsis at a known width.
- No drop shadows, no text below 11px, no gradients needing >2 token colors, no non-token color except GitHub language colors in the bar list.

## Layout grid
- Card widths: **440px** (two-column README at ~900px), **880px** full-width, **360px** single-column mobile. Column gutter 20px.
- Card height = padding + title row (24) + 12 + sum of blocks + 8px gaps (+ 12 + footer 16 if present).

## Component spec (block heights)
- **Card**: title row 24px — 16px leading icon, 8px gap, 14px/600 title, right-aligned 11px muted subtitle (also the degraded-state slot: "cached · as of Aug 20"); 12px gap to body; footer 11px muted, 12px above.
- **StatRow**: 24px; dense 20px (use dense for stacks of 8+). Icon 16px in `--text-muted`, 10px gap, label ellipsizes, value 600 right-aligned.
- **StatGrid**: 48px = 24px/700 value + 4px + 11px muted label; equal columns, centered.
- **Heatmap**: 11px cell, 3px gap (14px pitch), rx 2, 7 rows = 95px; +20px month band; optional 28px weekday gutter. 53 weeks = 739px (fits 880 card); drop the OLDEST weeks when width-constrained (23 weeks at 360).
- **IsoHeatmap**: 2:1 dimetric; tile pitch 14 (tile 14x7 on screen); bar 3-40px by level; faces = heat token at fill-opacity 1 (top) / .72 (right) / .5 (left) — shading needs no extra tokens; painted back-to-front by (col+row).
- **Sparkline**: 40px tall, 1.5px stroke, `--spark-fill` area, end dot r2.5, 11px/600 value label.
- **BarList**: 20px rows; 110px label column, 8px track (radius 4), right 11px muted value. Bar color = `--bar-fill` unless it's a language (GitHub palette).
- **BadgeRow**: 20px pills, 11px text, 8px side padding, radius 10, 6px gaps, wraps at 26px pitch.
- **TextBlock**: 18px per line. **Divider**: 16px, 1px rule in `--card-border`, optional centered 11px label.

## Theme tokens
23 tokens per theme (CSS custom properties in `tokens/*.css`, scoped by `data-theme`): font stack + 3 sizes; card bg/border/border-width/radius/padding; primary/muted/accent; heat-0..4; spark stroke/fill; bar track/fill; badge bg/text.

Themes: **Default** (light `:root` / `default-dark`) — GitHub-adjacent greens, not a clone; **Paper** (`paper`, `paper-dark`) — warm off-white, ink, serif system stack, terracotta accent; **Terminal** (`terminal`, dark only) — mono stack, phosphor green, hairlines, radius 0; **Ocean** (`ocean`, `ocean-dark`) — hue-only retheme proving the scale swaps cleanly; **Marker** (`marker`, `marker-dark`) — the mood-shift proof: 14px radius, 2px ink border, hot coral scale, inverted badge pills, zero block special-cases.

## Content fundamentals
Copy is developer-facing telemetry, not marketing. Sentence case everywhere; no exclamation points, no emoji, no first person. Labels are terse nouns ("Commits", "PRs opened", "Contributed to"); values are formatted numbers with thousands separators ("13,100") or compact ("13.1k") in stat grids. Timestamps read "as of Aug 22". Degraded states stay matter-of-fact: subtitle "cached · as of Aug 20", footer "Live fetch failed — showing last good data" — informative, never alarming. Footers are one muted line ("Updated daily by GitHub Actions").

## Visual foundations
- **Color**: everything from theme tokens; one accent per theme, used sparingly (a highlighted stat, sparkline). The 5-step heat ramp is the signature element. Language colors are the sole non-token exception.
- **Type**: system stacks only (sans default, serif for Paper, mono for Terminal). Scale 24/14/12/11; 11px is the hard floor. Semibold for values and titles; never rely on a specific font's metrics for alignment.
- **Backgrounds**: flat `--card-bg` fills; no images, textures, patterns, or gradients (SVG viewer inconsistency); no shadows — depth comes from the border + bg contrast against GitHub's chrome.
- **Borders & radius**: token-driven; 1px default, hairline feel; radius 0-14 is the main mood dial across themes.
- **Spacing**: card padding 18-22 (token); blocks stack at 8px; title-to-body 12px; column gutter 20px.
- **Animation/hover/press**: none — static SVG by constraint.
- **Density**: quiet and scannable at a glance; muted labels, strong values, generous line pitch.

## Iconography
36 icons at 16px in `icons/`, taken directly from **Octicons** (primer/octicons, MIT) so cards feel native to GitHub. Filled/outline Octicon style, single color, always rendered in `--text-muted` (or `currentColor`). No emoji, no unicode glyph icons. Substitutions: "music" uses Octicon `unmute`, "sparkle" uses `sparkle-fill` (Octicons has no literal music/sparkle-outline glyph). Extras beyond the brief's 30: merge, history, rocket, verified, zap.

## Mockup reference
`mockups/GitHub Profile.html` (plus `_ds_bundle.js`, `styles.css`) — interactive mockup: two-column profile (Activity, Repositories, Community, Streaks, Commits, Contributions) with theme switcher, mobile 360 stack, isometric-heatmap swap, and degraded-card state. The React components approximate the SVG output with HTML/SVG hybrids; the block heights above, not the DOM, are the engineering contract.

## Caveats
- Paper's serif is plain `Georgia, serif` — a universal system font; no font files exist or should be uploaded (embedded fonts are forbidden by the SVG constraint).
