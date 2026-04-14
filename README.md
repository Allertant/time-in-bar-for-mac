# TimeInBar

一个原生 macOS 状态栏倒计时小工具。

## 项目文档

- 产品需求说明：[docs/requirements.md](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/docs/requirements.md)
- 技术实现说明：[docs/architecture.md](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/docs/architecture.md)
- 迭代规划：[docs/roadmap.md](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/docs/roadmap.md)

## 当前功能

- 偏好设置里配置开始时间、结束时间、刷新频率
- 开始前只显示图标，菜单提示 `还没有上班`
- 工作中显示 `剩余时间 · 进度`
- 下班后只显示图标，菜单提示 `下班了!!`

## 运行方式

1. 用 Xcode 打开 [TimeInBar.xcodeproj](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar.xcodeproj)
2. 选择 `TimeInBar` scheme
3. 运行应用

## 当前限制

- 第一版只支持单时间段
- 不支持跨天时间段
- 如果结束时间早于或等于开始时间，会显示配置无效

## 代码结构

- 应用入口：[TimeInBar/TimeInBarApp.swift](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar/TimeInBarApp.swift)
- 状态与时间逻辑：[TimeInBar/CountdownModel.swift](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar/CountdownModel.swift)
- 状态栏菜单：[TimeInBar/MenuContentView.swift](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar/MenuContentView.swift)
- 偏好设置页：[TimeInBar/SettingsView.swift](/Users/shiyixi/Documents/my-coding/time-in-bar-for-mac/TimeInBar/SettingsView.swift)
