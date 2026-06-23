# TimeInBar 技术实现说明

> 本文档描述当前的实现状态。约定与设计决策的速查见仓库根目录的
> `CLAUDE.md`，产品范围见 `requirements.md`。

## 1. 技术选型

- `SwiftUI` + `MenuBarExtra`：原生菜单栏应用
- `UserDefaults`：按 key 独立持久化的配置
- `ServiceManagement`（`SMAppService`）：开机启动
- `AppKit`（`NSRunningApplication` / `NSWorkspace`）：Stretchly 进程管理、全屏提醒窗口
- 无第三方依赖

## 2. 目录结构

薄 Xcode app 壳 + 本地 SPM 包，所有业务逻辑、UI、领域代码都在
`Packages/TimeInBarKit` 里（遵循项目的 SPM 架构规则）。

```text
time-in-bar-for-mac/
├── CLAUDE.md                        # AI/编码上下文速查
├── docs/                            # 产品与技术文档
├── TimeInBar/                       # app target（薄壳）
│   ├── TimeInBarApp.swift           # @main，MenuBarExtra + Settings 窗口
│   ├── Info.plist                   # LSUIElement = true（纯菜单栏 agent）
│   └── Localizable.xcstrings        # zh-Hans 源语言，en 翻译
├── Packages/TimeInBarKit/
│   ├── Package.swift
│   ├── Sources/TimeInBarKit/
│   │   ├── Domain.swift             # 纯值类型：枚举 + StatusSnapshot + ScheduleWindow + DisplayConfig
│   │   ├── WorkScheduleCalculator.swift  # 纯静态函数：窗口解析、快照生成、时间格式化
│   │   ├── CountdownModel.swift     # @MainActor ObservableObject，配置 + 定时器 + 协调
│   │   ├── LaunchAtLoginService.swift     # SMAppService 封装
│   │   ├── StretchlyManager.swift         # Stretchly 启动/退出
│   │   ├── WorkdayReminderController.swift# 全屏黑色遮罩 + 自动消失计时器
│   │   ├── MenuContentView.swift          # 下拉菜单：开始上班 / Preferences / Quit
│   │   ├── MenuBarLabelView.swift         # 状态栏标签：文字 / 符号 / 文字+饼图
│   │   ├── StatusBarImageFactory.swift    # 饼图+文字合成的 NSImage 渲染
│   │   └── SettingsView.swift             # 偏好窗口（拆成各 section 子视图）
│   └── Tests/TimeInBarKitTests/
│       └── WorkScheduleCalculatorTests.swift  # 23 个纯函数测试
└── TimeInBar.xcodeproj/
```

## 3. 模块职责

### 3.1 App 入口（`TimeInBarApp.swift`）

- 创建全局 `CountdownModel`（`@StateObject`）
- 挂载 `MenuBarExtra`（标签 = `MenuBarLabelView`，内容 = `MenuContentView`）
- 挂载 Settings 窗口（`SettingsView`）

### 3.2 领域层（`Domain.swift`）

纯值类型，无依赖：

- `TrackingMode`：`.fixedSchedule` / `.countdown`
- `WorkStatus`：`.idle` / `.notStarted` / `.working` / `.finished` / `.invalid`
- `RefreshFrequency`、`ProgressDisplayStyle`
- `StatusSnapshot`（UI 单一数据源，`Equatable`）
- `ScheduleWindow`（解析后的 `[start, end]`，`Equatable`）
- `DisplayConfig`（打包的显示配置）

### 3.3 纯计算（`WorkScheduleCalculator.swift`）

所有函数都不持有实例状态，入参即全部上下文，独立可测：

- `currentFixedScheduleWindow`：解析固定时间段的班次窗口（日班 / 夜班跨天）
- `countdownSession`：解析倒计时会话是否仍有效（含跨午夜）
- `makeFixedScheduleSnapshot` / `makeCountdownSnapshot` / `makeWorkingSnapshot`
- `formattedRemainingTime`：按刷新频率格式化剩余时间
- `dateForToday`

### 3.4 协调器（`CountdownModel.swift`）

`@MainActor ObservableObject`，串联配置 → 快照 → 副作用：

