import SwiftUI
import AppKit

public struct MenuContentView: View {
    @ObservedObject public var model: CountdownModel
    @Environment(\.openWindow) private var openWindow

    public init(model: CountdownModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    private var showsStartButton: Bool {
        model.trackingMode == .countdown
            && (model.snapshot.status == .idle || model.snapshot.status == .finished)
    }

    public var body: some View {
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
