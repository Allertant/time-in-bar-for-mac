import AppKit
import Foundation

@MainActor
final class CountdownModel: ObservableObject {
    @Published var trackingMode: TrackingMode {
        didSet {
            defaults.set(trackingMode.rawValue, forKey: Keys.trackingMode)
            refresh()
        }
    }

    @Published var startHour: Int {
        didSet {
            defaults.set(startHour, forKey: Keys.startHour)
            refresh()
        }
    }

    @Published var startMinute: Int {
        didSet {
            defaults.set(startMinute, forKey: Keys.startMinute)
            refresh()
        }
    }

    @Published var endHour: Int {
        didSet {
            defaults.set(endHour, forKey: Keys.endHour)
            refresh()
        }
    }

    @Published var endMinute: Int {
        didSet {
            defaults.set(endMinute, forKey: Keys.endMinute)
            refresh()
        }
    }

    @Published var workDurationHours: Double {
        didSet {
            let normalized = (workDurationHours * 2).rounded() / 2
            if workDurationHours != normalized {
                workDurationHours = normalized
                return
            }
            defaults.set(workDurationHours, forKey: Keys.workDurationHours)
            refresh()
        }
    }

    @Published var refreshFrequency: RefreshFrequency {
        didSet {
            defaults.set(refreshFrequency.rawValue, forKey: Keys.refreshFrequency)
            refresh()
        }
    }

    @Published var progressDisplayStyle: ProgressDisplayStyle {
        didSet {
            defaults.set(progressDisplayStyle.rawValue, forKey: Keys.progressDisplayStyle)
            refresh()
        }
    }

    @Published var showsRemainingTime: Bool {
        didSet {
            defaults.set(showsRemainingTime, forKey: Keys.showsRemainingTime)
            refresh()
        }
    }

    @Published var showsProgress: Bool {
        didSet {
            defaults.set(showsProgress, forKey: Keys.showsProgress)
            refresh()
        }
    }

    @Published var quitsOneMinuteAfterWorkday: Bool {
        didSet {
            defaults.set(quitsOneMinuteAfterWorkday, forKey: Keys.quitsOneMinuteAfterWorkday)
            refresh()
        }
    }

    @Published var managesStretchly: Bool {
        didSet {
            defaults.set(managesStretchly, forKey: Keys.managesStretchly)
            refresh()
        }
    }

    @Published var showsFullScreenReminderAfterWorkday: Bool {
        didSet {
            defaults.set(showsFullScreenReminderAfterWorkday, forKey: Keys.showsFullScreenReminderAfterWorkday)
            refresh()
        }
    }

    let launchAtLogin = LaunchAtLoginService()

    @Published private(set) var snapshot: StatusSnapshot {
        didSet {
            manageStretchlyIfNeeded(from: oldValue.status, to: snapshot.status)
            updateWorkdayReminderVisibility(oldStatus: oldValue.status)
        }
    }

