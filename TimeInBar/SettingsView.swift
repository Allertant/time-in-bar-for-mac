import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: CountdownModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preferences")
                    .font(.title3.weight(.semibold))

                Text(scheduleSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GroupBox {
                HStack(alignment: .top, spacing: 18) {
                    CompactTimePicker(title: "开始时间", selection: startTimeBinding)
                    CompactTimePicker(title: "结束时间", selection: endTimeBinding)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                SectionLabel(title: "时间段", subtitle: "设置每天的工作开始和结束时间")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("刷新频率") {
                        Picker("刷新频率", selection: $model.refreshFrequency) {
                            ForEach(RefreshFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

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

                    Toggle("显示剩余时间", isOn: $model.showsRemainingTime)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                SectionLabel(title: "显示方式", subtitle: "控制状态栏中的刷新节奏和进度样式")
            }

            if model.snapshot.status == .invalid {
                Label("结束时间必须晚于开始时间。", systemImage: "exclamationmark.triangle.fill")
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
    }

    private var scheduleSummary: String {
        "\(timeText(hour: model.startHour, minute: model.startMinute)) - \(timeText(hour: model.endHour, minute: model.endMinute))"
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
}

private struct CompactTimePicker: View {
    let title: String
    @Binding var selection: Date

    var body: some View {
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
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
