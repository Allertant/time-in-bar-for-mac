import AppKit
import Foundation

@MainActor
public final class CountdownModel: ObservableObject {
    // MARK: - Config (persisted, each key written in its own didSet)

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
            defaults.set(workDurationHours, forKey: Keys.workDurationHours)
            refresh()
        }
    }

    private func normalizeWorkDuration(_ hours: Double) -> Double {
        (hours * 2).rounded() / 2
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

    public let launchAtLogin = LaunchAtLoginService()

    // MARK: - Derived state

    @Published public private(set) var snapshot: StatusSnapshot {
        didSet {
            manageStretchlyIfNeeded(from: oldValue.status, to: snapshot.status)
            updateWorkdayReminderVisibility(oldStatus: oldValue.status)
        }
    }

    private static let manualStartTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    public var todayManualStartTime: String? {
        guard let session = WorkScheduleCalculator.countdownSession(
            start: manualStartDate, workDurationHours: workDurationHours, reference: .now
        ) else { return nil }
        return Self.manualStartTimeFormatter.string(from: session.start)
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
    private var timer: Timer?
    private var autoQuitTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let workdayReminderController = WorkdayReminderController()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        if let wakeObserver {
            NotificationCenter.default.removeObserver(wakeObserver)
        }
    }

    public func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Timer engine

    public func startManualWork() {
        let previousStatus = snapshot.status
        manualStartDate = .now
        refresh()
        manageStretchlyIfNeeded(from: previousStatus, to: snapshot.status)
    }

    private func refresh() {
        refreshSnapshot()
        startTimer()
    }

    public func setWorkDurationHours(_ hours: Double) {
        workDurationHours = normalizeWorkDuration(hours)
    }

    private func observeWakeNotifications() {
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                self?.launchAtLogin.refresh()
            }
        }
    }

    private func startTimer(reference: Date = .now) {
        timer?.invalidate()
        guard let nextFireDate = nextRefreshDate(after: reference) else { return }

        let interval = max(0, nextFireDate.timeIntervalSince(reference))
        let nextTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = Date()
                self.refreshSnapshot(now: now)
                self.startTimer(reference: now)
            }
        }
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
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

    // MARK: - Schedule resolution (shared by snapshot, transitions, auto-quit)

    private func fixedScheduleBounds(reference: Date) -> (start: Date, end: Date)? {
        WorkScheduleCalculator.currentFixedScheduleWindow(
            now: reference,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
    }

    private func workEndDate(reference: Date) -> Date? {
        switch trackingMode {
        case .fixedSchedule:
            return fixedScheduleBounds(reference: reference)?.end
        case .countdown:
            return WorkScheduleCalculator.countdownSession(
                start: manualStartDate, workDurationHours: workDurationHours, reference: reference
            )?.end
        }
    }

    private func nextStateTransitionDate(after reference: Date) -> Date? {
        switch trackingMode {
        case .fixedSchedule:
            guard let bounds = fixedScheduleBounds(reference: reference) else { return nil }
            return [bounds.start, bounds.end].filter { $0 > reference }.min()
        case .countdown:
            guard let end = workEndDate(reference: reference) else { return nil }
            return end > reference ? end : nil
        }
    }

    // MARK: - Auto-quit

    private func scheduleAutoQuitIfNeeded(reference: Date = .now) {
        autoQuitTimer?.invalidate()
        autoQuitTimer = nil

        guard quitsOneMinuteAfterWorkday,
              let end = workEndDate(reference: reference) else {
            return
        }

        let quitAt = end.addingTimeInterval(60)

        // Only schedule a future quit. If we are already past the quit time
        // (slept through it, or the toggle was enabled after work), do not
        // quit retroactively — the user expects the feature to apply going
        // forward, not to kill the current session.
        guard reference < quitAt else { return }

        let interval = max(0, quitAt.timeIntervalSince(reference))
        let nextTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.quitApp()
            }
        }
        autoQuitTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    // MARK: - Workday reminder

    private func updateWorkdayReminderVisibility(oldStatus: WorkStatus) {
        let eligible = showsFullScreenReminderAfterWorkday
            && trackingMode == .countdown
            && snapshot.status == .finished

        if eligible && oldStatus == .working {
            // Fresh working→finished transition: present and arm the 3s dismiss.
            workdayReminderController.presentThenDismiss(after: 3)
        } else if !eligible {
            // No longer eligible (feature off, mode switched, or left .finished):
            // hide immediately. While still eligible we leave the controller alone
            // so the periodic refresh doesn't cut a showing reminder short.
            workdayReminderController.hide()
        }
    }

    // MARK: - Stretchly

    private let stretchlyManager = StretchlyManager()

    private func manageStretchlyIfNeeded(from oldStatus: WorkStatus, to newStatus: WorkStatus) {
        stretchlyManager.manage(from: oldStatus, to: newStatus, enabled: managesStretchly)
    }

    // MARK: - Snapshot generation

    private func makeSnapshot(now: Date) -> StatusSnapshot {
        switch trackingMode {
        case .fixedSchedule:
            return WorkScheduleCalculator.makeFixedScheduleSnapshot(
                now: now,
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute,
                showsProgress: showsProgress,
                showsRemainingTime: showsRemainingTime,
                progressDisplayStyle: progressDisplayStyle,
                refreshFrequency: refreshFrequency
            )
        case .countdown:
            return WorkScheduleCalculator.makeCountdownSnapshot(
                now: now,
                manualStartDate: manualStartDate,
                workDurationHours: workDurationHours,
                showsProgress: showsProgress,
                showsRemainingTime: showsRemainingTime,
                progressDisplayStyle: progressDisplayStyle,
                refreshFrequency: refreshFrequency
            )
        }
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
