import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: CountdownModel

    var body: some View {
        Form {
            Section("时间段") {
                TimePickerRow(title: "开始时间", selection: startTimeBinding)
                TimePickerRow(title: "结束时间", selection: endTimeBinding)
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
}

private struct TimePickerRow: View {
    let title: String
    @Binding var selection: Date

    var body: some View {
        HStack {
            Text(title)
            Spacer()

            DatePicker(
                "",
                selection: $selection,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.field)
        }
    }
}
