import SwiftUI

public struct MenuBarLabelView: View {
    public let snapshot: StatusSnapshot

    public init(snapshot: StatusSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        if let labelText = snapshot.labelText {
            if snapshot.progressStyle == .pieChart,
               let progressPercent = snapshot.progressPercent {
                // Text is baked into the image; expose it (plus status) to VoiceOver.
                Image(
                    nsImage: StatusBarImageFactory.makeTimeAndPieImage(
                        text: labelText,
                        progress: Double(progressPercent) / 100.0
                    )
                )
                .accessibilityLabel("\(statusLabel) \(labelText)")
            } else {
                // Plain text — VoiceOver already reads the remaining-time string.
                Text(labelText)
                    .monospacedDigit()
            }
        } else {
            // Symbol-only states have no readable text; label them by status.
            Image(systemName: snapshot.labelSymbol)
                .accessibilityLabel(statusLabel)
        }
    }

    /// Short, status-derived label for VoiceOver.
    private var statusLabel: String {
        switch snapshot.status {
        case .idle, .notStarted:
            return "未上班"
        case .working:
            return "工作中"
        case .finished:
            return "已下班"
        case .invalid:
            return "工作时间配置无效"
        }
    }
}
