import AppKit

@MainActor
public final class StretchlyManager {
    private static let bundleID = "net.hovancik.stretchly"

    public func manage(from oldStatus: WorkStatus, to newStatus: WorkStatus, enabled: Bool) {
        guard enabled else { return }

        let wasWorking = oldStatus == .working
        let isWorking = newStatus == .working

        if !wasWorking && isWorking {
            launch()
        } else if wasWorking && !isWorking {
            quit()
        }
    }

    private func launch() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID)
        guard running.isEmpty else { return }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func quit() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID) {
            app.terminate()
        }
    }
}
