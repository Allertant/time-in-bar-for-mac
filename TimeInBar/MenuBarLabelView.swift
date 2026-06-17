import SwiftUI

struct MenuBarLabelView: View {
    let snapshot: StatusSnapshot

    var body: some View {
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
