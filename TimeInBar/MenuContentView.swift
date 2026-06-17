import SwiftUI
import AppKit

struct MenuContentView: View {
    @ObservedObject var model: CountdownModel
    @Environment(\.openWindow) private var openWindow

    private var showsStartButton: Bool {
        model.trackingMode == .countdown
            && (model.snapshot.status == .idle || model.snapshot.status == .finished)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsStartButton {
                Button("开始上班") {
                    model.startManualWork()
                }
            }

            Button("Preferences…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }

            Button("Quit") {
                model.quitApp()
            }
        }
        .padding(12)
        .frame(minWidth: 240, alignment: .leading)
    }
}
