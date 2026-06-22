import Foundation
import Testing
@testable import TimeInBarKit

struct WorkScheduleCalculatorTests {

    private func display(
        showsProgress: Bool = false,
        showsRemainingTime: Bool = false,
        progressDisplayStyle: ProgressDisplayStyle = .percentageText,
        refreshFrequency: RefreshFrequency = .minute
    ) -> DisplayConfig {
        DisplayConfig(
            showsProgress: showsProgress,
            showsRemainingTime: showsRemainingTime,
            progressDisplayStyle: progressDisplayStyle,
            refreshFrequency: refreshFrequency
        )
    }

    // MARK: - formattedRemainingTime

    @Test func formattedRemainingTimeHours() {
        let result = WorkScheduleCalculator.formattedRemainingTime(
            seconds: 7200, frequency: .hour
        )
        #expect(result == "2h")
    }

    @Test func formattedRemainingTimeMinutes() {
        let result = WorkScheduleCalculator.formattedRemainingTime(
            seconds: 5400, frequency: .minute
        )
        #expect(result == "1h30m")  // 5400s = 1h30m
    }

    @Test func formattedRemainingTimeSeconds() {
        let result = WorkScheduleCalculator.formattedRemainingTime(
            seconds: 3661, frequency: .second
        )
        #expect(result == "1h1m1s")
    }

    @Test func formattedRemainingTimeLessThanOneHour() {
        let result = WorkScheduleCalculator.formattedRemainingTime(
            seconds: 1800, frequency: .minute
        )
        #expect(result == "30m")
    }

    @Test func formattedRemainingTimeLessThanOneMinute() {
        let result = WorkScheduleCalculator.formattedRemainingTime(
            seconds: 30, frequency: .minute
        )
        #expect(result == "<1m")
    }

    @Test func formattedRemainingTimeZero() {
        let result = WorkScheduleCalculator.formattedRemainingTime(
            seconds: 0, frequency: .second
        )
        #expect(result == "0s")
    }

    // MARK: - dateForToday

    @Test func dateForTodayMidnight() {
        let ref = Date(timeIntervalSince1970: 0)  // epoch
        let result = WorkScheduleCalculator.dateForToday(
            hour: 8, minute: 30, reference: ref
        )
        let components = Calendar.current.dateComponents([.hour, .minute], from: result!)
        #expect(components.hour == 8)
        #expect(components.minute == 30)
    }

    // MARK: - makeWorkingSnapshot

    @Test func makeWorkingSnapshotMidpoint() {
        let start = Date(timeIntervalSince1970: 0)
        let end = start.addingTimeInterval(3600)  // 1 hour total
        let now = start.addingTimeInterval(1800)   // 30 min elapsed = 50%

        let snapshot = WorkScheduleCalculator.makeWorkingSnapshot(
            start: start, end: end, now: now,
            display: display(showsProgress: true, showsRemainingTime: true)
        )

        #expect(snapshot.status == .working)
        #expect(snapshot.progressPercent == 50)
        #expect(snapshot.progressStyle == .percentageText)
    }

    // MARK: - makeCountdownSnapshot

    @Test func makeCountdownSnapshotIdleWhenNoManualStart() {
        let snapshot = WorkScheduleCalculator.makeCountdownSnapshot(
            now: Date(), manualStartDate: nil,
            workDurationHours: 8,
            display: display(showsProgress: true, showsRemainingTime: true)
        )
        #expect(snapshot.status == .idle)
    }

    @Test func makeCountdownSnapshotFinished() {
        let start = Calendar.current.startOfDay(for: .now)
        let now = start.addingTimeInterval(9 * 3600)  // 9 hours after start (past 8h)

        let snapshot = WorkScheduleCalculator.makeCountdownSnapshot(
            now: now, manualStartDate: start,
            workDurationHours: 8,
            display: display()
        )
        #expect(snapshot.status == .finished)
    }

    @Test func makeCountdownSnapshotWorkingAcrossMidnight() {
        // Start at 23:00 yesterday, 8h duration → ends 07:00 today.
        // At 01:00 today the session should still be working (not reset to idle).
        let todayStart = Calendar.current.startOfDay(for: .now)
        let start = todayStart.addingTimeInterval(-1 * 3600)        // 23:00 yesterday
        let now = todayStart.addingTimeInterval(1 * 3600)           // 01:00 today

        let snapshot = WorkScheduleCalculator.makeCountdownSnapshot(
            now: now, manualStartDate: start,
            workDurationHours: 8,
            display: display()
        )
        #expect(snapshot.status == .working)
    }

