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

        Settings {
            SettingsView(model: countdownModel)
        }
    }
}
