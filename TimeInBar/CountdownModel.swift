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

enum WorkStatus: Equatable {
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
    let menuTitle: String
    let menuDetail: String?
}

@MainActor
final class CountdownModel: ObservableObject {
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

    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginRequiresApproval = false
    @Published private(set) var launchAtLoginUnsupported = false
    @Published private(set) var launchAtLoginErrorMessage: String?

    @Published private(set) var snapshot: StatusSnapshot

    private let defaults: UserDefaults
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.startHour = defaults.object(forKey: Keys.startHour) as? Int ?? 8
        self.startMinute = defaults.object(forKey: Keys.startMinute) as? Int ?? 0
        self.endHour = defaults.object(forKey: Keys.endHour) as? Int ?? 17
        self.endMinute = defaults.object(forKey: Keys.endMinute) as? Int ?? 0
        let storedFrequency = defaults.string(forKey: Keys.refreshFrequency)
        self.refreshFrequency = RefreshFrequency(rawValue: storedFrequency ?? "") ?? .minute
        let storedProgressStyle = defaults.string(forKey: Keys.progressDisplayStyle)
        self.progressDisplayStyle = ProgressDisplayStyle(rawValue: storedProgressStyle ?? "") ?? .percentageText
        self.showsRemainingTime = defaults.object(forKey: Keys.showsRemainingTime) as? Bool ?? true
        self.showsProgress = defaults.object(forKey: Keys.showsProgress) as? Bool ?? true
        self.snapshot = StatusSnapshot(
            status: .notStarted,
            labelText: nil,
            progressPercent: nil,
            progressStyle: nil,
            labelSymbol: "sunrise",
            menuTitle: "还没有上班",
            menuDetail: nil
        )

        refreshSnapshot()
        startTimer()
        observeWakeNotifications()
        refreshLaunchAtLoginStatus()
    }

    deinit {
        timer?.invalidate()
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

    private func persistAndRefresh() {
        defaults.set(startHour, forKey: Keys.startHour)
        defaults.set(startMinute, forKey: Keys.startMinute)
        defaults.set(endHour, forKey: Keys.endHour)
        defaults.set(endMinute, forKey: Keys.endMinute)
        defaults.set(refreshFrequency.rawValue, forKey: Keys.refreshFrequency)
        defaults.set(progressDisplayStyle.rawValue, forKey: Keys.progressDisplayStyle)
        defaults.set(showsRemainingTime, forKey: Keys.showsRemainingTime)
        defaults.set(showsProgress, forKey: Keys.showsProgress)
        refreshSnapshot()
        startTimer()
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
                self?.refreshLaunchAtLoginStatus()
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let nextTimer = Timer(timeInterval: refreshFrequency.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSnapshot()
            }
        }
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func refreshSnapshot(now: Date = .now) {
        snapshot = makeSnapshot(now: now)
    }

    private func makeSnapshot(now: Date) -> StatusSnapshot {
        guard let start = dateForToday(hour: startHour, minute: startMinute, reference: now),
              let end = dateForToday(hour: endHour, minute: endMinute, reference: now),
              start < end else {
            return StatusSnapshot(
                status: .invalid,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "exclamationmark.triangle",
                menuTitle: "时间设置无效",
                menuDetail: "结束时间必须晚于开始时间"
            )
        }

        if now < start {
            return StatusSnapshot(
                status: .notStarted,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "sunrise",
                menuTitle: "还没有上班",
                menuDetail: "今天从 \(timeText(hour: startHour, minute: startMinute)) 开始"
            )
        }

        if now >= end {
            return StatusSnapshot(
                status: .finished,
                labelText: nil,
                progressPercent: nil,
                progressStyle: nil,
                labelSymbol: "figure.walk.departure",
                menuTitle: "下班了!!",
                menuDetail: "今天已经结束啦"
            )
        }

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
            labelSymbol: "timer",
            menuTitle: "距离下班还剩 \(timeText)",
            menuDetail: "今日进度 \(progress)%"
        )
    }

    private func formattedRemainingTime(seconds: TimeInterval) -> String {
        let rounded: Int

        switch refreshFrequency {
        case .hour:
            rounded = Int(seconds.rounded(.down))
            let hours = max(0, rounded / 3600)
            return "\(hours)h"
        case .minute:
            rounded = Int(seconds.rounded(.down))
            let totalMinutes = max(0, rounded / 60)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 {
                return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h"
            }
            return "\(minutes)m"
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

    private func timeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func dateForToday(hour: Int, minute: Int, reference: Date) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
    }

    private enum Keys {
        static let startHour = "startHour"
        static let startMinute = "startMinute"
        static let endHour = "endHour"
        static let endMinute = "endMinute"
        static let refreshFrequency = "refreshFrequency"
        static let progressDisplayStyle = "progressDisplayStyle"
        static let showsRemainingTime = "showsRemainingTime"
        static let showsProgress = "showsProgress"
    }
}
