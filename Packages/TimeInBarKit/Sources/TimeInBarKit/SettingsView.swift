import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var model: CountdownModel

    public init(model: CountdownModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preferences")
                    .font(.title3.weight(.semibold))

                Text(modeSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("打卡模式", selection: $model.trackingMode) {
                        ForEach(TrackingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    if model.trackingMode == .fixedSchedule {
                        HStack(alignment: .top, spacing: 18) {
                            CompactTimePicker(title: "开始时间", selection: startTimeBinding)
                            CompactTimePicker(title: "结束时间", selection: endTimeBinding)
                        }
                    } else {
                        LabeledContent("工作时长") {
                            HStack(spacing: 4) {
                                TextField("", value: workDurationBinding, format: .number.precision(.fractionLength(0...1)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.trailing)
                                Text("小时")
                                if let startTime = model.todayManualStartTime {
                                    Text("·")
                                    Text("上班时间 \(startTime)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                SectionLabel(title: "工作时间", subtitle: model.trackingMode == .fixedSchedule ? "设置每天的工作开始和结束时间" : "设置每天的工作时长，手动开始计时")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("剩余时间") {
                        Picker("刷新频率", selection: $model.refreshFrequency) {
                            ForEach(RefreshFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    Toggle("显示剩余时间", isOn: $model.showsRemainingTime)

                    Divider()

                    LabeledContent("进度展示") {
                        Picker("进度展示", selection: $model.progressDisplayStyle) {
                            ForEach(ProgressDisplayStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    Toggle("显示进度", isOn: $model.showsProgress)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                SectionLabel(title: "显示方式", subtitle: "控制状态栏中的刷新节奏和进度样式")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("登录后自动启动", isOn: launchAtLoginBinding)
                        .disabled(model.launchAtLogin.unsupported)

                    Toggle("下班 1 分钟后自动退出", isOn: $model.quitsOneMinuteAfterWorkday)

                    Toggle("上班时自动启动 Stretchly", isOn: $model.managesStretchly)

                    if model.launchAtLogin.unsupported {
                        Text("当前系统版本不支持应用内配置开机自动启动。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if model.launchAtLogin.requiresApproval {
                        Text("系统还需要你的确认，启用后请在系统设置的登录项中完成授权。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("打开登录项设置") {
                            model.launchAtLogin.openSettings()
                        }
                    }

                    if let errorMessage = model.launchAtLogin.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                SectionLabel(title: "启动", subtitle: "控制应用是否在登录后自动启动")
            }

            GroupBox {
                HStack(spacing: 10) {
                    Toggle("下班后全屏提示", isOn: $model.showsFullScreenReminderAfterWorkday)

                    /*
                    Button("测试全屏提示") {
                        model.showFullScreenWorkdayReminderForTesting()
                    }
                    */
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                SectionLabel(title: "下班提示", subtitle: "下班到点后用黑色全屏提示休息")
            }

            if model.trackingMode == .fixedSchedule && model.snapshot.status == .invalid {
                Label("结束时间必须晚于开始时间。", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if model.trackingMode == .countdown && model.workDurationHours <= 0 {
                Label("工作时长必须大于 0。", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .controlSize(.small)
        .padding(18)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            model.launchAtLogin.refresh()
        }
    }

    private var modeSummary: String {
        switch model.trackingMode {
        case .fixedSchedule:
            return "\(timeText(hour: model.startHour, minute: model.startMinute)) - \(timeText(hour: model.endHour, minute: model.endMinute))"
        case .countdown:
            let format = String(localized: "每天工作 %@ 小时，手动打卡")
            return String(format: format, formatDuration(model.workDurationHours))
        }
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { makeDate(hour: model.startHour, minute: model.startMinute) },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                model.startHour = components.hour ?? model.startHour
                model.startMinute = components.minute ?? model.startMinute
            }
        )
    }

    private var workDurationBinding: Binding<Double> {
        Binding(
            get: { model.workDurationHours },
            set: { model.setWorkDurationHours($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLogin.enabled },
            set: { model.launchAtLogin.setEnabled($0) }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { makeDate(hour: model.endHour, minute: model.endMinute) },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                model.endHour = components.hour ?? model.endHour
                model.endMinute = components.minute ?? model.endMinute
            }
        )
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .minute, value: hour * 60 + minute, to: today) ?? .now
    }

    private func timeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func formatDuration(_ hours: Double) -> String {
        hours.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hours))" : String(format: "%.1f", hours)
    }
}

private struct CompactTimePicker: View {
    public let title: String
    @Binding var selection: Date

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            DatePicker(
                "",
                selection: $selection,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.field)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionLabel: View {
    public let title: String
    public let subtitle: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
