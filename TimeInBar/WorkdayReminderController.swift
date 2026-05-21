import AppKit
import SwiftUI

@MainActor
final class WorkdayReminderController {
    private var windows: [WorkdayReminderWindow] = []
    private var screenObserver: NSObjectProtocol?

    var isPresented: Bool {
        !windows.isEmpty
    }

    var presentedWindowCount: Int {
        windows.count
    }

    var targetScreenCount: Int {
        targetScreens.count
    }

    var coverageSummary: String {
        let screenFrames = targetScreens
            .map { NSStringFromRect($0.frame) }
            .joined(separator: ", ")
        return "windows=\(presentedWindowCount), screens=\(targetScreenCount), frames=[\(screenFrames)]"
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func show() {
        guard windows.isEmpty else { return }

        observeScreenChanges()
        createWindows()
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    private func observeScreenChanges() {
        guard screenObserver == nil else { return }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPresented else { return }
                self.recreateWindows()
            }
        }
    }

    private func recreateWindows() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        createWindows()
    }

    private func createWindows() {
        let screens = targetScreens

        for screen in screens {
            let screenRelativeFrame = NSRect(origin: .zero, size: screen.frame.size)
            let window = WorkdayReminderWindow(
                contentRect: screenRelativeFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.backgroundColor = .black
            window.isOpaque = true
            window.level = .screenSaver
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .ignoresCycle,
                .stationary
            ]
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.onDismiss = { [weak self] in
                self?.hide()
            }
            window.contentView = NSHostingView(rootView: WorkdayReminderView())
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            windows.append(window)
        }

        if windows.count != screens.count {
            NSLog("TimeInBar reminder screen coverage mismatch: windows=%d screens=%d", windows.count, screens.count)
        } else {
            NSLog("TimeInBar reminder screen coverage verified: windows=%d screens=%d", windows.count, screens.count)
        }
    }

    private var targetScreens: [NSScreen] {
        NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
    }
}

private final class WorkdayReminderWindow: NSWindow {
    var onDismiss: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onDismiss?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func close() {}

    override func performClose(_ sender: Any?) {
        onDismiss?()
    }
}

private struct WorkdayReminderView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                Text("下班了，休息吧")
                    .font(.system(size: fontSize(for: proxy.size), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(48)

                VStack {
                    Spacer()

                    Text("按 ESC 关闭")
                        .font(.system(size: min(fontSize(for: proxy.size) * 0.25, 18)))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 32, 48))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func fontSize(for size: CGSize) -> CGFloat {
        min(max(min(size.width, size.height) * 0.12, 48), 120)
    }
}
