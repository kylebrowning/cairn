# Cairn

Cairn renders your GitHub profile stats as static SVG cards for your profile
README — a Swift replacement for `lowlighter/metrics`. It runs as a GitHub
Action on a schedule, collects data from the GitHub API, and pushes rendered
cards to a branch. No headless browser, no HTML intermediate: SVG is produced
directly by Swift code.

Nine theme variants ship built in (`default`, `paper`, `terminal`, `ocean`,
`marker` — light and dark), rendered from a token-driven design system in
`design/`.

## Install (three steps)

**1. Add a config file** at `.github/profile.yml` in your profile repository
(the repo named after your username):

```yaml
theme: default
columns: 2
output:
  branch: metrics
  dir: .
plugins:
  - activity
  - community
  - repositories: { top: 6, ignore: [HTML, CSS] }
  - streaks: { timezone: America/Los_Angeles }
  - commits
  - calendar: { style: isometric, span: 2 }
```

**2. Add a workflow** at `.github/workflows/cairn.yml`:

```yaml
name: Profile cards
on:
  schedule:
    - cron: "17 5 * * *"
  workflow_dispatch:
jobs:
  cairn:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: kylebrowning/cairn@v1
```

**3. Add `<picture>` tags** to your profile `README.md`, pointing at the
output branch. Light and dark are separate renders switched by
`prefers-color-scheme`:

```html
<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="https://raw.githubusercontent.com/USER/USER/metrics/profile.dark.svg">
  <img alt="Profile stats"
       src="https://raw.githubusercontent.com/USER/USER/metrics/profile.light.svg">
</picture>

<sub>Generated with <a href="https://github.com/kylebrowning/cairn">Cairn</a></sub>
```

The attribution line is optional but appreciated — it's how other people
find Cairn.

Per-card SVGs (`activity.light.svg`, `calendar.dark.svg`, …) are published to
the same branch if you'd rather arrange cards yourself.

## Built-in plugins

| Plugin | Card | Options |
| --- | --- | --- |
| `activity` | Commit/PR/issue/review totals | `dense: true` |
| `repositories` | Repo counts + top languages | `top` (6), `ignore: [names]` |
| `community` | Followers, orgs, stars, watching | — |
| `streaks` | Current/best streak + weekly sparkline | `timezone` (UTC) |
| `commits` | Total, highest day, average per day | — |
| `calendar` | Contribution heatmap, full width | `style: flat\|isometric`, `weeks` (52), `span` (2) |
| `languages` | Standalone top-languages bar list | `top`, `ignore` |

Every plugin's card falls back to its last cached render (subtitle
"cached · as of …") when a run fails — a failing plugin never fails the job.

## CLI

The action just runs this CLI; you can too:

```
cairn collect  --login USER [--token-env GITHUB_TOKEN] [--config .github/profile.yml] --out snapshot.json
cairn render   --snapshot snapshot.json --config .github/profile.yml --out ./out
cairn run      --login USER            # collect then render, with cache fallback
cairn themes                           # list themes
cairn validate --config .github/profile.yml
```

`collect` and `render` communicate only through `snapshot.json`; render never
touches the network.

## Writing a plugin

External plugins are executables. Cairn writes JSON to stdin:

```json
{ "snapshot": { …the full snapshot… }, "options": { "weeks": 4 } }
```

and expects a `Card` as JSON on stdout within 20 seconds, exit status 0.
A card is a title plus a list of blocks from the fixed vocabulary — `stat`,
`statGrid`, `heatmap`, `isometricHeatmap`, `sparkline`, `barList`, `badgeRow`,
`text`, `divider`. Plugins never pick colors, fonts, or pixel positions; the
theme does. (The one exception: `barList` bars may carry GitHub language
colors.)

Configure it by path:

```yaml
plugins:
  - path: ./plugins/wakatime
    options: { weeks: 4 }
```

### A complete Swift example

Add `ProfileKit` as a dependency and adopt `ExternalPluginMain`:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "wakatime-plugin",
    dependencies: [
        .package(url: "https://github.com/kylebrowning/cairn.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "wakatime-plugin",
            dependencies: [.product(name: "ProfileKit", package: "cairn")])
    ]
)
```

```swift
import ProfileKit

@main
struct WakatimePlugin: ExternalPluginMain {
    static let id = "wakatime"

    init() {}

    func render(_ snapshot: Snapshot, options: PluginOptions) throws -> Card {
        let weeks = options.int("weeks", default: 4)
        // Read pre-collected data if your collect step stored any:
        let hours = snapshot.extra["wakatime"]?.objectValue?["hours"]?.doubleValue ?? 0
        return Card(
            id: Self.id,
            title: "Coding time",
            icon: .clock,
            subtitle: "last \(weeks) weeks",
            blocks: [
                .statGrid([
                    BigStat(value: "\(Int(hours))h", label: "total", accent: true)
                ]),
                .text("Tracked by WakaTime"),
            ])
    }
}
```

`ExternalPluginMain` supplies the `main()` that reads stdin, calls your
`render`, and writes the card to stdout. Build it, commit the binary or build
it in your workflow, and point `path:` at it.

## Development

```
swift test                                   # macOS or Linux
UPDATE_GOLDENS=1 swift test                  # regenerate golden SVGs
python3 scripts/generate-themes.py           # design/tokens/*.css → themes/*.yml
cairn render --snapshot Fixtures/snapshot.json --out ./out
```

The visual source of truth lives in `design/` — tokens, icons, the component
spec (`components.md`), and the mockups the golden files are checked against.
All layout constants in code trace back to `design/components.md` via
`Sources/Render/Metrics.swift`.
