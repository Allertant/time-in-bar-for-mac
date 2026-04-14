import SwiftUI

struct MenuBarLabelView: View {
    let snapshot: StatusSnapshot

    var body: some View {
        if let text = snapshot.labelText {
            Text(text)
        } else {
            Image(systemName: snapshot.labelSymbol)
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var model: CountdownModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.snapshot.menuTitle)
                .font(.headline)

            if let detail = model.snapshot.menuDetail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Preferences…") {
                model.openSettings()
            }

            Button("Quit") {
                model.quitApp()
            }
        }
        .padding(12)
        .frame(minWidth: 240, alignment: .leading)
    }
}
