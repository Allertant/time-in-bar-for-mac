import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var unsupported = false
    @Published private(set) var errorMessage: String?

    public func refresh() {
        errorMessage = nil

        guard #available(macOS 13.0, *) else {
            unsupported = true
            enabled = false
            requiresApproval = false
            return
        }

        unsupported = false

        switch SMAppService.mainApp.status {
        case .enabled:
            enabled = true
            requiresApproval = false
        case .requiresApproval:
            enabled = true
            requiresApproval = true
        case .notRegistered:
            enabled = false
            requiresApproval = false
        case .notFound:
            enabled = false
            requiresApproval = false
            errorMessage = String(localized: "系统未找到可注册的启动项。")
        @unknown default:
            enabled = false
            requiresApproval = false
            errorMessage = String(localized: "无法确认开机启动状态。")
        }
    }

    public func setEnabled(_ isEnabled: Bool) {
        guard #available(macOS 13.0, *) else {
            unsupported = true
            return
        }

        var caughtError: String?
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            caughtError = error.localizedDescription
        }

        // refresh() re-reads status and clears errorMessage; re-apply the
        // caught error afterwards so the user actually sees what went wrong.
        refresh()
        if let caughtError {
            errorMessage = caughtError
        }
    }

    public func openSettings() {
        guard #available(macOS 13.0, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }
}