    @Test func makeCountdownSnapshotStaleSessionIsIdle() {
        // A session that ended yesterday is stale → idle.
        let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))!
        let start = yesterdayStart.addingTimeInterval(9 * 3600)     // 09:00 yesterday
        let now = Calendar.current.startOfDay(for: .now).addingTimeInterval(12 * 3600)  // 12:00 today

        let snapshot = WorkScheduleCalculator.makeCountdownSnapshot(
            now: now, manualStartDate: start,
            workDurationHours: 8,  // ended 17:00 yesterday
            display: display()
        )
        #expect(snapshot.status == .idle)
    }

    // MARK: - makeFixedScheduleSnapshot

    @Test func makeFixedScheduleSnapshotNotStarted() {
        let ref = Calendar.current.startOfDay(for: Date())
        let morning = Calendar.current.date(byAdding: .hour, value: 7, to: ref)!

        let snapshot = WorkScheduleCalculator.makeFixedScheduleSnapshot(
            now: morning, startHour: 8, startMinute: 0,
            endHour: 17, endMinute: 0,
            display: display()
        )
        #expect(snapshot.status == .notStarted)
    }

    @Test func makeFixedScheduleSnapshotOvernightWorkingTonight() {
        // Overnight shift 22:00→06:00. At 23:00 (after tonight's start) → working.
        let ref = Calendar.current.startOfDay(for: Date())
        let lateEvening = ref.addingTimeInterval(23 * 3600)

        let snapshot = WorkScheduleCalculator.makeFixedScheduleSnapshot(
            now: lateEvening, startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0,
            display: display()
        )
        #expect(snapshot.status == .working)
    }

    @Test func makeFixedScheduleSnapshotOvernightWorkingEarlyMorning() {
        // Overnight shift 22:00→06:00. At 03:00 → still in last night's shift.
        let ref = Calendar.current.startOfDay(for: Date())
        let earlyMorning = ref.addingTimeInterval(3 * 3600)

        let snapshot = WorkScheduleCalculator.makeFixedScheduleSnapshot(
            now: earlyMorning, startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0,
            display: display()
        )
        #expect(snapshot.status == .working)
    }

    @Test func makeFixedScheduleSnapshotOvernightFinishedDaytime() {
        // Overnight shift 22:00→06:00. At 12:00 (between shifts) → finished.
        let ref = Calendar.current.startOfDay(for: Date())
        let noon = ref.addingTimeInterval(12 * 3600)

        let snapshot = WorkScheduleCalculator.makeFixedScheduleSnapshot(
            now: noon, startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0,
            display: display()
        )
        #expect(snapshot.status == .finished)
    }

    // MARK: - currentFixedScheduleWindow (direct bounds)

    @Test func fixedScheduleWindowDayShiftIsToday() {
        // Day shift 08:00→17:00; window is today's [start, end].
        let today = Calendar.current.startOfDay(for: Date())
        let noon = today.addingTimeInterval(12 * .secondsPerHour)
        let expectedStart = today.addingTimeInterval(8 * .secondsPerHour)
        let expectedEnd = today.addingTimeInterval(17 * .secondsPerHour)

        let window = WorkScheduleCalculator.currentFixedScheduleWindow(
            now: noon, startHour: 8, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(window == ScheduleWindow(start: expectedStart, end: expectedEnd))
    }

    @Test func fixedScheduleWindowOvernightEarlyMorningIsLastNight() {
        // Overnight 22:00→06:00. At 03:00 the relevant shift started yesterday at 22:00.
        let today = Calendar.current.startOfDay(for: Date())
        let earlyMorning = today.addingTimeInterval(3 * .secondsPerHour)
        let expectedStart = today.addingTimeInterval(-2 * .secondsPerHour)         // 22:00 yesterday
        let expectedEnd = today.addingTimeInterval(6 * .secondsPerHour)            // 06:00 today

        let window = WorkScheduleCalculator.currentFixedScheduleWindow(
            now: earlyMorning, startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0
        )
        #expect(window == ScheduleWindow(start: expectedStart, end: expectedEnd))
    }

    @Test func fixedScheduleWindowOvernightEveningIsTonight() {
        // Overnight 22:00→06:00. At 23:00 the relevant shift started today.
        let today = Calendar.current.startOfDay(for: Date())
        let lateEvening = today.addingTimeInterval(23 * .secondsPerHour)
        let expectedStart = today.addingTimeInterval(22 * .secondsPerHour)         // 22:00 today
        let expectedEnd = today.addingTimeInterval((24 + 6) * .secondsPerHour)     // 06:00 tomorrow

        let window = WorkScheduleCalculator.currentFixedScheduleWindow(
            now: lateEvening, startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0
        )
        #expect(window == ScheduleWindow(start: expectedStart, end: expectedEnd))
    }

    // MARK: - countdownSession (direct bounds)

    @Test func countdownSessionNilWhenNoStart() {
        #expect(WorkScheduleCalculator.countdownSession(start: nil, workDurationHours: 8, reference: .now) == nil)
    }

    @Test func countdownSessionRelevantReturnsWindow() {
        let start = Calendar.current.startOfDay(for: .now).addingTimeInterval(9 * .secondsPerHour)  // 09:00 today
        let now = start.addingTimeInterval(2 * .secondsPerHour)                                      // 11:00 today
        let expectedEnd = start.addingTimeInterval(8 * .secondsPerHour)

        let window = WorkScheduleCalculator.countdownSession(start: start, workDurationHours: 8, reference: now)
        #expect(window == ScheduleWindow(start: start, end: expectedEnd))
    }

    @Test func countdownSessionStaleReturnsNil() {
        // Started 09:00 yesterday, 8h → ended 17:00 yesterday; now today → stale.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))!
        let start = yesterday.addingTimeInterval(9 * .secondsPerHour)

        #expect(WorkScheduleCalculator.countdownSession(start: start, workDurationHours: 8, reference: .now) == nil)
    }

    @Test func countdownSessionCrossMidnightReturnsWindow() {
        // Start 23:00 yesterday, 8h → ends 07:00 today; still relevant today.
        let today = Calendar.current.startOfDay(for: .now)
        let start = today.addingTimeInterval(-1 * .secondsPerHour)        // 23:00 yesterday
        let now = today.addingTimeInterval(1 * .secondsPerHour)           // 01:00 today
        let expectedEnd = start.addingTimeInterval(8 * .secondsPerHour)

        let window = WorkScheduleCalculator.countdownSession(start: start, workDurationHours: 8, reference: now)
        #expect(window == ScheduleWindow(start: start, end: expectedEnd))
    }
}
