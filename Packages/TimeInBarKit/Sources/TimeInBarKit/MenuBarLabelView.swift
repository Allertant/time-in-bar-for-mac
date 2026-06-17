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
                Image(
                    nsImage: StatusBarImageFactory.makeTimeAndPieImage(
                        text: labelText,
                        progress: Double(progressPercent) / 100.0
                    )
                )
            } else {
                Text(labelText)
                    .monospacedDigit()
            }
        } else {
            Image(systemName: snapshot.labelSymbol)
        }
    }
}
