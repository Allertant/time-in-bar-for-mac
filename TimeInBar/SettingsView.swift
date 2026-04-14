import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: CountdownModel

    var body: some View {
        Form {
            Section("时间段") {
                TimePickerRow(
                    title: "开始时间",
                    hour: $model.startHour,
                    minute: $model.startMinute
                )

                TimePickerRow(
                    title: "结束时间",
                    hour: $model.endHour,
                    minute: $model.endMinute
                )
            }

            Section("刷新频率") {
                Picker("刷新频率", selection: $model.refreshFrequency) {
                    ForEach(RefreshFrequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
            }

            if model.snapshot.status == .invalid {
                Text("结束时间必须晚于开始时间。")
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}

private struct TimePickerRow: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()

            Picker("小时", selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .frame(width: 80)

            Text(":")
                .foregroundStyle(.secondary)

            Picker("分钟", selection: $minute) {
                ForEach(0..<60, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .frame(width: 80)
        }
    }
}
