import AppKit
import Foundation
import ServiceManagement

enum RefreshFrequency: String, CaseIterable, Identifiable {
    case hour
    case minute
    case second

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hour:
            return "按时"
        case .minute:
            return "按分"
        case .second:
            return "按秒"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .hour:
            return 3600
        case .minute:
            return 60
        case .second:
            return 1
        }
    }
}

enum ProgressDisplayStyle: String, CaseIterable, Identifiable {
    case percentageText
    case pieChart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentageText:
            return "百分比"
        case .pieChart:
            return "饼图"
        }
    }
}

enum TrackingMode: String, CaseIterable, Identifiable {
    case fixedSchedule
    case countdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixedSchedule:
            return "按时间段"
        case .countdown:
            return "按时长"
        }
    }
}

enum WorkStatus: Equatable {
    case idle
    case notStarted
    case working
    case finished
    case invalid
}

struct StatusSnapshot {
    let status: WorkStatus
    let labelText: String?
    let progressPercent: Int?
    let progressStyle: ProgressDisplayStyle?
    let labelSymbol: String
}

@MainActor
final class CountdownModel: ObservableObject {
    @Published var trackingMode: TrackingMode {
        didSet { persistAndRefresh() }
    }

    @Published var startHour: Int {
        didSet { persistAndRefresh() }
    }

    @Published var startMinute: Int {
        didSet { persistAndRefresh() }
    }

    @Published var endHour: Int {
        didSet { persistAndRefresh() }
    }

    @Published var endMinute: Int {
        didSet { persistAndRefresh() }
    }

    @Published var workDurationHours: Int {
        didSet { persistAndRefresh() }
    }

    @Published var refreshFrequency: RefreshFrequency {
        didSet { persistAndRefresh() }
    }

    @Published var progressDisplayStyle: ProgressDisplayStyle {
        didSet { persistAndRefresh() }
    }

    @Published var showsRemainingTime: Bool {
        didSet { persistAndRefresh() }
    }

    @Published var showsProgress: Bool {
        didSet { persistAndRefresh() }
    }

    @Published var quitsOneMinuteAfterWorkday: Bool {
        didSet { persistAndRefresh() }
    }

    @Published var managesStretchly: Bool {
        didSet { persistAndRefresh() }
    }

    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginRequiresApproval = false
    @Published private(set) var launchAtLoginUnsupported = false
    @Published private(set) var launchAtLoginErrorMessage: String?

    @Published private(set) var snapshot: StatusSnapshot {
        didSet { manageStretchlyIfNeeded(from: oldValue.status, to: snapshot.status) }
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
    private var wakeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchedAt = .now
        let storedMode = defaults.string(forKey: Keys.trackingMode)
        self.trackingMode = TrackingMode(rawValue: storedMode ?? "") ?? .fixedSchedule
        self.startHour = defaults.object(forKey: Keys.startHour) as? Int ?? 8
        self.startMinute = defaults.object(forKey: Keys.startMinute) as? Int ?? 0
        self.endHour = defaults.object(forKey: Keys.endHour) as? Int ?? 17
        self.endMinute = defaults.object(forKey: Keys.endMinute) as? Int ?? 0
        self.workDurationHours = defaults.object(forKey: Keys.workDurationHours) as? Int ?? 8
        self.manualStartDate = defaults.object(forKey: Keys.manualStartDate) as? Date
        let storedFrequency = defaults.string(forKey: Keys.refreshFrequency)
        self.refreshFrequency = RefreshFrequency(rawValue: storedFrequency ?? "") ?? .minute
        let storedProgressStyle = defaults.string(forKey: Keys.progressDisplayStyle)
        self.progressDisplayStyle = ProgressDisplayStyle(rawValue: storedProgressStyle ?? "") ?? .percentageText
        self.showsRemainingTime = defaults.object(forKey: Keys.showsRemainingTime) as? Bool ?? true
        self.showsProgress = defaults.object(forKey: Keys.showsProgress) as? Bool ?? true
        self.quitsOneMinuteAfterWorkday = defaults.object(forKey: Keys.quitsOneMinuteAfterWorkday) as? Bool ?? false
        self.managesStretchly = defaults.object(forKey: Keys.managesStretchly) as? Bool ?? false
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
        refreshLaunchAtLoginStatus()
    }

