import Foundation

public enum WorkScheduleCalculator {
    public static func makeFixedScheduleSnapshot(
        now: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        showsProgress: Bool,
        showsRemainingTime: Bool,
        progressDisplayStyle: ProgressDisplayStyle,
        refreshFrequency: RefreshFrequency
    ) -> StatusSnapshot {
        guard let start = dateForToday(hour: startHour, minute: startMinute, reference: now),
              let end = dateForToday(hour: endHour, minute: endMinute, reference: now),
              start < end else {
            return StatusSnapshot(
                status: .invalid,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "exclamationmark.triangle"
            )
        }

        if now < start {
            return StatusSnapshot(
                status: .notStarted,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "sunrise"
            )
        }

        if now >= end {
            return StatusSnapshot(
                status: .finished,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "figure.walk.departure"
            )
        }

        return makeWorkingSnapshot(
            start: start,
            end: end,
            now: now,
            showsProgress: showsProgress,
            showsRemainingTime: showsRemainingTime,
            progressDisplayStyle: progressDisplayStyle,
            refreshFrequency: refreshFrequency
        )
    }

    public static func makeCountdownSnapshot(
        now: Date,
        manualStartDate: Date?,
        workDurationHours: Double,
        showsProgress: Bool,
        showsRemainingTime: Bool,
        progressDisplayStyle: ProgressDisplayStyle,
        refreshFrequency: RefreshFrequency
    ) -> StatusSnapshot {
        guard let start = manualStartDate else {
            return StatusSnapshot(
                status: .idle,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "sunrise"
            )
        }

        let end = start.addingTimeInterval(workDurationHours * 3600)

        // A session is relevant if it ends today or later. This supports
        // cross-midnight work (e.g. start 23:00, 8h) — the session stays
        // working/finished through the end's day, then resets to idle.
        guard end >= Calendar.current.startOfDay(for: now) else {
            return StatusSnapshot(
                status: .idle,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "sunrise"
            )
        }

        if now >= end {
            return StatusSnapshot(
                status: .finished,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "figure.walk.departure"
            )
        }

        return makeWorkingSnapshot(
            start: start,
            end: end,
            now: now,
            showsProgress: showsProgress,
            showsRemainingTime: showsRemainingTime,
            progressDisplayStyle: progressDisplayStyle,
            refreshFrequency: refreshFrequency
        )
    }

    public static func makeWorkingSnapshot(
        start: Date,
        end: Date,
        now: Date,
        showsProgress: Bool,
        showsRemainingTime: Bool,
        progressDisplayStyle: ProgressDisplayStyle,
        refreshFrequency: RefreshFrequency
    ) -> StatusSnapshot {
        let total = end.timeIntervalSince(start)
        let remaining = end.timeIntervalSince(now)
        let elapsed = now.timeIntervalSince(start)
        let progress = max(0, min(100, Int((elapsed / total) * 100)))
        let timeText = formattedRemainingTime(seconds: remaining, frequency: refreshFrequency)

        let labelText: String?
        let progressPercent: Int?
        let progressStyle: ProgressDisplayStyle?

        if showsProgress {
            switch progressDisplayStyle {
            case .percentageText:
                labelText = showsRemainingTime ? "\(timeText) · \(progress)%" : "\(progress)%"
                progressPercent = progress
                progressStyle = progressDisplayStyle
            case .pieChart:
                labelText = showsRemainingTime ? timeText : ""
                progressPercent = progress
                progressStyle = progressDisplayStyle
            }
        } else {
            labelText = showsRemainingTime ? timeText : nil
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
        let rounded: Int

        switch frequency {
        case .hour:
            rounded = Int(seconds.rounded(.down))
            let hours = max(0, rounded / 3600)
            return hours > 0 ? "\(hours)h" : "<1h"
        case .minute:
            rounded = Int(seconds.rounded(.down))
            let totalMinutes = max(0, rounded / 60)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 {
                return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h"
            }
            return minutes > 0 ? "\(minutes)m" : "<1m"
        case .second:
            rounded = max(0, Int(seconds.rounded(.down)))
            let hours = rounded / 3600
            let minutes = (rounded % 3600) / 60
            let secs = rounded % 60
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
