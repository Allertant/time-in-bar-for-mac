import Foundation
import Testing
@testable import TimeInBarKit

struct WorkScheduleCalculatorTests {

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
            showsProgress: true, showsRemainingTime: true,
            progressDisplayStyle: .percentageText,
            refreshFrequency: .minute
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
            showsProgress: true, showsRemainingTime: true,
            progressDisplayStyle: .percentageText,
            refreshFrequency: .minute
        )
        #expect(snapshot.status == .idle)
    }

    @Test func makeCountdownSnapshotFinished() {
        let start = Calendar.current.startOfDay(for: .now)
        let now = start.addingTimeInterval(9 * 3600)  // 9 hours after start (past 8h)

        let snapshot = WorkScheduleCalculator.makeCountdownSnapshot(
            now: now, manualStartDate: start,
            workDurationHours: 8,
            showsProgress: false, showsRemainingTime: false,
            progressDisplayStyle: .percentageText,
            refreshFrequency: .minute
        )
        #expect(snapshot.status == .finished)
    }

    // MARK: - makeFixedScheduleSnapshot

    @Test func makeFixedScheduleSnapshotNotStarted() {
        let ref = Calendar.current.startOfDay(for: Date())
        let morning = Calendar.current.date(byAdding: .hour, value: 7, to: ref)!

        let snapshot = WorkScheduleCalculator.makeFixedScheduleSnapshot(
            now: morning, startHour: 8, startMinute: 0,
            endHour: 17, endMinute: 0,
            showsProgress: false, showsRemainingTime: false,
            progressDisplayStyle: .percentageText,
            refreshFrequency: .minute
        )
        #expect(snapshot.status == .notStarted)
    }

    @Test func makeFixedScheduleSnapshotInvalid() {
        let ref = Calendar.current.startOfDay(for: Date())

        let snapshot = WorkScheduleCalculator.makeFixedScheduleSnapshot(
            now: ref, startHour: 17, startMinute: 0,
            endHour: 8, endMinute: 0,
            showsProgress: false, showsRemainingTime: false,
            progressDisplayStyle: .percentageText,
            refreshFrequency: .minute
        )
        #expect(snapshot.status == .invalid)
    }
}
