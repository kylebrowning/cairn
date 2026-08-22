import Foundation
import ProfileKit
import Testing

@testable import Plugins

func day(_ date: String, _ count: Int) -> ContributionDay {
    ContributionDay(date: date, count: count, level: count == 0 ? 0 : min(4, count))
}

func instant(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
}

let utc = TimeZone(identifier: "UTC")!

@Suite struct StreakTests {
    @Test func emptyCalendarHasNoStreaks() {
        let streaks = CalendarMath.streaks(days: [], now: instant("2026-08-22T12:00:00Z"), timezone: utc)
        #expect(streaks == CalendarMath.Streaks(current: 0, best: 0))
    }

    @Test func noCommitsTodayButYesterdayContinuesTheStreak() {
        let days = [
            day("2026-08-19", 2), day("2026-08-20", 1), day("2026-08-21", 3),
            day("2026-08-22", 0),
        ]
        let streaks = CalendarMath.streaks(days: days, now: instant("2026-08-22T12:00:00Z"), timezone: utc)
        #expect(streaks.current == 3)
        #expect(streaks.best == 3)
    }

    @Test func commitsTodayCountToward() {
        let days = [day("2026-08-21", 1), day("2026-08-22", 5)]
        let streaks = CalendarMath.streaks(days: days, now: instant("2026-08-22T12:00:00Z"), timezone: utc)
        #expect(streaks.current == 2)
    }

    @Test func gapTwoDaysAgoEndsTheCurrentStreak() {
        let days = [
            day("2026-08-17", 4), day("2026-08-18", 2),
            day("2026-08-19", 0), day("2026-08-20", 0), day("2026-08-21", 0), day("2026-08-22", 0),
        ]
        let streaks = CalendarMath.streaks(days: days, now: instant("2026-08-22T12:00:00Z"), timezone: utc)
        #expect(streaks.current == 0)
        #expect(streaks.best == 2)
    }

    @Test func gapInTheMiddleSplitsRuns() {
        let days = [
            day("2026-08-10", 1), day("2026-08-11", 1), day("2026-08-12", 1), day("2026-08-13", 1),
            day("2026-08-14", 0),
            day("2026-08-15", 1), day("2026-08-16", 1),
            day("2026-08-17", 0), day("2026-08-18", 0), day("2026-08-19", 0),
            day("2026-08-20", 1), day("2026-08-21", 1), day("2026-08-22", 1),
        ]
        let streaks = CalendarMath.streaks(days: days, now: instant("2026-08-22T12:00:00Z"), timezone: utc)
        #expect(streaks.best == 4)
        #expect(streaks.current == 3)
    }

    @Test func streakCrossesYearBoundary() {
        let days = [
            day("2025-12-29", 1), day("2025-12-30", 2), day("2025-12-31", 1),
            day("2026-01-01", 3), day("2026-01-02", 1),
        ]
        let streaks = CalendarMath.streaks(days: days, now: instant("2026-01-02T12:00:00Z"), timezone: utc)
        #expect(streaks.current == 5)
        #expect(streaks.best == 5)
    }

    @Test func streakCrossesLeapDay() {
        let days = [day("2024-02-28", 1), day("2024-02-29", 1), day("2024-03-01", 1)]
        let streaks = CalendarMath.streaks(days: days, now: instant("2024-03-01T12:00:00Z"), timezone: utc)
        #expect(streaks.current == 3)
    }

    @Test func timezoneDecidesWhatTodayIs() {
        // 2026-08-23 03:00 UTC is still 2026-08-22 in Los Angeles.
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let days = [day("2026-08-21", 1), day("2026-08-22", 1)]
        let now = instant("2026-08-23T03:00:00Z")
        // UTC: last contribution was "yesterday" relative to Aug 23 — still current.
        #expect(CalendarMath.streaks(days: days, now: now, timezone: utc).current == 2)
        // LA: it's still Aug 22, streak ends today — also current.
        #expect(CalendarMath.streaks(days: days, now: now, timezone: la).current == 2)

        // A gap on the 22nd looks different per zone.
        let gapDays = [day("2026-08-20", 1), day("2026-08-21", 1), day("2026-08-22", 0)]
        // UTC on Aug 23: the last active day (21st) is two days back — broken.
        #expect(CalendarMath.streaks(days: gapDays, now: now, timezone: utc).current == 0)
        // LA on Aug 22: the 21st is yesterday — streak survives.
        #expect(CalendarMath.streaks(days: gapDays, now: now, timezone: la).current == 2)
    }

    @Test func dstTransitionDoesNotBreakDateMath() {
        // US DST ended 2025-11-02; consecutive dates around it stay consecutive.
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let days = [day("2025-10-31", 1), day("2025-11-01", 1), day("2025-11-02", 1), day("2025-11-03", 1)]
        let streaks = CalendarMath.streaks(days: days, now: instant("2025-11-03T20:00:00Z"), timezone: la)
        #expect(streaks.current == 4)
        #expect(streaks.best == 4)
    }
}

@Suite struct CalendarMathTests {
    @Test func weeksBreakOnSundays() {
        // 2026-08-16 is a Sunday.
        let days = (14...22).map { day(String(format: "2026-08-%02d", $0), 1) }
        let weeks = CalendarMath.weeks(days)
        #expect(weeks.count == 2)
        #expect(weeks[0].count == 2)  // Fri 14, Sat 15
        #expect(weeks[1].first?.day.date == "2026-08-16")
    }

    @Test func heatmapLabelsMonthChanges() {
        var days: [ContributionDay] = []
        for d in 20...31 { days.append(day(String(format: "2026-07-%02d", d), 1)) }
        for d in 1...10 { days.append(day(String(format: "2026-08-%02d", d), 2)) }
        let heatmap = CalendarMath.heatmap(days: days, weeks: 52, weekdayLabels: true)
        #expect(heatmap.monthLabels.count == 1)
        #expect(heatmap.monthLabels[0].month == 7)  // August, 0-based
        // First padded column starts on the weekday of Jul 20 (Monday = 1).
        #expect(heatmap.weeks[0].count == 7)
    }

    @Test func weeklyTotalsSumCounts() {
        let days = (14...27).map { day(String(format: "2026-08-%02d", $0), 2) }
        let totals = CalendarMath.weeklyTotals(days: days, weeks: 12)
        #expect(totals.reduce(0, +) == 28)
    }
}

@Suite struct FormatTests {
    @Test func thousands() {
        #expect(Format.thousands(0) == "0")
        #expect(Format.thousands(999) == "999")
        #expect(Format.thousands(13100) == "13,100")
        #expect(Format.thousands(1_234_567) == "1,234,567")
    }

    @Test func compact() {
        #expect(Format.compact(915) == "915")
        #expect(Format.compact(13100) == "13.1k")
        #expect(Format.compact(13000) == "13k")
        #expect(Format.compact(2_500_000) == "2.5M")
    }

    @Test func storage() {
        #expect(Format.storage(kilobytes: 512) == "512 KB")
        #expect(Format.storage(kilobytes: 4_572_774) == "4.36 GB")
    }

    @Test func asOf() {
        #expect(Format.asOf(instant("2026-08-20T09:00:00Z")) == "as of Aug 20")
    }
}
