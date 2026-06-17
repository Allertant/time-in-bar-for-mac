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

    public var interval: TimeInterval {
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

public struct StatusSnapshot {
    public let status: WorkStatus
    public let labelText: String?
    public let progressPercent: Int?
    public let progressStyle: ProgressDisplayStyle?
    public let labelSymbol: String
}