    deinit {
        timer?.invalidate()
        autoQuitTimer?.invalidate()
        if let wakeObserver {
            NotificationCenter.default.removeObserver(wakeObserver)
        }
    }

    func quitApp() {
        NSApp.terminate(nil)
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginErrorMessage = nil

        guard #available(macOS 13.0, *) else {
            launchAtLoginUnsupported = true
            launchAtLoginEnabled = false
            launchAtLoginRequiresApproval = false
            return
        }

        launchAtLoginUnsupported = false

        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            launchAtLoginEnabled = true
            launchAtLoginRequiresApproval = false
        case .requiresApproval:
            launchAtLoginEnabled = true
            launchAtLoginRequiresApproval = true
        case .notRegistered:
            launchAtLoginEnabled = false
            launchAtLoginRequiresApproval = false
        case .notFound:
            launchAtLoginEnabled = false
            launchAtLoginRequiresApproval = false
            launchAtLoginErrorMessage = "系统未找到可注册的启动项。"
        @unknown default:
            launchAtLoginEnabled = false
            launchAtLoginRequiresApproval = false
            launchAtLoginErrorMessage = "无法确认开机启动状态。"
        }
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        guard #available(macOS 13.0, *) else {
            launchAtLoginUnsupported = true
            return
        }

        launchAtLoginErrorMessage = nil

        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
        }

        refreshLaunchAtLoginStatus()
    }

    func openLoginItemsSettings() {
        guard #available(macOS 13.0, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }

    func startManualWork() {
        let previousStatus = snapshot.status
        manualStartDate = .now
        refreshSnapshot()
        startTimer()
        scheduleAutoQuitIfNeeded()
        manageStretchlyIfNeeded(from: previousStatus, to: snapshot.status)
    }

    private func persistAndRefresh() {
        defaults.set(trackingMode.rawValue, forKey: Keys.trackingMode)
        defaults.set(startHour, forKey: Keys.startHour)
        defaults.set(startMinute, forKey: Keys.startMinute)
        defaults.set(endHour, forKey: Keys.endHour)
        defaults.set(endMinute, forKey: Keys.endMinute)
        defaults.set(workDurationHours, forKey: Keys.workDurationHours)
        defaults.set(refreshFrequency.rawValue, forKey: Keys.refreshFrequency)
        defaults.set(progressDisplayStyle.rawValue, forKey: Keys.progressDisplayStyle)
        defaults.set(showsRemainingTime, forKey: Keys.showsRemainingTime)
        defaults.set(showsProgress, forKey: Keys.showsProgress)
        defaults.set(quitsOneMinuteAfterWorkday, forKey: Keys.quitsOneMinuteAfterWorkday)
        defaults.set(managesStretchly, forKey: Keys.managesStretchly)
        refreshSnapshot()
        startTimer()
        scheduleAutoQuitIfNeeded()
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
                self?.refreshLaunchAtLoginStatus()
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

        guard quitsOneMinuteAfterWorkday else { return }

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

    // MARK: - Stretchly

    private static let stretchlyBundleID = "net.hovancik.stretchly"

    private func manageStretchlyIfNeeded(from oldStatus: WorkStatus, to newStatus: WorkStatus) {
        guard managesStretchly else { return }

        let wasWorking = oldStatus == .working
        let isWorking = newStatus == .working

        if !wasWorking && isWorking {
            launchStretchly()
        } else if wasWorking && !isWorking {
            quitStretchly()
        }
    }

    private func launchStretchly() {
        let bundleID = Self.stretchlyBundleID
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard running.isEmpty else { return }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func quitStretchly() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Self.stretchlyBundleID)
        for app in running {
            app.terminate()
        }
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
    }
}
