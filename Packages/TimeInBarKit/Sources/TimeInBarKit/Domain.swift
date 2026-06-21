import Foundation

public enum RefreshFrequency: String, CaseIterable, Identifiable {
    case hour
    case minute
    case second

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hour:
            return "按时"
        case .minute:
            return "按分"
        case .second:
            return "按秒"
        }
    }
}

public enum ProgressDisplayStyle: String, CaseIterable, Identifiable {
    case percentageText
    case pieChart

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .percentageText:
            return "百分比"
        case .pieChart:
            return "饼图"
        }
    }
}

public enum TrackingMode: String, CaseIterable, Identifiable {
    case fixedSchedule
    case countdown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fixedSchedule:
            return "按时间段"
        case .countdown:
            return "按时长"
        }
    }
}

public enum WorkStatus: Equatable {
    case idle
    case notStarted
    case working
    case finished
    case invalid
}

public struct StatusSnapshot: Equatable {
    public let status: WorkStatus
    public let labelText: String?
    public let progressPercent: Int?
    public let progressStyle: ProgressDisplayStyle?
    public let labelSymbol: String
}

/// A resolved [start, end] work window, used by both fixed-schedule and
/// countdown resolvers. Named (rather than a tuple) so it can be tested
/// and passed around with clear intent.
public struct ScheduleWindow: Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

/// Display-related settings that always travel together into the calculator.
public struct DisplayConfig: Equatable {
    public let showsProgress: Bool
    public let showsRemainingTime: Bool
    public let progressDisplayStyle: ProgressDisplayStyle
    public let refreshFrequency: RefreshFrequency

    public init(
        showsProgress: Bool,
        showsRemainingTime: Bool,
        progressDisplayStyle: ProgressDisplayStyle,
        refreshFrequency: RefreshFrequency
    ) {
        self.showsProgress = showsProgress
        self.showsRemainingTime = showsRemainingTime
        self.progressDisplayStyle = progressDisplayStyle
        self.refreshFrequency = refreshFrequency
    }
}

extension TimeInterval {
    /// One minute, in seconds.
    public static var secondsPerMinute: TimeInterval { 60 }
    /// One hour, in seconds.
    public static var secondsPerHour: TimeInterval { 3600 }
    /// One day, in seconds.
    public static var secondsPerDay: TimeInterval { 86400 }
}
