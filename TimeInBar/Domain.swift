import Foundation

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
