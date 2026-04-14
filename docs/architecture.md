# TimeInBar 技术实现说明

## 1. 技术选型

当前实现采用：

- `SwiftUI`
- `MenuBarExtra`
- `UserDefaults`

原因：

- 原生支持 macOS 菜单栏应用
- 代码量小，适合快速验证产品
- 偏好设置和菜单栏内容都可以直接用 SwiftUI 构建

## 2. 当前目录结构

```text
time-in-bar-for-mac/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── requirements.md
│   └── roadmap.md
├── TimeInBar/
│   ├── CountdownModel.swift
│   ├── Info.plist
│   ├── MenuContentView.swift
│   ├── SettingsView.swift
│   └── TimeInBarApp.swift
└── TimeInBar.xcodeproj/
```

## 3. 模块职责

### 3.1 App 入口

文件：[TimeInBar/TimeInBarApp.swift](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar/TimeInBarApp.swift)

职责：

- 创建全局 `CountdownModel`
- 挂载 `MenuBarExtra`
- 挂载 `Settings` 场景

### 3.2 业务状态模型

文件：[TimeInBar/CountdownModel.swift](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar/CountdownModel.swift)

职责：

- 保存开始时间、结束时间、刷新频率
- 将配置持久化到 `UserDefaults`
- 根据当前时间计算状态
- 输出给 UI 使用的快照数据
- 监听系统唤醒并重新刷新状态

当前核心状态：

- `notStarted`
- `working`
- `finished`
- `invalid`

### 3.3 菜单栏视图

文件：[TimeInBar/MenuContentView.swift](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar/MenuContentView.swift)

职责：

- 渲染状态栏上的图标或文字
- 渲染点击后的菜单内容
- 提供 `Preferences…` 和 `Quit` 入口

### 3.4 偏好设置页

文件：[TimeInBar/SettingsView.swift](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar/SettingsView.swift)

职责：

- 配置开始时间
- 配置结束时间
- 配置刷新频率
- 显示非法时间段的错误提示

## 4. 数据流

```text
用户修改设置
-> SettingsView 更新 CountdownModel
-> CountdownModel 持久化 UserDefaults
-> CountdownModel 重新计算 snapshot
-> MenuBarExtra 文本 / 图标自动刷新
```

## 5. 状态计算逻辑

### 5.1 开始前

条件：

- `now < start`

输出：

- 状态栏图标
- 菜单文案 `还没有上班`

### 5.2 工作中

条件：

- `start <= now < end`

输出：

- 状态栏文案 `3h32m · 23%`
- 菜单文案 `距离下班还剩 ...`
- 菜单文案 `今日进度 ...`

### 5.3 下班后

条件：

- `now >= end`

输出：

- 状态栏图标
- 菜单文案 `下班了!!`

### 5.4 非法配置

条件：

- `start >= end`

输出：

- 错误图标
- 菜单提示 `时间设置无效`
- 设置页红字提示

## 6. 刷新机制

当前通过 `Timer` 驱动刷新。

刷新间隔取决于偏好设置：

- `按时` -> 3600 秒
- `按分` -> 60 秒
- `按秒` -> 1 秒

同时监听系统唤醒事件，避免休眠恢复后显示不正确。

## 7. 持久化策略

当前采用 `UserDefaults` 保存以下字段：

- `startHour`
- `startMinute`
- `endHour`
- `endMinute`
- `refreshFrequency`

优点：

- 足够满足第一版需求
- 不需要引入数据库或文件存储
- 读写简单

## 8. 已知限制

- 尚未添加 App Icon 资源
- 尚未配置登录启动
- 未做单元测试
- 未做本地化
- 未做 UI 视觉打磨
- 目前工程在本环境下未能通过 `xcodebuild` 验证，因为机器只启用了 Command Line Tools，没有切到完整 Xcode

## 9. 后续建议

- 补充 App Icon 和更明确的状态栏图标语义
- 使用更精确的“对齐到分钟/秒边界”刷新策略
- 为状态格式化和状态计算补测试
- 增加开机启动能力
- 增加首次启动默认引导