    var todayManualStartTime: String? {
        guard let start = manualStartDate,
              Calendar.current.isDateInToday(start) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: start)
    }

    private var manualStartDate: Date? {
        didSet {
            if let date = manualStartDate {
                defaults.set(date, forKey: Keys.manualStartDate)
            } else {
                defaults.removeObject(forKey: Keys.manualStartDate)
            }
        }
    }

    private let defaults: UserDefaults
    private let launchedAt: Date
    private var timer: Timer?
    private var autoQuitTimer: Timer?
    private var reminderDismissTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let workdayReminderController = WorkdayReminderController()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchedAt = .now
        let storedMode = defaults.string(forKey: Keys.trackingMode)
        self.trackingMode = TrackingMode(rawValue: storedMode ?? "") ?? .fixedSchedule
        self.startHour = defaults.object(forKey: Keys.startHour) as? Int ?? 8
        self.startMinute = defaults.object(forKey: Keys.startMinute) as? Int ?? 0
        self.endHour = defaults.object(forKey: Keys.endHour) as? Int ?? 17
        self.endMinute = defaults.object(forKey: Keys.endMinute) as? Int ?? 0
        if defaults.object(forKey: Keys.workDurationHours) != nil {
            self.workDurationHours = defaults.double(forKey: Keys.workDurationHours)
        } else {
            self.workDurationHours = 8
        }
        self.manualStartDate = defaults.object(forKey: Keys.manualStartDate) as? Date
        let storedFrequency = defaults.string(forKey: Keys.refreshFrequency)
        self.refreshFrequency = RefreshFrequency(rawValue: storedFrequency ?? "") ?? .minute
        let storedProgressStyle = defaults.string(forKey: Keys.progressDisplayStyle)
        self.progressDisplayStyle = ProgressDisplayStyle(rawValue: storedProgressStyle ?? "") ?? .percentageText
        self.showsRemainingTime = defaults.object(forKey: Keys.showsRemainingTime) as? Bool ?? true
        self.showsProgress = defaults.object(forKey: Keys.showsProgress) as? Bool ?? true
        self.quitsOneMinuteAfterWorkday = defaults.object(forKey: Keys.quitsOneMinuteAfterWorkday) as? Bool ?? false
        self.managesStretchly = defaults.object(forKey: Keys.managesStretchly) as? Bool ?? false
        self.showsFullScreenReminderAfterWorkday = defaults.object(forKey: Keys.showsFullScreenReminderAfterWorkday) as? Bool ?? false
        self.snapshot = StatusSnapshot(
            status: .notStarted,
            labelText: nil,
            progressPercent: nil,
            progressStyle: nil,
            labelSymbol: "sunrise"
        )

        refreshSnapshot()
        startTimer()
        observeWakeNotifications()
        launchAtLogin.refresh()
    }

    deinit {
        timer?.invalidate()
        autoQuitTimer?.invalidate()
        reminderDismissTimer?.invalidate()
        if let wakeObserver {
            NotificationCenter.default.removeObserver(wakeObserver)
        }
    }

    func quitApp() {
        NSApp.terminate(nil)
    }

    func startManualWork() {
        let previousStatus = snapshot.status
        manualStartDate = .now
        refreshSnapshot()
        startTimer()
        scheduleAutoQuitIfNeeded()
        manageStretchlyIfNeeded(from: previousStatus, to: snapshot.status)
    }

    private func refresh() {
        refreshSnapshot()
        startTimer()
    }

    func showFullScreenWorkdayReminderForTesting() {
        showWorkdayReminder()
    }

    private func showWorkdayReminder() {
        workdayReminderController.show()
        NSLog("TimeInBar reminder coverage: %@", workdayReminderController.coverageSummary)
        scheduleReminderDismiss()
    }

    private func observeWakeNotifications() {
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSnapshot()
                self?.startTimer()
                self?.scheduleAutoQuitIfNeeded()
                self?.launchAtLogin.refresh()
            }
        }
    }

    private func startTimer(reference: Date = .now) {
        timer?.invalidate()
        guard let nextFireDate = nextRefreshDate(after: reference) else { return }

        let nextTimer = Timer(
            fireAt: nextFireDate,
            interval: 0,
            target: self,
            selector: #selector(handleRefreshTimer),
            userInfo: nil,
            repeats: false
        )
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    @objc private func handleRefreshTimer() {
        let now = Date()
        refreshSnapshot(now: now)
        startTimer(reference: now)
    }

    private func refreshSnapshot(now: Date = .now) {
        snapshot = makeSnapshot(now: now)
        scheduleAutoQuitIfNeeded(reference: now)
    }

    private func nextRefreshDate(after reference: Date) -> Date? {
        let candidates = [
            nextDisplayRefreshDate(after: reference),
            nextStateTransitionDate(after: reference)
        ].compactMap { $0 }

        return candidates.min()
    }

    private func nextDisplayRefreshDate(after reference: Date) -> Date? {
        let component: Calendar.Component

        switch refreshFrequency {
        case .second:
            component = .second
        case .minute:
            component = .minute
        case .hour:
            component = .hour
        }

        return Calendar.current.dateInterval(of: component, for: reference)?.end
    }

    private func nextStateTransitionDate(after reference: Date) -> Date? {
        switch trackingMode {
        case .fixedSchedule:
            guard let start = dateForToday(hour: startHour, minute: startMinute, reference: reference),
                  let end = dateForToday(hour: endHour, minute: endMinute, reference: reference),
                  start < end else {
                return nil
            }

            let candidates = [
                start,
                end
            ].filter { $0 > reference }

            return candidates.min()

        case .countdown:
            guard let start = manualStartDate,
                  Calendar.current.isDateInToday(start) else {
                return nil
            }
            let end = start.addingTimeInterval(TimeInterval(workDurationHours) * 3600)
            return end > reference ? end : nil
        }
    }

    private func scheduleAutoQuitIfNeeded(reference: Date = .now) {
        autoQuitTimer?.invalidate()
        autoQuitTimer = nil

        guard quitsOneMinuteAfterWorkday else {
            return
        }

        let endDate: Date?

        switch trackingMode {
        case .fixedSchedule:
            guard let end = dateForToday(hour: endHour, minute: endMinute, reference: reference),
                  let start = dateForToday(hour: startHour, minute: startMinute, reference: reference),
                  start < end else {
                return
            }
            endDate = end

        case .countdown:
            guard let start = manualStartDate,
                  Calendar.current.isDateInToday(start) else {
                return
            }
            endDate = start.addingTimeInterval(TimeInterval(workDurationHours) * 3600)
        }

        guard let end = endDate else { return }
        let quitAt = end.addingTimeInterval(60)

        if reference >= quitAt {
            if launchedAt < quitAt {
                quitApp()
            }
            return
        }

        let nextTimer = Timer(fireAt: quitAt, interval: 0, target: self, selector: #selector(handleAutoQuitTimer), userInfo: nil, repeats: false)
        autoQuitTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    @objc private func handleAutoQuitTimer() {
        quitApp()
    }

    private func updateWorkdayReminderVisibility(oldStatus: WorkStatus) {
        if showsFullScreenReminderAfterWorkday
            && trackingMode == .countdown
            && oldStatus == .working
            && snapshot.status == .finished {
            showWorkdayReminder()
        } else {
            reminderDismissTimer?.invalidate()
            reminderDismissTimer = nil
            workdayReminderController.hide()
        }
    }

    private func scheduleReminderDismiss() {
        guard reminderDismissTimer == nil else { return }

        reminderDismissTimer?.invalidate()
        let nextTimer = Timer(
            fireAt: Date().addingTimeInterval(3),
            interval: 0,
            target: self,
            selector: #selector(handleReminderDismissTimer),
            userInfo: nil,
            repeats: false
        )
        reminderDismissTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    @objc private func handleReminderDismissTimer() {
        workdayReminderController.hide()
    }

    // MARK: - Stretchly

    private let stretchlyManager = StretchlyManager()

    private func manageStretchlyIfNeeded(from oldStatus: WorkStatus, to newStatus: WorkStatus) {
        stretchlyManager.manage(from: oldStatus, to: newStatus, enabled: managesStretchly)
    }

    private func makeSnapshot(now: Date) -> StatusSnapshot {
        switch trackingMode {
        case .fixedSchedule:
            return makeFixedScheduleSnapshot(now: now)
        case .countdown:
            return makeCountdownSnapshot(now: now)
        }
    }

    private func makeFixedScheduleSnapshot(now: Date) -> StatusSnapshot {
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

        return makeWorkingSnapshot(start: start, end: end, now: now)
    }

    private func makeCountdownSnapshot(now: Date) -> StatusSnapshot {
        guard let start = manualStartDate,
              Calendar.current.isDateInToday(start) else {
            return StatusSnapshot(
                status: .idle,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "sunrise"
            )
        }

        let end = start.addingTimeInterval(TimeInterval(workDurationHours) * 3600)

        if now >= end {
            return StatusSnapshot(
                status: .finished,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "figure.walk.departure"
            )
        }

        return makeWorkingSnapshot(start: start, end: end, now: now)
    }

    private func makeWorkingSnapshot(start: Date, end: Date, now: Date) -> StatusSnapshot {
        let total = end.timeIntervalSince(start)
        let remaining = end.timeIntervalSince(now)
        let elapsed = now.timeIntervalSince(start)
        let progress = max(0, min(100, Int((elapsed / total) * 100)))
        let timeText = formattedRemainingTime(seconds: remaining)
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

    private func formattedRemainingTime(seconds: TimeInterval) -> String {
        let rounded: Int

        switch refreshFrequency {
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

    private func dateForToday(hour: Int, minute: Int, reference: Date) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
    }

    private enum Keys {
        static let trackingMode = "trackingMode"
        static let startHour = "startHour"
        static let startMinute = "startMinute"
        static let endHour = "endHour"
        static let endMinute = "endMinute"
        static let workDurationHours = "workDurationHours"
        static let manualStartDate = "manualStartDate"
        static let refreshFrequency = "refreshFrequency"
        static let progressDisplayStyle = "progressDisplayStyle"
        static let showsRemainingTime = "showsRemainingTime"
        static let showsProgress = "showsProgress"
        static let quitsOneMinuteAfterWorkday = "quitsOneMinuteAfterWorkday"
        static let managesStretchly = "managesStretchly"
        static let showsFullScreenReminderAfterWorkday = "showsFullScreenReminderAfterWorkday"
    }
}
