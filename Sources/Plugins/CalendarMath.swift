import Foundation
import ProfileKit

/// Date arithmetic over the contribution calendar's "YYYY-MM-DD" strings.
/// Everything works on day numbers so no wall-clock time is involved; the
/// user's timezone matters only for deciding what "today" is.
enum CalendarMath {
    struct Day: Equatable {
        var year: Int
        var month: Int  // 1-12
        var day: Int
        /// Days since 0001-01-01 (proleptic Gregorian) — gap detection.
        var ordinal: Int
        /// 0 = Sunday.
        var weekday: Int
    }

    static func parse(_ date: String) -> Day? {
        let parts = date.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let ordinal = ordinalDay(year: year, month: month, day: day)
        // 0001-01-01 was a Monday (ordinal 1), so ordinal % 7 == 0 on Sundays.
        let weekday = ordinal % 7
        return Day(year: year, month: month, day: day, ordinal: ordinal, weekday: weekday)
    }

    static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static let cumulativeDays = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

    static func ordinalDay(year: Int, month: Int, day: Int) -> Int {
        let y = year - 1
        var days = y * 365 + y / 4 - y / 100 + y / 400
        days += cumulativeDays[month - 1]
        if month > 2 && isLeap(year) {
            days += 1
        }
        return days + day
    }

    /// The calendar date of `instant` in `timezone`, as an ordinal day.
    static func todayOrdinal(of instant: Date, timezone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        return ordinalDay(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// Groups contribution days into columns of 7 that break on Sundays,
    /// mirroring GitHub's calendar (first and last week may be partial).
    static func weeks(_ days: [ContributionDay]) -> [[(day: ContributionDay, parsed: Day)]] {
        var weeks: [[(ContributionDay, Day)]] = []
        var current: [(ContributionDay, Day)] = []
        for day in days {
            guard let parsed = parse(day.date) else { continue }
            if parsed.weekday == 0 && !current.isEmpty {
                weeks.append(current)
                current = []
            }
            current.append((day, parsed))
        }
        if !current.isEmpty {
            weeks.append(current)
        }
        return weeks
    }

    /// Heatmap payload from real days: levels per week (padded to the weekday
    /// row) and a month label at each week where a new month starts.
    static func heatmap(
        days: [ContributionDay], weeks weekLimit: Int, weekdayLabels: Bool
    ) -> Heatmap {
        let grouped = Array(weeks(days).suffix(weekLimit))
        var levels: [[Int]] = []
        var labels: [Heatmap.MonthLabel] = []
        var previousMonth: Int?
        for (index, week) in grouped.enumerated() {
            // Pad a partial first week so rows line up with weekdays.
            var column = [Int](repeating: 0, count: week.first?.parsed.weekday ?? 0)
            column += week.map { max(0, min($0.day.level, 4)) }
            levels.append(column)
            let month = week.first!.parsed.month
            if let previous = previousMonth, month != previous {
                labels.append(Heatmap.MonthLabel(week: index, month: month - 1))
            }
            previousMonth = month
        }
        return Heatmap(weeks: levels, monthLabels: labels, weekdayLabels: weekdayLabels)
    }

    /// Total contributions for each of the trailing `count` weeks, oldest first.
    static func weeklyTotals(days: [ContributionDay], weeks count: Int) -> [Double] {
        weeks(days).suffix(count).map { week in
            Double(week.reduce(0) { $0 + $1.day.count })
        }
    }

    struct Streaks: Equatable {
        var current: Int
        var best: Int
    }

    /// Streaks over the calendar. A day counts when it has contributions;
    /// today (in `timezone`, relative to `now`) not yet having any does not
    /// break the current streak — yesterday still continues it.
    static func streaks(days: [ContributionDay], now: Date, timezone: TimeZone) -> Streaks {
        let today = todayOrdinal(of: now, timezone: timezone)
        var best = 0
        var run = 0
        var previousOrdinal: Int?
        var runs: [(endOrdinal: Int, length: Int)] = []
        for day in days {
            guard let parsed = parse(day.date), parsed.ordinal <= today else { continue }
            if day.count > 0 {
                if let previous = previousOrdinal, parsed.ordinal == previous + 1 {
                    run += 1
                } else {
                    run = 1
                }
                previousOrdinal = parsed.ordinal
                best = max(best, run)
                runs.append((parsed.ordinal, run))
            }
        }
        var current = 0
        if let last = runs.last {
            if last.endOrdinal == today || last.endOrdinal == today - 1 {
                current = last.length
            }
        }
        return Streaks(current: current, best: best)
    }
}
