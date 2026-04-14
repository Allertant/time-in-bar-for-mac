import SwiftUI

@main
struct TimeInBarApp: App {
    @StateObject private var countdownModel = CountdownModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: countdownModel)
        } label: {
            MenuBarLabelView(snapshot: countdownModel.snapshot)
        }

        Window("Preferences", id: "settings") {
            SettingsView(model: countdownModel)
                .frame(minWidth: 420, minHeight: 220)
        }
    }
}
