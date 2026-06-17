# TimeInBar

A macOS menu bar countdown app that shows remaining work time and progress at a glance.

## Build & Run

```bash
xcodebuild -scheme TimeInBar -configuration Debug build
```

- Xcode project: `TimeInBar.xcodeproj`
- Deployment target: macOS 14.0
- Swift 5
- No external dependencies

## Architecture

```
TimeInBar/
├── TimeInBarApp.swift              # @main entry, MenuBarExtra + Settings window
├── CountdownModel.swift            # @MainActor ObservableObject, config + timers + coordination
├── Domain.swift                    # Pure value types: enums (TrackingMode, WorkStatus, etc.) + StatusSnapshot
├── WorkScheduleCalculator.swift    # Pure static functions: snapshot generation, time formatting, date helpers
├── LaunchAtLoginService.swift      # SMAppService wrapper, @MainActor ObservableObject
├── StretchlyManager.swift          # Stretchly app launch/quit via NSRunningApplication
├── WorkdayReminderController.swift # Full-screen black overlay with auto-dismiss timer
├── MenuContentView.swift           # Menu bar dropdown: "开始上班" button, Preferences, Quit
├── MenuBarLabelView.swift          # Status bar label: text, symbol, or text+pie chart
├── StatusBarImageFactory.swift     # NSImage renderer for pie chart + text composite
├── SettingsView.swift              # Preferences window: tracking mode, display, startup, reminder
└── Info.plist
```

### Data Flow

```
SettingsView → @Published properties (didSet: persist key → refresh())
  → CountdownModel.refresh()
    → refreshSnapshot() → makeSnapshot() → WorkScheduleCalculator
      → snapshot.didSet
        → StretchlyManager.manage(from:to:enabled:)
        → WorkdayReminderController.presentThenDismiss / hide
    → startTimer() → Timer fires → handleRefreshTimer → repeat
```

### Two Tracking Modes

| | Fixed Schedule (`按时间段`) | Countdown (`按时长`) |
|---|---|---|
| Config | start/end time | work duration hours (0.5 increments) |
| Start | automatic at start hour | manual "开始上班" button |
| End | automatic at end hour | duration elapsed from manual start |
| Status when idle | `.notStarted` | `.idle` |

### WorkStatus States

`idle → working → finished` (countdown mode)  
`notStarted → working → finished` (fixed schedule)  
`invalid` (invalid config: end ≤ start in fixed schedule)

## Code Conventions

- `@MainActor` on mutable shared state, not on pure functions
- Per-key UserDefaults persistence: each `@Published` property persists only its own key in `didSet`
- All `didSet` on config properties call `refresh()` which → `refreshSnapshot()` + `startTimer()`
- `refreshSnapshot()` internally calls `scheduleAutoQuitIfNeeded()` — no caller should call it separately
- Pure calculation functions in `WorkScheduleCalculator` take all state as parameters (no instance references)
- `MainActor.assumeIsolated` in timer/notification closures (lighter than `Task { @MainActor }`)

## Key Design Decisions

- **Absolute time, not relative countdown**: timer calculates remaining time from start/end dates, not a decrementing counter. Safe across sleep/wake.
- **Snapshot as single source of truth**: UI renders from `StatusSnapshot`, never queries live time. Snapshot refresh driven by Timer aligned to display boundaries.
- **Stretchly + reminder + auto-quit are independent switches**: no feature gates another. Reminder auto-dismisses without quitting. Quit timer is separate from reminder timer.
- **Reminder only fires on `.working` → `.finished` transition in countdown mode**: prevents unwanted reminder on app relaunch after work hours.

## Known Limitations

- Cross-midnight countdown: `isDateInToday` check resets status to `.idle` after midnight
- Fixed schedule does not support overnight shifts (requires `start < end`)
- Opening Stretchly toggle mid-work does not retroactively launch Stretchly
- No unit tests
- No localization (Chinese/English strings hardcoded)