- 持有全部 `@Published` 配置，每个属性在 `didSet` 里**只持久化自己的 key**，再调 `refresh()`
- `refresh()` → `refreshSnapshot()`（重算快照、按需调度自动退出）+ `startTimer()`
- 快照的 `didSet` 触发 Stretchly 管理和全屏提示两个副作用（基于状态**转换**判定）
- 定时器对齐到显示边界（秒/分/时）与状态转换时刻，block 形式 + `[weak self]`
- 监听系统唤醒，恢复后重算

### 3.5 服务

- `LaunchAtLoginService`：`SMAppService` 状态查询 / 注册 / 注销 / 打开系统设置
- `StretchlyManager`：按 bundle id 查运行实例、`NSWorkspace.open` 启动、`terminate` 退出
- `WorkdayReminderController`：每屏一个 `.screenSaver` 级全屏黑窗，3 秒自动消失，ESC/Cmd+W 可关

### 3.6 视图

- `MenuBarLabelView`：按快照渲染文字 / 符号 / 文字+饼图，附 VoiceOver 标签
- `MenuContentView`：下拉菜单
- `SettingsView`：偏好窗口，拆为 `WorkTimeSection` / `DisplaySection` / `StartupSection` / `ReminderSection`
- `StatusBarImageFactory`：饼图 + 文字的 `NSImage` 合成

## 4. 数据流

```text
SettingsView → @Published 属性（didSet: 写自己的 key → refresh()）
  → refresh()
    → refreshSnapshot() → makeSnapshot() → WorkScheduleCalculator
      → snapshot（仅在变化时重新赋值，避免无谓重渲染）
        → didSet 副作用：
            StretchlyManager.manage(from:to:enabled:)
            WorkdayReminderController.presentThenDismiss / hide
    → startTimer() → 定时器到点 → handleRefreshTimer → 循环
```

## 5. 两种打卡模式

| | 固定时间段 `按时间段` | 倒计时 `按时长` |
|---|---|---|
| 配置 | 开始/结束时间 | 工作时长（0.5 步进） |
| 开始 | 到开始时刻自动 | 手动点"开始上班" |
| 结束 | 到结束时刻自动 | 从手动开始计满时长 |
| 空闲态 | `.notStarted` | `.idle` |
| 跨天 | 支持：`start >= end` 表示 end 在次日 | 支持：会话 end 在今天或更晚就一直有效 |

状态流转：

- 倒计时：`idle → working → finished`
- 固定时间段：`notStarted → working → finished`
- `invalid` 仅在日期无法构造时出现（实际不可达，夜班已被合法化）

## 6. 刷新机制

`Timer` 驱动，下一次触发时刻取以下两者的较小值：

- **显示边界**：当前秒 / 分 / 时 的下一个边界（由刷新频率决定）
- **状态转换**：下一个 start / end 时刻

这样工作中精确在下班点切换到 `.finished`（触发提醒 / Stretchly 退出 / 自动退出），
而非依赖轮询。定时器为 block 形式、`[weak self]`、`.common` run-loop 模式，
避免保留环。系统唤醒后重算以恢复正确状态。

## 7. 持久化

`UserDefaults`，每个 `@Published` 属性在 `didSet` 只写自己的 key：

`trackingMode`、`startHour/Minute`、`endHour/Minute`、`workDurationHours`、
`manualStartDate`、`refreshFrequency`、`progressDisplayStyle`、
`showsRemainingTime`、`showsProgress`、`quitsOneMinuteAfterWorkday`、
`managesStretchly`、`showsFullScreenReminderAfterWorkday`。

## 8. 已知限制

- 无 App Icon 资源
- 夜班固定时间段：`finished → working`（下一班开始）的切换最多延迟一个刷新周期；`working → finished` 精确
- 本地化目录的 key 被 Xcode 提取器标为 `stale`（源码在包里、目录在 app 壳里）；运行时查找正常（走 `Bundle.main`），仅影响新字符串的自动提取——需手动加 key
- `deinit` 在 `@MainActor` 类上是 nonisolated，原则上可能跨线程 invalidate 定时器；模型随 app 生命周期常驻，实际不触发
- Stretchly 开关在工作中途打开不会补启动（仅状态转换触发）
- 自动退出永不补退：过了退出时刻（睡过头、或事后才开开关）不会补退，只调度未来定时器

## 9. 构建

```bash
xcodebuild -scheme TimeInBar -configuration Debug build          # app
cd Packages/TimeInBarKit && swift test                           # 23 个测试
```
