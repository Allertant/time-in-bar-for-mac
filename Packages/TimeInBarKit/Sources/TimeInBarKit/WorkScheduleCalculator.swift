import Foundation

public enum WorkScheduleCalculator {
    /// Resolves the relevant fixed-schedule shift window for `now`.
    /// For day shifts (start < end) the window is [start, end] today.
    /// For overnight shifts (start >= end) end is the next day; the window
    /// wrapping the current moment is returned (last night's or tonight's).
    public static func currentFixedScheduleWindow(
        now: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) -> ScheduleWindow? {
        guard let startToday = dateForToday(hour: startHour, minute: startMinute, reference: now),
              let endToday = dateForToday(hour: endHour, minute: endMinute, reference: now) else {
            return nil
        }

        let isOvernight = startToday >= endToday
        guard isOvernight else {
            return ScheduleWindow(start: startToday, end: endToday)
        }

        // Overnight: end is the day after start. Three regions relative to `now`:
        //   now < endToday            → still in last night's shift
        //   endToday <= now < startToday → daytime, between shifts (finished)
        //   now >= startToday         → in tonight's shift
        if now < startToday {
            // Last night's shift: started yesterday at startHour, ends today at endHour.
            return ScheduleWindow(start: startToday.addingTimeInterval(-.secondsPerDay), end: endToday)
        }
        // Tonight's shift: starts today at startHour, ends tomorrow at endHour.
        return ScheduleWindow(start: startToday, end: endToday.addingTimeInterval(.secondsPerDay))
    }

    public static func makeFixedScheduleSnapshot(
        now: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        display: DisplayConfig
    ) -> StatusSnapshot {
        guard let window = currentFixedScheduleWindow(
            now: now, startHour: startHour, startMinute: startMinute,
            endHour: endHour, endMinute: endMinute
        ) else {
            return StatusSnapshot(
                status: .invalid,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "exclamationmark.triangle"
            )
        }

        if now < window.start {
            return StatusSnapshot(
                status: .notStarted,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "sunrise"
            )
        }

        if now >= window.end {
            return StatusSnapshot(
                status: .finished,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "figure.walk.departure"
            )
        }

        return makeWorkingSnapshot(
            start: window.start,
            end: window.end,
            now: now,
            display: display
        )
    }

    /// Resolves the countdown session window [start, start+duration] if it is
    /// still relevant — i.e. ends today or later. Returns nil when there is no
    /// manual start, or the session ended before today (stale). This is the
    /// single source of truth for "is this countdown session active", used by
    /// snapshot generation, scheduling, and the start-time label.
    public static func countdownSession(
        start manualStartDate: Date?,
        workDurationHours: Double,
        reference: Date
    ) -> ScheduleWindow? {
        guard let start = manualStartDate else { return nil }
        let end = start.addingTimeInterval(workDurationHours * .secondsPerHour)
        guard end >= Calendar.current.startOfDay(for: reference) else { return nil }
        return ScheduleWindow(start: start, end: end)
    }

    public static func makeCountdownSnapshot(
        now: Date,
        manualStartDate: Date?,
        workDurationHours: Double,
        display: DisplayConfig
    ) -> StatusSnapshot {
        guard let session = countdownSession(
            start: manualStartDate, workDurationHours: workDurationHours, reference: now
        ) else {
            return StatusSnapshot(
                status: .idle,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "sunrise"
            )
        }

        if now >= session.end {
            return StatusSnapshot(
                status: .finished,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "figure.walk.departure"
            )
        }

        return makeWorkingSnapshot(
            start: session.start,
            end: session.end,
            now: now,
            display: display
        )
    }

    public static func makeWorkingSnapshot(
        start: Date,
        end: Date,
        now: Date,
        display: DisplayConfig
    ) -> StatusSnapshot {
        let total = end.timeIntervalSince(start)
        let remaining = end.timeIntervalSince(now)
        let elapsed = now.timeIntervalSince(start)
        let progress = max(0, min(100, Int((elapsed / total) * 100)))
        let timeText = formattedRemainingTime(seconds: remaining, frequency: display.refreshFrequency)

        let labelText: String?
        let progressPercent: Int?
        let progressStyle: ProgressDisplayStyle?

        if display.showsProgress {
            switch display.progressDisplayStyle {
            case .percentageText:
                labelText = display.showsRemainingTime ? "\(timeText) · \(progress)%" : "\(progress)%"
                progressPercent = progress
                progressStyle = display.progressDisplayStyle
            case .pieChart:
                labelText = display.showsRemainingTime ? timeText : ""
                progressPercent = progress
                progressStyle = display.progressDisplayStyle
            }
        } else {
            labelText = display.showsRemainingTime ? timeText : nil
            progressPercent = nil
            progressStyle = nil
        }

        return StatusSnapshot(
            status: .working,
            labelText: labelText,
            progressPercent: progressPercent,
            progressStyle: progressStyle,
            labelSymbol: "timer"
        )
    }

    public static func formattedRemainingTime(seconds: TimeInterval, frequency: RefreshFrequency) -> String {
        let minute = 60
        let hour = 60 * minute
        let rounded = max(0, Int(seconds.rounded(.down)))

        switch frequency {
        case .hour:
            let hours = rounded / hour
            return hours > 0 ? "\(hours)h" : "<1h"
        case .minute:
            let totalMinutes = rounded / minute
            let hours = totalMinutes / minute
            let minutes = totalMinutes % minute
            if hours > 0 {
                return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h"
            }
            return minutes > 0 ? "\(minutes)m" : "<1m"
        case .second:
            let hours = rounded / hour
            let minutes = (rounded % hour) / minute
            let secs = rounded % minute
            if hours > 0 {
                return "\(hours)h\(minutes)m\(secs)s"
            }
            if minutes > 0 {
                return "\(minutes)m\(secs)s"
            }
            return "\(secs)s"
        }
    }

    public static func dateForToday(hour: Int, minute: Int, reference: Date) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
    }
}
